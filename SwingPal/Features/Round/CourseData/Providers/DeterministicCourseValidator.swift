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

    /// Two vertices this close are the same point.
    static let duplicateGreenVertexThresholdMeters: Double = 1.0
    /// Two greens on different holes are the same green drawn twice when at
    /// least this share of the smaller one's vertices coincide with the
    /// other's (or their centres coincide). Catches the kind of duplicate
    /// data we had to clean out of `medway.json` and
    /// `royal-melbourne-west.json`, while greens that merely touch (sharing
    /// a node or two on a common edge) pass, as do the two halves of a
    /// double green.
    static let duplicateGreenSharedVertexFraction: Double = 0.6
    static let duplicateGreenCentreThresholdMeters: Double = 2.0

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
                .map { (holeNumber: hole.number, feature: $0) }
        }
        if let pair = duplicateGreens(greens) {
            failures.append("Holes \(pair.0) and \(pair.1) have the same green drawn twice — duplicate geometry detected.")
        }

        return failures
    }

    /// The first pair of holes whose greens are the same green drawn twice.
    static func duplicateGreens(
        _ greens: [(holeNumber: Int, feature: SwingPalCourse.Hole.Feature)]
    ) -> (Int, Int)? {
        guard greens.count >= 2 else { return nil }
        for i in 0..<(greens.count - 1) {
            for j in (i + 1)..<greens.count {
                let a = greens[i], b = greens[j]
                guard a.holeNumber != b.holeNumber else { continue }
                // The two halves of a double green, split between the flags.
                if RuntimeOSMCourseConverter.sharedGreenPartner(of: a.feature) == b.holeNumber,
                   RuntimeOSMCourseConverter.sharedGreenPartner(of: b.feature) == a.holeNumber {
                    continue
                }
                if isSameGreen(a.feature.coordinates, b.feature.coordinates) {
                    return (a.holeNumber, b.holeNumber)
                }
            }
        }
        return nil
    }

    private static func isSameGreen(
        _ a: [SwingPalCourse.Coordinate],
        _ b: [SwingPalCourse.Coordinate]
    ) -> Bool {
        func metres(_ p: SwingPalCourse.Coordinate, _ q: SwingPalCourse.Coordinate) -> Double {
            RuntimeOSMCourseConverter.haversineMeters(
                CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude),
                CLLocationCoordinate2D(latitude: q.latitude, longitude: q.longitude)
            )
        }
        func distinct(_ ring: [SwingPalCourse.Coordinate]) -> [SwingPalCourse.Coordinate] {
            ring.count > 1 && ring.first == ring.last ? Array(ring.dropLast()) : ring
        }
        let ringA = distinct(a), ringB = distinct(b)
        guard !ringA.isEmpty, !ringB.isEmpty else { return false }

        if let centreA = RuntimeOSMCourseConverter.centroid(of: ringA),
           let centreB = RuntimeOSMCourseConverter.centroid(of: ringB),
           metres(centreA, centreB) < duplicateGreenCentreThresholdMeters {
            return true
        }

        let (smaller, larger) = ringA.count <= ringB.count ? (ringA, ringB) : (ringB, ringA)
        let coinciding = smaller.filter { vertex in
            larger.contains { metres(vertex, $0) < duplicateGreenVertexThresholdMeters }
        }.count
        return Double(coinciding) >= Double(smaller.count) * duplicateGreenSharedVertexFraction
    }
}
