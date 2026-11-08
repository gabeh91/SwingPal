import XCTest
@testable import SwingPal

final class DeterministicCourseValidatorTests: XCTestCase {
    func testApprovesAValidEighteenHoleCourse() {
        let course = SwingPalCourse.test(name: "Royal Melbourne", distanceKilometers: 1.0)
        let failures = DeterministicCourseValidator.validate(course)
        XCTAssertEqual(failures, [])
    }

    func testRejectsCourseWithWrongHoleCount() {
        let baseline = SwingPalCourse.test(name: "Stub", distanceKilometers: 0)
        let trimmed = SwingPalCourse(
            id: baseline.id,
            name: baseline.name,
            distanceKilometers: baseline.distanceKilometers,
            coordinate: baseline.coordinate,
            holeCount: 12,
            par: baseline.par,
            sourceReferences: baseline.sourceReferences,
            quality: baseline.quality,
            community: baseline.community,
            tees: baseline.tees,
            holes: Array(baseline.holes.prefix(12))
        )
        let failures = DeterministicCourseValidator.validate(trimmed)
        XCTAssertTrue(failures.contains(where: { $0.contains("9- or 18-hole") }))
    }

    func testRejectsHoleMissingTeeAndGreen() {
        let baseline = SwingPalCourse.test(name: "Stub", distanceKilometers: 0)
        let firstHole = baseline.holes[0]
        let strippedFirstHole = SwingPalCourse.Hole(
            id: firstHole.id,
            number: firstHole.number,
            par: firstHole.par,
            features: firstHole.features.filter { $0.kind != .green && $0.kind != .tee }
        )
        var holes = baseline.holes
        holes[0] = strippedFirstHole
        let course = SwingPalCourse(
            id: baseline.id,
            name: baseline.name,
            distanceKilometers: baseline.distanceKilometers,
            coordinate: baseline.coordinate,
            holeCount: baseline.holeCount,
            par: baseline.par,
            sourceReferences: baseline.sourceReferences,
            quality: baseline.quality,
            community: baseline.community,
            tees: baseline.tees,
            holes: holes
        )

        let failures = DeterministicCourseValidator.validate(course)
        XCTAssertTrue(failures.contains(where: { $0.contains("missing a tee polygon") }))
        XCTAssertTrue(failures.contains(where: { $0.contains("missing a green polygon") }))
    }

    func testRejectsCourseWithDuplicateGreens() {
        let baseline = SwingPalCourse.test(name: "Stub", distanceKilometers: 0)
        // Make hole 2's green identical to hole 1's green
        let firstGreenCoords = baseline.holes[0].features.first(where: { $0.kind == .green })?.coordinates ?? []
        let secondHole = baseline.holes[1]
        let mutatedSecondHoleFeatures = secondHole.features.map { feature -> SwingPalCourse.Hole.Feature in
            if feature.kind == .green {
                return SwingPalCourse.Hole.Feature(
                    id: feature.id,
                    kind: .green,
                    label: feature.label,
                    coordinates: firstGreenCoords
                )
            }
            return feature
        }
        var holes = baseline.holes
        holes[1] = SwingPalCourse.Hole(
            id: secondHole.id,
            number: secondHole.number,
            par: secondHole.par,
            features: mutatedSecondHoleFeatures
        )
        let course = SwingPalCourse(
            id: baseline.id,
            name: baseline.name,
            distanceKilometers: baseline.distanceKilometers,
            coordinate: baseline.coordinate,
            holeCount: baseline.holeCount,
            par: baseline.par,
            sourceReferences: baseline.sourceReferences,
            quality: baseline.quality,
            community: baseline.community,
            tees: baseline.tees,
            holes: holes
        )

        let failures = DeterministicCourseValidator.validate(course)
        XCTAssertTrue(failures.contains(where: { $0.contains("duplicate geometry") }))
    }

    func testRejectsHoleWithImplausibleTeeToGreenDistance() {
        let baseline = SwingPalCourse.test(name: "Stub", distanceKilometers: 0)
        let firstHole = baseline.holes[0]
        // Replace tee with coordinates 800 m east of the green so distance
        // exceeds 700 m threshold.
        let mutatedFeatures = firstHole.features.map { feature -> SwingPalCourse.Hole.Feature in
            if feature.kind == .tee {
                let baseCoord = feature.coordinates.first ?? .init(latitude: 0, longitude: 0)
                let nudged = SwingPalCourse.Coordinate(
                    latitude: baseCoord.latitude,
                    longitude: baseCoord.longitude + 0.012 // ~1 km
                )
                return SwingPalCourse.Hole.Feature(
                    id: feature.id,
                    kind: .tee,
                    label: feature.label,
                    coordinates: [nudged]
                )
            }
            return feature
        }
        var holes = baseline.holes
        holes[0] = SwingPalCourse.Hole(
            id: firstHole.id,
            number: firstHole.number,
            par: firstHole.par,
            features: mutatedFeatures
        )
        let course = SwingPalCourse(
            id: baseline.id,
            name: baseline.name,
            distanceKilometers: baseline.distanceKilometers,
            coordinate: baseline.coordinate,
            holeCount: baseline.holeCount,
            par: baseline.par,
            sourceReferences: baseline.sourceReferences,
            quality: baseline.quality,
            community: baseline.community,
            tees: baseline.tees,
            holes: holes
        )

        let failures = DeterministicCourseValidator.validate(course)
        XCTAssertTrue(failures.contains(where: { $0.contains("tee→green distance") }))
    }

    // MARK: - Duplicate greens

    private func square(east: Double, north: Double, side: Double = 0.0002) -> [SwingPalCourse.Coordinate] {
        let lat = -37.82 + north, lon = 144.88 + east
        let ring: [SwingPalCourse.Coordinate] = [
            .init(latitude: lat, longitude: lon),
            .init(latitude: lat, longitude: lon + side),
            .init(latitude: lat + side, longitude: lon + side),
            .init(latitude: lat + side, longitude: lon)
        ]
        return ring + [ring[0]]
    }

    private func green(_ coordinates: [SwingPalCourse.Coordinate], label: String = "Green") -> SwingPalCourse.Hole.Feature {
        .init(kind: .green, label: label, coordinates: coordinates)
    }

    func testTheSameGreenOnTwoHolesIsADuplicate() {
        let pair = DeterministicCourseValidator.duplicateGreens([
            (holeNumber: 1, feature: green(square(east: 0, north: 0))),
            (holeNumber: 2, feature: green(square(east: 0.001, north: 0))),
            (holeNumber: 3, feature: green(square(east: 0, north: 0)))
        ])
        XCTAssertEqual(pair?.0, 1)
        XCTAssertEqual(pair?.1, 3)
    }

    func testGreensThatTouchAreNotDuplicates() {
        // Two neighbouring greens drawn with a common edge (shared nodes).
        XCTAssertNil(DeterministicCourseValidator.duplicateGreens([
            (holeNumber: 1, feature: green(square(east: 0, north: 0))),
            (holeNumber: 2, feature: green(square(east: 0.0002, north: 0)))
        ]))
    }

    func testTheHalvesOfADoubleGreenAreNotDuplicates() {
        let whole = square(east: 0, north: 0)
        XCTAssertNil(DeterministicCourseValidator.duplicateGreens([
            (holeNumber: 4, feature: green(whole, label: "Green (shared with hole 6)")),
            (holeNumber: 6, feature: green(whole, label: "Green (shared with hole 4)"))
        ]))
        // …but a green labelled as shared with some other hole is still caught.
        XCTAssertNotNil(DeterministicCourseValidator.duplicateGreens([
            (holeNumber: 4, feature: green(whole, label: "Green (shared with hole 6)")),
            (holeNumber: 5, feature: green(whole, label: "Green (shared with hole 4)"))
        ]))
    }
}
