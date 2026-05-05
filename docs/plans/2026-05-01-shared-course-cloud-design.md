# 2026-05-01 Shared Course Cloud — Design Brainstorm

> Phase 5 of the [runtime course discovery and import](.cursor/plans/runtime-course-discovery-import_0247cd1d.plan.md) work.
> Status: **brainstorm**, no implementation. The runtime importer (Phases 1–4) currently writes every imported course to the local Caches directory only; this doc explores how to elevate that local cache into a shared Supabase-backed catalog once Supabase auth is online.

## Goal

Once *one* user has imported a course on-device, *every other* SwingPal user near that course should be able to start a round on it without re-running the OSM pipeline. The community pays the cost of import once; everyone else gets a fast path that looks the same as our hand-bundled courses.

## Why this is the right phase to defer it to

The runtime importer needs to ship **before** the cloud sync. We need real imported `SwingPalCourse` payloads coming out of real users' phones to know:

- which feature-kind distributions we actually see in the wild,
- how often the AI advisory layer flips a course to `provisional`,
- how often two different users in the same area produce diverging geometry for the same course (suggesting OSM relation churn / our converter behaving non-deterministically across iOS minor versions).

Without that telemetry the cloud schema is guesswork. Phases 1–4 are the data collection step, even though the data initially lives only on individual devices.

---

## Trust model

This is the part that needs the most thought, so it goes first.

A user-generated course is fundamentally different from a hand-bundled course:

| Property | Bundled | User-imported |
|---|---|---|
| Source-of-truth | designed-by-hand by us | OSM at one point in time |
| Validation | reviewed eyes-on + lints | deterministic gates + AI advisory |
| Reproducibility | byte-stable | depends on OSM, converter version, AI verdict |
| Trust score | implicit "we've shipped this" | depends on who imported, when, and how many people have used it without complaint |

The cloud needs to *remember* that distinction. Concretely:

1. **Provenance is a first-class field.** Every shared course row carries `source` ∈ `{bundled, runtime_osm, manual_correction}`, the OSM relation/way ID it came from, the converter version, the on-device validation outcome, and the AI summary if any.
2. **Bundled always wins.** If the runtime importer produces a course whose dedupe key (name + rounded coord, see Phase 4) collides with a bundled course, the cloud should refuse the upload, return `409 conflict_with_bundled`, and the client falls through to using the bundled record.
3. **First-import promotes; subsequent imports vote.** The first user to upload a `(osm_id, converter_version)` pair becomes the canonical record. Subsequent imports of the same course don't *replace* it; they cast a "matches what I imported" vote. We can later use those votes as a confidence signal (3 independent users converged on the same geometry → high trust).

This avoids two failure modes:

- **Single bad upload poisons the catalog.** A user with corrupt local OSM cache uploads a deformed course. Without voting, every other user picks it up. With voting, the bad import sits at confidence=1 until somebody else's clean import either matches it (confirms) or doesn't (raises a flag).
- **Race on first import.** Two users importing simultaneously both succeed; whoever wins the upsert is canonical, the other becomes a vote on it.

### Validation gate before *any* upload

We already run two layers on-device. For cloud upload we add a third gate: **the upload only happens if `quality.overallConfidence != .provisional`**. Provisional courses stay local. The reasoning:

- Provisional means *the on-device AI flagged concerns* or *the AI was unavailable*. Either way, we don't yet trust it enough to share.
- It also gives us an organic moderation surface — users on a `provisional` course can manually flag corrections (we already have the correction-center pipeline), and once a correction is accepted *that* course is what gets uploaded.

---

## Data model

Supabase schema additions, layered on top of the existing `courses` table from `2026-04-21-supabase-auth-data-design.md`. None of the existing columns change.

### `courses` — extend, don't replace

The doc already defines `courses` with `id, name, country_code, region, locality, latitude, longitude, hole_count, par, metadata jsonb`. We extend it with provenance / sharing columns:

```sql
alter table courses add column source text not null default 'bundled';
-- 'bundled' | 'runtime_osm' | 'manual_correction'
alter table courses add column osm_id text;
-- 'relation-12345' | 'way-9876' (null for bundled)
alter table courses add column converter_version text;
-- e.g. 'swift-1.0' / 'python-1.2' — bumped whenever the converter changes
alter table courses add column geometry_hash text;
-- sha256 of canonical-encoded course JSON, for dedupe + drift detection
alter table courses add column publish_state text not null default 'public';
-- 'public' | 'pending_review' | 'hidden'
alter table courses add column upload_confidence numeric(3,2) not null default 1.00;
-- starts at 1.00 for the first import, climbs to 1.00 cap as votes confirm
alter table courses add column ai_summary text;
-- the one-liner from FoundationModelsCourseValidator if any
alter table courses add column ai_concerns jsonb not null default '[]'::jsonb;
alter table courses add column uploaded_by_profile_id uuid references profiles(id);
alter table courses add column uploaded_at timestamptz;
alter table courses add column last_verified_at timestamptz;
-- updated each time another user's import matches this geometry_hash

create unique index courses_osm_unique
  on courses (osm_id, converter_version)
  where source = 'runtime_osm';
```

### `course_geometry_payloads` — full JSON in storage, not in Postgres

Storing 50–500 KB course JSON in Postgres works but pollutes the table. Better split:

- Postgres `courses` row: small, indexable metadata.
- Supabase Storage bucket `courses-geometry/` keyed by `course_id.json`: the full `SwingPalCourse` JSON exactly as we encode locally.
- Public read, RLS-write (only the uploader of the row can write the corresponding object).

Alternatively, if Postgres egress is cheaper than Storage egress for our volume:

- Add `geometry jsonb` column on `courses` itself.
- Compress at the API boundary (`Content-Encoding: gzip`).

Decision can wait until we measure actual sizes — *most* shared courses will be 50–150 KB compressed, well within either option.

### `course_uploads` — votes / confirmation log

```sql
create table course_uploads (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  uploaded_by_profile_id uuid not null references profiles(id),
  geometry_hash text not null,
  matched_canonical boolean not null,
  -- true = same geometry_hash as the canonical row → vote
  -- false = different geometry → conflict, see resolution below
  client_converter_version text not null,
  client_app_version text not null,
  client_os_version text not null,
  ai_outcome text,
  -- 'approved' | 'provisional' | null
  created_at timestamptz not null default now()
);

create index course_uploads_by_course on course_uploads (course_id, created_at desc);
```

This gives us:

- A timeline of who imported what and when.
- A confidence input (`upload_confidence` is a function of `count(matched_canonical=true)` plus age of canonical row).
- A conflict surface — when `matched_canonical=false`, the user's import was for the same `osm_id` but the geometry differs from canonical. That's our "OSM updated, time to refresh" signal.

### `course_corrections` — already exists

The existing draft-correction flow stays as-is. The new piece: when a correction is accepted on a *cloud-shared* course, we either:

- patch the canonical row in place (if the corrector is highly trusted), or
- fork it into a new `course_id` with `source='manual_correction'` and let voting decide which becomes the default for that `osm_id`.

The first option is simpler. The second is safer. Likely we ship the simple version first.

---

## Sync flow

### On import (after Phase 4 persistence)

```
1. RuntimeOSMConverter produces SwingPalCourse + CourseValidationResult.
2. ImportedCourseStore writes the course locally (existing behavior).
3. NEW: if validation.outcome == .approved AND user is signed in AND
   they've opted into community sharing, schedule an upload task:
     a. Compute geometry_hash from the canonical-encoded JSON.
     b. Look up `courses` by (osm_id, converter_version).
     c. If row exists and hash matches → write a row in `course_uploads`
        with matched_canonical=true. Done.
     d. If row exists and hash differs → write a row in `course_uploads`
        with matched_canonical=false. Surface "your local geometry
        differs from the community version" in settings → user can
        choose to overwrite (creates a new candidate row) or accept
        canonical (deletes local file, keeps cloud).
     e. If row doesn't exist → INSERT, then upload geometry to storage.
4. The upload task is best-effort. If it fails, retry on next app launch
   from a queue persisted alongside the manifest. Importing a round
   *never* blocks on cloud upload.
```

### On discovery (RoundSetupState.loadNearbyCoursesIfNeeded)

We already do `Overpass nwr around 10 km`. Add a Supabase pre-pass:

```
1. Query Supabase: select * from courses
   where ST_DWithin(geog, current_location_geog, 10000)
     and publish_state = 'public'
   order by ST_Distance(geog, current_location_geog) asc
   limit 25.
2. Mark each result as 'community' in the UI.
3. Run the existing Overpass query in parallel.
4. Merge: if Overpass returns an osm_id we already got from Supabase,
   prefer the Supabase row (we have the converted payload ready) and
   skip the import pipeline entirely on tap.
```

Net effect for the user: courses near them appear *instantly* (one cheap Postgres query) and most taps don't need the import pipeline because somebody else already imported it.

### On tap of a Supabase-sourced course

```
1. Download geometry JSON from storage.
2. Decode into SwingPalCourse.
3. Re-run DeterministicCourseValidator locally — this is cheap and
   defends against a corrupted upload bypassing our trust gates.
4. Skip the AI advisory step (already ran on the uploader's device,
   and the result is in the row's ai_concerns).
5. Persist via ImportedCourseStore exactly like a fresh import.
6. Continue into round setup.
```

The deterministic re-validation is the key safety net — even if somebody manages to upload garbage, every downloader catches it before it hits a round.

---

## RLS / abuse strategy

```sql
-- Anyone authenticated can read public courses.
create policy "courses readable when public" on courses
for select using (publish_state = 'public');

-- Only signed-in users can insert, and only their own row.
create policy "courses insert by uploader" on courses
for insert with check (
  uploaded_by_profile_id = auth.uid()
  and source = 'runtime_osm'
);

-- Only the uploader (or admin) can hide their own upload.
create policy "courses update by uploader" on courses
for update using (uploaded_by_profile_id = auth.uid())
with check (uploaded_by_profile_id = auth.uid());
```

Storage bucket `courses-geometry`:

- Public read (the JSON contents are not sensitive — they're public OSM data).
- Authenticated insert; key constrained to `<course_id>.json` where the row's `uploaded_by_profile_id = auth.uid()`.

Rate limiting:

- Per-profile cap: max **5 distinct course uploads per 24 h**. The runtime importer is for the user's own immediate round; if somebody is uploading dozens of courses they're scraping OSM through us, which we explicitly don't want.
- Global cap on `INSERT ... courses where source='runtime_osm'`: max 1000/day at the Edge Function layer until we have moderation tooling.

Reporting:

- Re-use the correction-center flow. A "report this course" action on a community course flips `publish_state='hidden'` immediately if the reporter is the uploader, or files a moderation ticket if not.

---

## Versioning

The converter is going to evolve. We need to handle the case where v2 produces a structurally different `SwingPalCourse` than v1.

- `courses.converter_version` is part of the unique key. v2 imports go in alongside v1 imports of the same OSM course; they don't conflict.
- Discovery query prefers the **highest converter_version** for a given `osm_id`. If v2 exists for this course, v1 is invisible.
- v1 rows are not deleted — they remain readable for users still on the old client.
- When a user upgrades and tries to import a course where their v2 disagrees with the canonical v2 row, the existing voting mechanism applies.

---

## UI surface (small)

Round setup's nearby section already groups bundled vs. discovered. We add a third grouping:

- **Bundled** — same as today.
- **From your area** — Supabase community courses, badged with a small "community" indicator + the upload count if > 1.
- **Other golf courses near you** — fresh OSM Overpass hits we don't have in Supabase, badged "import on tap".

Tap behavior:

- Bundled or community → instant select.
- Overpass-only → trigger the existing import overlay.

In settings, under "Cloud and sync", a single toggle:

> **Share imported courses with the SwingPal community**
>
> When you import a course we don't have, share the converted geometry with other golfers near it. Only courses that pass on-device validation are shared. Off by default.

Defaulting to **off** keeps us conservative; users opt in once they see how the feature works.

---

## Open questions

1. **Do we need a server-side validator?** The current plan re-runs the deterministic gates on every download. That's O(holes) and runs in microseconds. It might still be worth a server-side validator to reject obvious garbage at upload time so the bucket doesn't fill with junk.
2. **OpenGolfAPI as a metadata cross-check.** When we promote a runtime import to canonical, we could cross-reference par/length against OpenGolfAPI (the design plan in `2026-04-29-course-ingestion-pipeline-design.md` mentions it as a metadata supplement). If our import says par 72 and OpenGolfAPI says par 71 for the same name+coord, that's a meaningful warning.
3. **What happens to the user's local copy when the cloud version supersedes it?** Probably: keep the local copy as a fallback for offline rounds, but mark it stale; on next round-setup tap, prefer the cloud version transparently.
4. **Geometry hashes are sensitive to JSON ordering.** We need a canonical encoding before hashing. Probably: sort all keys lexicographically and write coordinates with fixed precision (e.g. 7 decimal places) before hashing. Otherwise two identical imports produce different hashes.
5. **Billing.** Supabase Storage egress is the variable cost. At 100 KB/course × 25 courses returned per discovery × thousands of users, this scales — but linearly with rounds played, not user count, so it's tractable. Worth modelling once we have user-count projections.
6. **Premium gate?** The design doc lists "saved rounds, bag data, attestation, future premium intelligence" as the cloud features. Sharing/receiving community courses doesn't naturally fit any of those buckets — it's a network-effect feature, value to the user goes up as more users are on the network. Probably keeps it free; gate other things.

---

## Suggested phasing for implementation (when we ship it)

Mirrors the runtime importer phasing:

1. **Phase A** — Schema additions, Supabase Storage bucket, RLS, no client integration. Just the table is there and admins can query it.
2. **Phase B** — Upload path: post-import, optional, behind a settings toggle. No discovery integration yet. We start collecting real geometry from real users to validate the trust model.
3. **Phase C** — Discovery integration: Supabase pre-pass before Overpass, "community" badge in UI, community courses skip the import overlay.
4. **Phase D** — Voting + drift detection: `course_uploads` becomes a real table that drives `upload_confidence`, conflict resolution UI surfaces in settings.
5. **Phase E** — Moderation tooling + admin dashboard for hidden / reported courses.

Each phase is shippable in isolation; the runtime importer keeps working unchanged throughout.

---

## What to do *before* any of this

Two prerequisites:

- **Real Supabase project + auth.** Currently `2026-04-21-supabase-auth-data-design.md` is a design doc; nothing is wired. Auth has to ship first because every cloud row needs an `uploaded_by_profile_id`.
- **Telemetry on the runtime importer.** Add a one-liner in `RoundSetupState.acceptImportedCourse` that logs (locally for now) `{osm_id, hole_count, validation_outcome, ai_outcome, conversion_ms}`. After a few weeks of real use we'll know whether the trust model needs to be stricter or looser before we open it up to the network.
