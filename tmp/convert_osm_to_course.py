"""
Convert Overpass API JSON for a golf course into the `SwingPalCourse` JSON
shape consumed by `BundledCourseRepository`.

Strategy
--------
1. Parse OSM JSON.
2. For each `golf=hole` way matching this course's identity (by `golf:course:name`
   tag, the explicit list of refs, or just-the-bbox), use the way's geometry as
   the tee->green centerline.
3. Assign each `golf=tee/fairway/green/bunker/water_hazard` polygon to the
   closest tagged hole's centerline (capped at 80m to avoid pulling in stray
   features from neighbouring courses).
4. Orient each hole's tees/greens by the centerline's endpoints so the runtime
   picks the correct primary tee and primary green.
5. Emit one big `SwingPalCourse` JSON.

Run
---
Default (regenerate every configured course):

    python3 tmp/convert_osm_to_course.py

Or target a specific course slug:

    python3 tmp/convert_osm_to_course.py royal-melbourne-west
    python3 tmp/convert_osm_to_course.py medway
"""

from __future__ import annotations

import json
import math
import sys
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable


# ---------------------------------------------------------------------------
# Course configuration
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class CourseConfig:
    """One configured course = one bundled JSON we generate."""

    slug: str
    """Stable folder/UUID seed; ALSO the bundled JSON filename (slug.json)."""

    display_name: str
    """Human-readable course name for the SwingPal UI."""

    osm_path: Path
    """Local Overpass result JSON to read from."""

    out_path: Path
    """Where to write the SwingPal-shaped JSON."""

    hole_refs: list[str]
    """OSM `ref` values for the course's holes, in playing order (1..N)."""

    course_filter: Callable[[dict[str, Any]], bool]
    """Predicate over a `golf=hole` element's `tags` dict; True = belongs to this course.

    Use this to disambiguate when an Overpass bbox covers more than one club
    (e.g. Royal Melbourne West vs East). For single-course bboxes, return True
    for any hole whose ref is in `hole_refs`.
    """

    par_overrides: dict[str, int] = field(default_factory=dict)
    """OSM-disagrees-with-scorecard fixes, keyed by ref."""

    course_distance_km: float = 3.0

    source_note: str = "Imported from OpenStreetMap via Overpass API."

    osm_external_id: str = ""

    tees: list[dict[str, Any]] = field(default_factory=list)
    """Optional per-course tee deck definitions. If empty, generic defaults are emitted."""


CONFIGS: list[CourseConfig] = [
    CourseConfig(
        slug="royal-melbourne-west",
        display_name="Royal Melbourne",
        osm_path=Path("tmp/rmw-osm-wide.json"),
        out_path=Path("SwingPal/Resources/Courses/royal-melbourne-west.json"),
        hole_refs=[f"{n}W" for n in range(1, 19)],
        # Royal Melbourne's bbox includes Victoria GC and others. Match by
        # both the West Course `nW` ref AND the explicit course-name tag.
        course_filter=lambda tags: (
            tags.get("ref") in {f"{n}W" for n in range(1, 19)}
            and tags.get("golf:course:name") == "West Course"
        ),
        # OSM tags 4W and 11W as par 4; the official Royal Melbourne West
        # scorecard is par 72 (4-5-4-5-3-4-3-4-4 / 4-5-4-3-4-5-3-4-4).
        par_overrides={"4W": 5, "11W": 5},
        course_distance_km=3.2,
        source_note=(
            "West Course routing; imported from OpenStreetMap via Overpass API "
            "and reconciled for SwingPal launch."
        ),
        osm_external_id="osm-royal-melbourne-west",
        tees=[
            {"name": "Championship", "yards": 6598},
            {"name": "Member", "yards": 6196},
            {"name": "Forward", "yards": 5478},
        ],
    ),
    CourseConfig(
        slug="medway",
        display_name="Medway Golf Club",
        osm_path=Path("tmp/medway-osm.json"),
        out_path=Path("SwingPal/Resources/Courses/medway.json"),
        hole_refs=[str(n) for n in range(1, 19)],
        # Single-course bbox — any `golf=hole` with a numeric ref 1..18 is ours.
        course_filter=lambda tags: tags.get("ref") in {str(n) for n in range(1, 19)},
        par_overrides={},
        course_distance_km=2.6,
        source_note=(
            "Medway Golf Club, Maidstone (Maribyrnong) VIC. Imported from "
            "OpenStreetMap via Overpass API."
        ),
        osm_external_id="osm-medway",
        # Medway publishes a Par 70 / ~5,721m layout. Yardages are approximate
        # member-tee references for now; refine when official scorecard ingestion lands.
        tees=[
            {"name": "Championship", "yards": 6256},
            {"name": "Member", "yards": 5973},
            {"name": "Forward", "yards": 5237},
        ],
    ),
]


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------


def deterministic_uuid(slug: str, label: str) -> str:
    """Stable UUIDs from a string seed so repeat runs of this script don't churn diffs."""
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"swingpal/courses/{slug}/{label}"))


def haversine(a: tuple[float, float], b: tuple[float, float]) -> float:
    """Distance in meters between two (lat, lon) points."""
    lat1, lon1 = a
    lat2, lon2 = b
    r = 6_371_000.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    h = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def centroid(coords: list[tuple[float, float]]) -> tuple[float, float]:
    lat = sum(c[0] for c in coords) / len(coords)
    lon = sum(c[1] for c in coords) / len(coords)
    return (lat, lon)


def point_to_segment_distance_m(
    p: tuple[float, float],
    a: tuple[float, float],
    b: tuple[float, float],
) -> float:
    """Approximate distance in meters from point `p` to segment `a-b`.

    Uses a local ENU-ish flat projection; perfectly fine for sub-km golf hole
    distances at Melbourne's latitude.
    """
    ref_lat = (a[0] + b[0]) / 2
    cos_lat = math.cos(math.radians(ref_lat))

    def to_local(pt: tuple[float, float]) -> tuple[float, float]:
        lat, lon = pt
        x = (lon - a[1]) * 111_111 * cos_lat
        y = (lat - a[0]) * 111_111
        return (x, y)

    pa = to_local(a)
    pb = to_local(b)
    pp = to_local(p)

    dx, dy = pb[0] - pa[0], pb[1] - pa[1]
    if dx == 0 and dy == 0:
        return math.hypot(pp[0] - pa[0], pp[1] - pa[1])

    t = ((pp[0] - pa[0]) * dx + (pp[1] - pa[1]) * dy) / (dx * dx + dy * dy)
    t = max(0.0, min(1.0, t))
    cx = pa[0] + t * dx
    cy = pa[1] + t * dy
    return math.hypot(pp[0] - cx, pp[1] - cy)


def closest_segment_distance_m(
    p: tuple[float, float],
    polyline: list[tuple[float, float]],
) -> float:
    """Min distance in meters from `p` to any segment of `polyline`."""
    if len(polyline) == 1:
        return haversine(p, polyline[0])
    return min(
        point_to_segment_distance_m(p, polyline[i], polyline[i + 1])
        for i in range(len(polyline) - 1)
    )


def coord_payload(coords: list[tuple[float, float]]) -> list[dict[str, float]]:
    return [{"latitude": lat, "longitude": lon} for lat, lon in coords]


def make_feature(
    slug: str, label_seed: str, kind: str, label: str, coords: list[tuple[float, float]]
) -> dict[str, Any]:
    return {
        "id": deterministic_uuid(slug, label_seed),
        "kind": kind,
        "label": label,
        "coordinates": coord_payload(coords),
    }


def load_osm(path: Path) -> list[dict[str, Any]]:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    return data["elements"]


def way_geometry(element: dict[str, Any]) -> list[tuple[float, float]]:
    return [(g["lat"], g["lon"]) for g in element.get("geometry", [])]


# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------


KIND_MAP = {
    "tee": "tee",
    "fairway": "fairway",
    "green": "green",
    "bunker": "bunker",
    "water_hazard": "water",
}

MAX_ASSIGNMENT_DISTANCE_M = 80.0
"""Features further than this from the nearest hole centerline are dropped.

This is the rough cap that prevents stray bunkers/tees from neighbouring courses
(or no-mans-land between holes) being attached to the wrong hole.
"""


def convert_course(config: CourseConfig) -> None:
    elements = load_osm(config.osm_path)

    holes_by_ref: dict[str, dict[str, Any]] = {}
    features_to_assign: list[dict[str, Any]] = []

    for el in elements:
        tags = el.get("tags") or {}
        kind = tags.get("golf")
        if kind == "hole":
            if config.course_filter(tags):
                ref = tags.get("ref")
                if ref:
                    holes_by_ref[ref] = el
        elif kind in KIND_MAP:
            features_to_assign.append(el)

    print(
        f"[{config.slug}] Found {len(holes_by_ref)} tagged holes and "
        f"{len(features_to_assign)} candidate features",
        file=sys.stderr,
    )

    # Verify every expected hole ref is present.
    missing = [r for r in config.hole_refs if r not in holes_by_ref]
    if missing:
        raise RuntimeError(
            f"[{config.slug}] Missing OSM hole ways for: {missing}. Check the "
            "Overpass bbox/query and the course_filter predicate."
        )

    hole_centerlines: dict[str, list[tuple[float, float]]] = {
        ref: way_geometry(el) for ref, el in holes_by_ref.items()
    }

    assignments: dict[str, list[tuple[str, str, list[tuple[float, float]]]]] = {
        ref: [] for ref in holes_by_ref
    }

    for feature in features_to_assign:
        coords = way_geometry(feature)
        if not coords:
            continue
        c = centroid(coords)
        best_ref: str | None = None
        best_distance = math.inf
        for ref, polyline in hole_centerlines.items():
            d = closest_segment_distance_m(c, polyline)
            if d < best_distance:
                best_distance = d
                best_ref = ref
        if best_ref is None or best_distance > MAX_ASSIGNMENT_DISTANCE_M:
            continue
        kind = KIND_MAP[feature["tags"]["golf"]]
        assignments[best_ref].append((kind, kind, coords))

    holes_payload: list[dict[str, Any]] = []
    for n, ref in enumerate(config.hole_refs, start=1):
        hole_id = deterministic_uuid(config.slug, f"hole/{ref}")

        # Orient the hole's features so the runtime picks the right tee and green
        # as "primary" (LiveRoundState uses `currentHoleFeatures.first(where: kind)`).
        #
        # 1. Use the OSM hole-way's two endpoints. Whichever end has tee polygons
        #    cluster nearest is the "tee end"; the other is the "green end".
        # 2. Sort tees by ascending distance to the tee end (closest = primary).
        # 3. Sort greens by ascending distance to the green end (closest = primary).
        records = assignments[ref]
        hole_geom = hole_centerlines[ref]
        end_a = hole_geom[0]
        end_b = hole_geom[-1]

        tee_records = [r for r in records if r[0] == "tee"]
        green_records = [r for r in records if r[0] == "green"]
        fairway_records = [r for r in records if r[0] == "fairway"]
        bunker_records = [r for r in records if r[0] == "bunker"]
        water_records = [r for r in records if r[0] == "water"]

        def min_distance_to_records(end: tuple[float, float], rs) -> float:
            if not rs:
                return math.inf
            return min(haversine(end, centroid(coords)) for _, _, coords in rs)

        end_a_to_tees = min_distance_to_records(end_a, tee_records)
        end_b_to_tees = min_distance_to_records(end_b, tee_records)
        if end_a_to_tees <= end_b_to_tees:
            tee_end, green_end = end_a, end_b
        else:
            tee_end, green_end = end_b, end_a

        tee_records.sort(key=lambda r: haversine(centroid(r[2]), tee_end))
        green_records.sort(key=lambda r: haversine(centroid(r[2]), green_end))
        bunker_records.sort(key=lambda r: -len(r[2]))

        ordered = (
            tee_records
            + fairway_records
            + green_records
            + bunker_records
            + water_records
        )

        features: list[dict[str, Any]] = []
        bunker_index = 0
        tee_index = 0
        for kind, _kind_dup, coords in ordered:
            if kind == "tee":
                tee_index += 1
                label = f"Tee box {tee_index}"
            elif kind == "fairway":
                label = "Fairway corridor"
            elif kind == "green":
                label = "Green"
            elif kind == "bunker":
                bunker_index += 1
                label = f"Bunker {bunker_index}"
            elif kind == "water":
                label = "Water hazard"
            else:
                label = kind.capitalize()
            features.append(
                make_feature(
                    config.slug,
                    f"{ref}/{kind}/{len(features)}",
                    kind,
                    label,
                    coords,
                )
            )

        # Read par from the OSM hole tag, default to 4. par_overrides wins for
        # holes where the OSM tag is known to disagree with the official scorecard.
        par_str = (holes_by_ref[ref].get("tags") or {}).get("par")
        par = (
            config.par_overrides.get(ref)
            or (int(par_str) if par_str and par_str.isdigit() else 4)
        )

        holes_payload.append(
            {
                "id": hole_id,
                "number": n,
                "par": par,
                "features": features,
            }
        )

    total_par = sum(h["par"] for h in holes_payload)

    all_coords: list[tuple[float, float]] = []
    for h in holes_payload:
        for f in h["features"]:
            for pt in f["coordinates"]:
                all_coords.append((pt["latitude"], pt["longitude"]))
    course_centroid = centroid(all_coords) if all_coords else (0.0, 0.0)

    if config.tees:
        tees_payload = [
            {
                "id": deterministic_uuid(config.slug, f"tee/{t['name'].lower()}"),
                "name": t["name"],
                "yards": t["yards"],
            }
            for t in config.tees
        ]
    else:
        tees_payload = [
            {"id": deterministic_uuid(config.slug, "tee/championship"), "name": "Championship", "yards": 6500},
            {"id": deterministic_uuid(config.slug, "tee/member"), "name": "Member", "yards": 6100},
            {"id": deterministic_uuid(config.slug, "tee/forward"), "name": "Forward", "yards": 5400},
        ]

    course_payload: dict[str, Any] = {
        "id": deterministic_uuid(config.slug, "course"),
        "name": config.display_name,
        "distanceKilometers": config.course_distance_km,
        "coordinate": {
            "latitude": course_centroid[0],
            "longitude": course_centroid[1],
        },
        "holeCount": len(config.hole_refs),
        "par": total_par,
        "sourceReferences": [
            {
                "id": deterministic_uuid(config.slug, "source/osm"),
                "kind": "openStreetMap",
                "externalID": config.osm_external_id or f"osm-{config.slug}",
                "note": config.source_note,
            }
        ],
        "quality": {
            "overallConfidence": "reviewed",
            "geometryConfidence": "reviewed",
            "metadataConfidence": "reviewed",
        },
        "community": {
            "access": "open",
            "correctionCount": 0,
        },
        "tees": tees_payload,
        "holes": holes_payload,
    }

    config.out_path.parent.mkdir(parents=True, exist_ok=True)
    with config.out_path.open("w", encoding="utf-8") as f:
        json.dump(course_payload, f, ensure_ascii=False, indent=2)

    feature_total = sum(len(h["features"]) for h in holes_payload)
    print(
        f"[{config.slug}] Wrote {config.out_path} - {len(holes_payload)} holes, "
        f"par {total_par}, {feature_total} features",
        file=sys.stderr,
    )


def main(argv: list[str]) -> None:
    selected = argv[1:] if len(argv) > 1 else [c.slug for c in CONFIGS]
    by_slug = {c.slug: c for c in CONFIGS}
    unknown = [s for s in selected if s not in by_slug]
    if unknown:
        raise SystemExit(
            f"Unknown course slug(s): {unknown}. Known: {list(by_slug.keys())}"
        )
    for slug in selected:
        convert_course(by_slug[slug])


if __name__ == "__main__":
    main(sys.argv)
