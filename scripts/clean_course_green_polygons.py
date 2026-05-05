#!/usr/bin/env python3
"""
Clean green polygon coordinates in bundled course JSONs.

Problem:
- Some holes include stray green vertices far from the real putting surface,
  producing absurd projected "green depth" and breaking Front/Back yardages.

Approach:
- For each specified hole:
  - Find the green feature and compute a centroid.
  - Compute each vertex's distance from centroid (local tangent-plane meters).
  - Keep the tight cluster of points by removing outliers:
    - compute the 90th percentile radius (r90)
    - keep points within max(r90 * 1.35, r90 + 8) meters
    - additionally cap at 80m (greens shouldn't be that large)
  - If too few points remain, fall back to keeping the closest 12 points.
  - Preserve order of remaining points (important for polygon winding).
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path
from typing import Any, Iterable


def _to_rad(x: float) -> float:
    return x * math.pi / 180.0


def _meters_xy(ref_lat: float, ref_lon: float, lat: float, lon: float) -> tuple[float, float]:
    # local tangent-plane approximation: x east, y north
    m_per_deg_lat = 111_111.0
    m_per_deg_lon = 111_111.0 * max(math.cos(_to_rad(ref_lat)), 0.1)
    dy = (lat - ref_lat) * m_per_deg_lat
    dx = (lon - ref_lon) * m_per_deg_lon
    return dx, dy


def _centroid(coords: list[dict[str, float]]) -> tuple[float, float] | None:
    if not coords:
        return None
    return (
        sum(c["latitude"] for c in coords) / len(coords),
        sum(c["longitude"] for c in coords) / len(coords),
    )


def _percentile(sorted_values: list[float], p: float) -> float:
    if not sorted_values:
        return 0.0
    # linear interpolation
    idx = (len(sorted_values) - 1) * p
    lo = int(math.floor(idx))
    hi = int(math.ceil(idx))
    if lo == hi:
        return sorted_values[lo]
    frac = idx - lo
    return sorted_values[lo] * (1.0 - frac) + sorted_values[hi] * frac


def _distance_from_centroid_m(cent_lat: float, cent_lon: float, c: dict[str, float]) -> float:
    dx, dy = _meters_xy(cent_lat, cent_lon, c["latitude"], c["longitude"])
    return math.hypot(dx, dy)


def clean_green_feature_coords(coords: list[dict[str, float]]) -> tuple[list[dict[str, float]], dict[str, Any]]:
    cent = _centroid(coords)
    if cent is None:
        return coords, {"status": "empty"}
    cent_lat, cent_lon = cent

    radii = [_distance_from_centroid_m(cent_lat, cent_lon, c) for c in coords]
    radii_sorted = sorted(radii)
    r90 = _percentile(radii_sorted, 0.90)
    # envelope: allow some irregular shapes but reject far stray points
    threshold = min(80.0, max(r90 * 1.35, r90 + 8.0))

    keep_mask = [r <= threshold for r in radii]
    kept = [c for c, keep in zip(coords, keep_mask) if keep]

    # Ensure polygon remains usable.
    if len(kept) < 4:
        # Keep the closest 12 points (or all if fewer).
        ranked = sorted(zip(coords, radii), key=lambda t: t[1])
        closest = {id(c) for c, _ in ranked[: min(12, len(ranked))]}
        kept = [c for c in coords if id(c) in closest]

    return kept, {
        "status": "cleaned",
        "original_points": len(coords),
        "kept_points": len(kept),
        "r90_m": round(r90, 2),
        "threshold_m": round(threshold, 2),
        "max_radius_m": round(max(radii_sorted) if radii_sorted else 0.0, 2),
    }


def iter_holes(course: dict[str, Any]) -> Iterable[dict[str, Any]]:
    for hole in course.get("holes", []):
        yield hole


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: clean_course_green_polygons.py <course.json> [<course.json> ...]", file=sys.stderr)
        return 2

    # The cleanup is now applied to **every** bundled course, on
    # every hole. Two passes:
    #   1. If a hole has multiple "green" features, keep only the
    #      one farthest from the tee (real putting green) and drop
    #      the rest (almost always artifacts of OSM multipolygons
    #      or adjacent practice-green polygons that bleed in).
    #   2. For each remaining green, trim outlier vertices that are
    #      far from the cluster centroid (using r90-based envelope).
    changed_any = False

    for arg in sys.argv[1:]:
        path = Path(arg)
        stem = path.stem

        course = json.loads(path.read_text(encoding="utf-8"))
        print(f"\n== {course.get('name', stem)} ({path.name}) ==")

        for hole in iter_holes(course):
            num = hole.get("number")
            features = hole.get("features", [])
            greens = [f for f in features if f.get("kind") == "green"]
            if not greens:
                print(f"H{num}: no green feature found")
                continue

            # Some holes (notably Medway 10/13, Royal Melbourne 1/2/5/15)
            # contain multiple features labelled "green", where one is a
            # stray outline (often near the tee) that breaks Front/Back
            # distances. If multiple greens exist, keep the one farthest
            # from the tee centroid (most likely the actual putting green).
            tee_features = [f for f in features if f.get("kind") == "tee"]
            tee_centroid = None
            if tee_features:
                tee_centroid = _centroid(tee_features[0].get("coordinates", []))

            if len(greens) > 1 and tee_centroid is not None:
                tee_lat, tee_lon = tee_centroid

                def green_distance_from_tee(g: dict[str, Any]) -> float:
                    g_cent = _centroid(g.get("coordinates", []))
                    if g_cent is None:
                        return -1.0
                    dx, dy = _meters_xy(tee_lat, tee_lon, g_cent[0], g_cent[1])
                    return math.hypot(dx, dy)

                ranked = sorted(greens, key=green_distance_from_tee, reverse=True)
                keep_green = ranked[0]
                remove_greens = [g for g in greens if g is not keep_green]
                if remove_greens:
                    hole["features"] = [f for f in features if f.get("kind") != "green"] + [keep_green]
                    features = hole["features"]
                    greens = [keep_green]
                    changed_any = True
                    print(f"H{num}: removed {len(remove_greens)} stray green feature(s)")

            # Clean all remaining green features (typically exactly one).
            for green in greens:
                coords = green.get("coordinates", [])
                cleaned, meta = clean_green_feature_coords(coords)
                if meta["status"] != "cleaned":
                    print(f"H{num}: {meta}")
                    continue

                if len(cleaned) != len(coords):
                    green["coordinates"] = cleaned
                    changed_any = True
                    print(f"H{num}: {meta}")
                else:
                    print(f"H{num}: unchanged (already clean) {meta}")

        if changed_any:
            path.write_text(json.dumps(course, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if not changed_any:
        print("\nNo changes made.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

