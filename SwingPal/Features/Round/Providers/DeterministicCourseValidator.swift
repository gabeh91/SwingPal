import Foundation
import CoreLocation

/// Hard-block gates a downloaded course must clear before it can be used.
/// These are deterministic, fast, and AI-free — the on-device model layered
/// on top in Phase 3 is purely advisory.
enum DeterministicCourseValidator {
    /// Inclusive bounds of valid hole counts. We allow 9-hole loops because
    /// a fair number of community/par-3 courses come back from OSM that way;
    /// anything in between (10-17) almost always indicates partial OSM
    /// coverage and we'd rather block than ship a half-mapped course.
    static let allowedHoleCounts: Set<Int> = [9, 18]
    /// Total-par bands per supported hole count. The 18-hole band tracks
    /// the historical 60-80 plan; the 9-hole band scales it down so par-3
    /// loops aren't rejected for being short.
    static let totalParRanges: [Int: ClosedRange<Int>] = [
        9: 27...40,
        18: 60...80
    ]
    static let holeParRange: ClosedRange<Int> = 3...5
    static let holeLengthRangeMeters: ClosedRange<Double> = 50...700

    /// Two greens are considered duplicates if any pair of vertices sits
    /// within this many metres. Catches the kind of duplicate-green data we
    /// already had to clean out of `medway.json` and
    /// `royal-melbourne-west.json`.
    static let duplicateGreenVertexThresholdMeters: Double = 1.0

    /// Runs every gate and returns either `[]` (approved) or the list of
    /// failure reasons. Reasons are user-readable so they can be surfaced
    /// directly in the loading overlay.
    static func validate(_ course: SwingPalCourse) -> [String] {
        var failures: [String] = []

        // Hole count.
        if !allowedHoleCounts.contains(course.holes.count) {
            failures.append(
                "We only import 9- or 18-hole courses (found \(course.holes.count) holes)."
            )
        }

        // Hole numbering: 1..N contiguous, no duplicates.
        let numbers = course.holes.map(\.number).sorted()
        let expected = Array(1...max(numbers.count, 1))
        if numbers != expected {
            failures.append("Hole numbering isn't contiguous from 1.")
        }

        // Per-hole par + per-hole geometry.
        for hole in course.holes {
            if !holeParRange.contains(hole.par) {
                failures.append("Hole \(hole.number) has an invalid par of \(hole.par).")
            }
            let hasGreen = hole.features.contains(where: { $0.kind == .green })
            let hasTee = hole.features.contains(where: { $0.kind == .tee })
            if !hasTee {
                failures.append("Hole \(hole.number) is missing a tee polygon.")
            }
            if !hasGreen {
                failures.append("Hole \(hole.number) is missing a green polygon.")
            }
        }

        // Total par.
        let totalPar = course.holes.reduce(0) { $0 + $1.par }
        if let range = totalParRanges[course.holes.count], !range.contains(totalPar) {
            failures.append(
                "Total par \(totalPar) is outside the playable range \(range.lowerBound)–\(range.upperBound) for a \(course.holes.count)-hole course."
            )
        }

        // Coordinate sanity.
        for (index, feature) in course.holes.flatMap(\.features).enumerated() {
            for coordinate in feature.coordinates {
                if !coordinate.latitude.isFinite || !coordinate.longitude.isFinite {
                    failures.append("Feature \(index) on the course has a non-finite coordinate.")
                    break
                }
                if !(-90.0...90.0).contains(coordinate.latitude)
                    || !(-180.0...180.0).contains(coordinate.longitude) {
                    failures.append("Feature \(index) has an out-of-range coordinate.")
                    break
                }
            }
        }

        // Tee→green distance per hole.
        for hole in course.holes {
            let tees = hole.features.filter { $0.kind == .tee }.flatMap(\.coordinates)
            let greens = hole.features.filter { $0.kind == .green }.flatMap(\.coordinates)
            guard
                let teeCentroid = RuntimeOSMCourseConverter.centroid(of: tees),
                let greenCentroid = RuntimeOSMCourseConverter.centroid(of: greens)
            else { continue }
            let distance = RuntimeOSMCourseConverter.haversineMeters(
                CLLocationCoordinate2D(latitude: teeCentroid.latitude, longitude: teeCentroid.longitude),
                CLLocationCoordinate2D(latitude: greenCentroid.latitude, longitude: greenCentroid.longitude)
            )
            if !holeLengthRangeMeters.contains(distance) {
                failures.append(
                    "Hole \(hole.number) has an implausible tee→green distance of \(Int(distance.rounded())) m."
                )
            }
        }

        // Duplicate-green vertex collisions across holes.
        let greens = course.holes.flatMap { hole in
            hole.features
                .filter { $0.kind == .green }
                .map { (holeNumber: hole.number, coordinates: $0.coordinates) }
        }
        if duplicateGreenSharing(greens: greens) {
            failures.append("Two greens share a coordinate within 1 m — duplicate geometry detected.")
        }

        return failures
    }

    private static func duplicateGreenSharing(
        greens: [(holeNumber: Int, coordinates: [SwingPalCourse.Coordinate])]
    ) -> Bool {
        guard greens.count >= 2 else { return false }
        for i in 0..<(greens.count - 1) {
            for j in (i + 1)..<greens.count {
                for ci in greens[i].coordinates {
                    for cj in greens[j].coordinates {
                        let distance = RuntimeOSMCourseConverter.haversineMeters(
                            CLLocationCoordinate2D(latitude: ci.latitude, longitude: ci.longitude),
                            CLLocationCoordinate2D(latitude: cj.latitude, longitude: cj.longitude)
                        )
                        if distance < duplicateGreenVertexThresholdMeters { return true }
                    }
                }
            }
        }
        return false
    }
}
