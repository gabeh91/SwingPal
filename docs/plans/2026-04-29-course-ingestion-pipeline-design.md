# 2026-04-29 Course Ingestion Pipeline — Design

## Goal

Move from one hand-rolled course (`royal-melbourne-west.json`) to a repeatable
pipeline that can ingest **any** course into SwingPal's runtime
`SwingPalCourse` shape with a single command. Stay deterministic, keep the
runtime app offline-capable for bundled courses, and leave a clear path to
runtime fetching when the catalog outgrows what we want to ship in the
binary.

## Non-Goals (this phase)

- No backend service. Everything is build-time tooling + bundled JSON.
- No moderation UI. Community corrections continue to live as the existing
  draft flow.
- No Supabase ingestion. That's a separate phase once the schema firms up.
- No commercial data licenses. OSM is the primary source; OpenGolfAPI is a
  metadata supplement only.

---

## Architecture Overview

```
courses-catalog.yaml            ← single source of truth: which courses, where
        │
        ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│ stage 1 – fetch          │    │ stage 2 – transform      │
│ Overpass query per entry │ →  │ raw OSM → SwingPalCourse │
│ (cache to tmp/cache/)    │    │ (current converter,      │
│                          │    │  generalised)            │
└──────────────────────────┘    └────────────┬─────────────┘
                                             │
                                             ▼
                              ┌──────────────────────────┐
                              │ stage 3 – validate       │
                              │ run quality gates,       │
                              │ surface diffs            │
                              └────────────┬─────────────┘
                                           │
                                           ▼
                  SwingPal/Resources/Courses/<slug>.json   (bundled)
                                  + course-manifest.json   (registry)
```

Each stage is a separate, idempotent step. Failure in one stage doesn't
corrupt the previous stage's output. `tmp/cache/` lets us iterate on
transform/validate without re-hitting Overpass (and respects their rate
limits).

---

## Catalog Format

One file: `courses/courses-catalog.yaml` (YAML for human ergonomics; we
translate to JSON internally).

```yaml
version: 1
defaults:
  source: openstreetmap
  feature_kinds: [tee, fairway, green, bunker, water_hazard]
  feature_assignment:
    max_distance_m: 80      # drop features further than this from any hole way
  default_tees: [Championship, Member, Forward]

courses:
  - slug: royal-melbourne-west
    name: "Royal Melbourne (West Course)"
    country: AU
    region: VIC
    osm:
      # Preferred: pin a relation ID. Most reliable; survives OSM ref churn.
      relation_id: 12345678          # null when unknown — we fall back to bbox
      # Fallback: bbox + name match. Both fields used when relation_id is null.
      bbox: [-37.998, 145.015, -37.955, 145.050]
      hole_filter:
        course_name: "West Course"   # OSM tag golf:course:name
        ref_pattern: "^[0-9]{1,2}W$" # OSM tag ref
    metadata:
      par: 70
      total_yards: 6598
      tees:
        - {name: Championship, yards: 6598}
        - {name: Member,       yards: 6196}
        - {name: Forward,      yards: 5478}

  - slug: kingston-heath
    name: "Kingston Heath Golf Club"
    country: AU
    region: VIC
    osm:
      relation_id: null
      bbox: [-37.985, 145.080, -37.965, 145.110]
      hole_filter:
        course_name: null            # only one course at this property
        ref_pattern: "^[0-9]{1,2}$"
    metadata:
      par: 72
      tees:
        - {name: Championship, yards: 7150}
        - {name: Member,       yards: 6592}
        - {name: Forward,      yards: 5694}
```

**Why both relation_id and bbox?** Per the user's Stage-0 decision: prefer
`relation_id` when known (zero ambiguity), fall back to bbox + name match
when not (faster onboarding for long-tail courses). The ingester logs which
path it took so we can incrementally upgrade entries as we look up relation
IDs.

---

## Ingester CLI

A single Python entry point: `tools/ingest_courses.py`.

```
python tools/ingest_courses.py                       # all courses in catalog
python tools/ingest_courses.py --course kingston-heath
python tools/ingest_courses.py --course rm-west --no-cache
python tools/ingest_courses.py --validate-only       # don't fetch, re-check existing JSONs
python tools/ingest_courses.py --dry-run             # print plan, don't write
python tools/ingest_courses.py --diff                # show what would change vs committed JSON
```

Internals:

1. Load + validate catalog. Hard-fail on duplicate slugs, malformed bboxes,
   non-positive yardages.
2. For each selected course:
   1. **Fetch** — Overpass POST with bbox + golf filters → cache to
      `tmp/cache/<slug>.osm.json`. Skip if cache exists and `--no-cache`
      not set. Respect Overpass rate limit (sleep on 429 with backoff).
   2. **Transform** — current `convert_osm_to_course.py` logic, but
      parameterised by the catalog entry. Hole detection uses
      `hole_filter` rules. Feature assignment uses `feature_assignment`
      rules.
   3. **Validate** (see next section). On failure, write to
      `tmp/staged/<slug>.json` and surface diff vs current shipped JSON.
      Don't overwrite the bundled file unless validation passes.
   4. **Write** — `SwingPal/Resources/Courses/<slug>.json` plus update
      `SwingPal/Resources/Courses/course-manifest.json` (slug → display
      name, par, country, source, last-ingested).
3. Print a summary table: courses processed, par totals, feature counts,
   validation status, time elapsed.

`pyproject.toml` for the tool: just `requests` + `pyyaml` + `pydantic` for
catalog validation. Pinned versions, separate venv from the iOS app.

---

## Validation Gates

A course only ships if it passes all of these. Implemented as a pure-Python
`validate.py` module so it runs both at ingest time and as a re-check
(`--validate-only`).

| Gate | Rule | Action on fail |
|---|---|---|
| **Hole count** | Exactly 18 holes (or 9 if catalog says so) | Hard-fail |
| **Hole numbering** | Numbers 1..N contiguous | Hard-fail |
| **Par sanity** | Each hole par in [3,5]; total par in [60, 80] | Hard-fail |
| **Geometry presence** | Each hole has at least 1 of {tee, green} polygons | Hard-fail |
| **Tee/green orientation** | Heuristic: tee polygon centroid is closer to start of hole way than green is | Warn (most courses pass, edge cases need review) |
| **Hole length sanity** | Tee→green distance in [80m, 600m] | Warn |
| **Feature density** | At least 3 of {tee, fairway, green, bunker} per hole | Warn |
| **No crossing fairways** | Adjacent hole bboxes don't fully overlap | Warn |
| **Total course par matches catalog metadata** | If catalog declares par, it matches the sum | Hard-fail |
| **No NaN / out-of-range coords** | All lat/lon valid, on Earth, within country bounds | Hard-fail |

Gate output is a structured report, not just text. The ingester writes
`tmp/reports/<slug>.json` with all checks, pass/fail, and diagnostic
context (e.g. which hole's tee orientation looked off). The CI step will
read these to gate merges.

---

## Distribution Strategy

Three modes, additive over time. Pick one for now (Stage A); the runtime
loader is forward-compatible with the others.

### Stage A — Bundled (current, recommended for launch)
- All catalog courses ship in the app under `SwingPal/Resources/Courses/`.
- `BundledCourseLoader` reads them; no network needed.
- App-size budget: ~50–80 KB per course (geometry-heavy courses ~150 KB).
  10 courses ≈ 1 MB. Fine.

### Stage B — Bundled + CDN-hosted "extras"
- Bundle the top 10 most-likely-played courses.
- Push the rest to a static bucket (Cloudflare R2 / S3 + CloudFront) at
  `https://courses.swingpal.app/v1/<slug>.json`.
- Manifest in the bundle lists slug → URL. Fetch + cache to
  `~/Library/Caches/SwingPal/Courses/<slug>.json` on first use.
- New `RemoteCourseRepository` decorates `BundledCourseRepository`.
- Triggered when: catalog grows past ~25 courses, or app-store size
  becomes a concern.

### Stage C — Runtime OSM fetch (long-tail discovery)
- "I'm at Random Country Club, it's not in your list" → app hits Overpass
  with current GPS + ~2 km bbox, runs a JS/Swift port of the converter
  on-device, caches the result, marks `quality.overallConfidence = .draft`.
- User can submit corrections → uploaded to backend → seeds future ingests.
- This is the long-tail strategy. Not for v1.

---

## Source Mix Strategy

OSM is the primary source but it has gaps. Layered approach:

| Field | Primary source | Fallback |
|---|---|---|
| Hole geometry (tee→green polyline) | OSM `golf=hole` ways | hand-trace from satellite (rare) |
| Greens, fairways, bunkers, water | OSM `golf=*` polygons | none (course just has fewer features) |
| Course par, hole par | OSM `par` tag | catalog metadata override |
| Tee yardages | catalog metadata | computed from geometry × 1.05 (rough) |
| Course display name, club name | catalog metadata | OSM `name` tag |
| Coordinate (for nearby search) | centroid of all hole geometry | catalog `coordinate` override |

The catalog can override anything OSM gives us. Useful when OSM is wrong
(e.g. par tagged incorrectly) or missing (e.g. a club hasn't been mapped
yet but you know the par).

---

## Hole Orientation Heuristic

The trickiest auto-detection problem. OSM `golf=hole` ways are usually a
2–4-point polyline from tee to green, but the direction isn't tagged.

Heuristic, in priority order:
1. **`golf=tee` polygon proximity** — find the largest `golf=tee` polygon
   within 60m of the way's first endpoint. If it's also closer to that
   endpoint than to the other, the way is oriented tee→green.
2. **`golf=green` polygon proximity** — same, for the last endpoint.
3. **Fallback** — first endpoint = tee, second = green. Flag the hole as
   `quality.geometryConfidence = .draft` for review.

Output: every hole carries a confidence flag. Review pipeline can sort by
confidence to triage manual fixes.

---

## What "Done" Looks Like for Phase 1

- `courses/courses-catalog.yaml` exists with at least the 1 entry we have
  today (RM West) reformatted into the new shape.
- `tools/ingest_courses.py` runs end-to-end: catalog → fetch → transform →
  validate → write. Idempotent: running twice with no input changes
  produces no diff in `Resources/Courses/`.
- The converter logic from `tmp/convert_osm_to_course.py` lives in
  `tools/swingpal_ingest/` as proper modules with unit tests.
- `tmp/convert_osm_to_course.py` deleted; `tmp/rmw-osm-wide.json` migrated
  into the cache layout.
- Validation reports for shipped courses live in `tmp/reports/` (gitignored).
- README in `tools/` explains the workflow, including how to find an OSM
  relation ID and how to add a new course in <5 minutes.
- CI step (optional) re-runs `--validate-only` on every PR so a course
  JSON edit can't ship invalid geometry.

---

## Phase Plan

### Phase 1 — Generalise + validate (≈ 1 day)
- Move converter into `tools/swingpal_ingest/`.
- Build catalog YAML loader.
- Wire up the CLI.
- Implement validation gates (hard-fail set first, warn set second).
- Re-ingest RM West through the new pipeline, confirm zero-diff vs
  current `royal-melbourne-west.json` (modulo deterministic UUID seeds).
- Write `tools/README.md`.

### Phase 2 — Onboard sandbelt 5 (≈ 0.5 day)
Add catalog entries for the well-mapped Aussie sandbelt courses:
- Kingston Heath, Victoria, Metropolitan, Commonwealth, Huntingdale.
Run pipeline, hand-review validation reports, ship the 5 new bundled
JSONs. Update `SeededCourseRepository` to load them from bundle instead
of synthetic.

### Phase 3 — International marquee (≈ 0.5 day)
- St Andrews Old, Pebble Beach, Augusta National, Sawgrass TPC, Pinehurst No. 2.
- Many of these have richer OSM data than Aussie courses; expect higher
  feature counts. Treat as a stress test for the validator.

### Phase 4 — CDN distribution (when needed)
- Add `RemoteCourseRepository` decorator.
- Build a small static-site deploy step: `tools/publish_courses.py` →
  R2/S3.
- Move all but ~10 launch courses out of the bundle.

### Phase 5 — Runtime OSM fetch (when needed)
- Either: port converter to Swift (clean, slow to build, runtime-cheap)
  or: stand up a minimal AWS Lambda that runs the Python pipeline on
  demand (fast to build, runtime-cost per request).

---

## Open Questions

1. **YAML vs JSON for catalog.** YAML is nicer to hand-edit and supports
   comments; JSON is one less dependency. Lean YAML; trivial to revisit.
2. **Where does the catalog live?** Top-level `courses/` directory, or
   under `tools/swingpal_ingest/data/`? Top-level signals it's a product
   asset, not a tooling artifact. Lean top-level.
3. **Quality flag propagation.** Today every bundled course is marked
   `reviewed`. Should the validator downgrade to `draft` on warnings?
   Probably yes — but UX needs to surface the flag (e.g. "Geometry
   pending review" badge in course list).
4. **Multi-course properties.** Royal Melbourne has West + East +
   Composite. Each is a separate `SwingPalCourse`. Do we model the club
   as a parent? Probably yes eventually, but not in this phase — flat
   slugs are fine for now (`royal-melbourne-west`, `royal-melbourne-east`).
5. **Tee yardage source.** Catalog declares championship/member/forward
   yardages today. For long-tail courses we won't have these. Computing
   from geometry is rough (often ±10% off). Worth either (a) accepting
   the estimate or (b) leaving yardage `nil` and the UI shows "—".
6. **Imagery source.** OSM doesn't give us aerial imagery; the SwiftUI
   `Map` already pulls Apple Maps satellite. No work needed unless we
   want a fallback for offline.
7. **Update cadence.** OSM data does drift (course renovations, hole
   re-routes). Re-running ingest periodically is fine for bundled, but
   gives users stale data until they update the app. CDN distribution
   solves this naturally.

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| OSM data quality varies wildly course-to-course | Validation gates surface bad imports before they ship. `quality.geometryConfidence` flag gives the UI a way to set user expectations. |
| Overpass rate limits / outages | Local cache (`tmp/cache/`). For batch runs >25 courses, switch to a downloaded Geofabrik regional `.osm.pbf` extract processed offline. |
| Tee/green orientation flipped | Confidence flag + automated visual diff (render hole geometry to PNG, eyeball). |
| App size grows unboundedly | Cap bundled count ≈ 10–15. Move the rest to CDN (Phase 4). |
| Catalog drifts from reality (new clubhouse, hole renumber) | Each catalog entry has `last_validated` timestamp; CI warns if older than 90 days. |
| OSM contributor maps a hole incorrectly | Manual override hooks in catalog (`metadata.par`, `metadata.tees`). Long-term: community corrections feed back into catalog. |
| Multiple courses share an OSM bbox (Royal Melbourne is the canonical case — West + East both inside one polygon) | Catalog `hole_filter.course_name` already disambiguates by `golf:course:name` tag. Already proven on RM. |

---

## Decision Log

- **Catalog format**: support both relation_id and bbox+name (per session
  decision 2026-04-29).
- **Phase scope**: design only; no code in this commit (per session
  decision 2026-04-29).
- **Primary source**: OSM, with catalog metadata overrides.
- **Distribution v1**: bundled JSON only; CDN deferred.
- **Validation**: pure-Python module, runs both at ingest and as a CI
  re-check.

---

## What I'd Build First

If we move into implementation, the smallest meaningful slice is:

1. `tools/swingpal_ingest/__init__.py` with the converter logic, taking
   a `CourseSpec` dataclass derived from the catalog.
2. `tools/swingpal_ingest/cli.py` exposing `ingest`, `validate`, `diff`.
3. `courses/courses-catalog.yaml` with the single RM West entry.
4. Re-run pipeline. Confirm `royal-melbourne-west.json` is byte-for-byte
   identical (after sorting feature lists deterministically) to what
   ships today.
5. Then Kingston Heath as the second entry — that's where we discover
   what the catalog needs to express that we didn't anticipate.
