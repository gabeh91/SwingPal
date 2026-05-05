import XCTest
import CoreLocation
@testable import SwingPal

final class RuntimeOSMCourseConverterTests: XCTestCase {
    // MARK: - Synthetic happy path

    func testConvertProducesNumberedHolesWithFeaturesAndDeterministicIDs() throws {
        let raw = try synthetic9HolePayload(courseName: "Stub Course")
        let discovered = DiscoveredCourse(
            id: "way-100",
            name: "Stub Course",
            coordinate: .init(latitude: -37.97, longitude: 145.03),
            osmID: 100,
            osmType: .way,
            countryCode: "AU",
            region: "Victoria",
            distanceKilometers: 2.0
        )

        let course = try RuntimeOSMCourseConverter.convert(rawOSM: raw, for: discovered)

        XCTAssertEqual(course.name, "Stub Course")
        XCTAssertEqual(course.holes.count, 9)
        XCTAssertEqual(course.holes.map(\.number), Array(1...9))

        for hole in course.holes {
            XCTAssertEqual(hole.par, 4)
            XCTAssertTrue(hole.features.contains(where: { $0.kind == .tee }))
            XCTAssertTrue(hole.features.contains(where: { $0.kind == .green }))
        }
        XCTAssertEqual(course.par, 36)
        XCTAssertEqual(course.tees.count, 3)
        XCTAssertEqual(course.tees.map(\.name), ["Championship", "Member", "Forward"])
        XCTAssertEqual(course.quality.overallConfidence, .provisional)
    }

    func testConvertRejectsPayloadWithFewerThanNineHoles() throws {
        let raw = try synthetic9HolePayload(courseName: "Stub Course", holeCount: 5)
        let discovered = DiscoveredCourse(
            id: "way-101",
            name: "Stub Course",
            coordinate: .init(latitude: 0, longitude: 0),
            osmID: 101,
            osmType: .way,
            countryCode: nil,
            region: nil,
            distanceKilometers: nil
        )
        XCTAssertThrowsError(
            try RuntimeOSMCourseConverter.convert(rawOSM: raw, for: discovered)
        ) { error in
            guard case RuntimeOSMCourseConverter.ConversionError.insufficientHoles(let found) = error else {
                XCTFail("Wrong error: \(error)")
                return
            }
            XCTAssertEqual(found, 5)
        }
    }

    func testConvertRejectsPayloadWithNoHoles() throws {
        let raw = Data(#"{"elements":[]}"#.utf8)
        let discovered = DiscoveredCourse(
            id: "way-102",
            name: "Empty",
            coordinate: .init(latitude: 0, longitude: 0),
            osmID: 102,
            osmType: .way,
            countryCode: nil,
            region: nil,
            distanceKilometers: nil
        )
        XCTAssertThrowsError(
            try RuntimeOSMCourseConverter.convert(rawOSM: raw, for: discovered)
        ) { error in
            XCTAssertEqual(error as? RuntimeOSMCourseConverter.ConversionError, .noHolesDetected)
        }
    }

    func testConvertReadsParTagWhenPresent() throws {
        let raw = try synthetic9HolePayload(courseName: "Par Course", holePars: [3, 4, 5, 4, 4, 3, 5, 4, 4])
        let discovered = DiscoveredCourse(
            id: "way-103",
            name: "Par Course",
            coordinate: .init(latitude: -37.97, longitude: 145.03),
            osmID: 103,
            osmType: .way,
            countryCode: nil,
            region: nil,
            distanceKilometers: nil
        )
        let course = try RuntimeOSMCourseConverter.convert(rawOSM: raw, for: discovered)
        XCTAssertEqual(course.holes.map(\.par), [3, 4, 5, 4, 4, 3, 5, 4, 4])
        XCTAssertEqual(course.par, 36)
    }

    // MARK: - Deterministic UUIDs

    func testDeterministicUUIDIsStableAcrossInvocations() {
        let a = RuntimeOSMCourseConverter.deterministicUUID(slug: "test", label: "course")
        let b = RuntimeOSMCourseConverter.deterministicUUID(slug: "test", label: "course")
        XCTAssertEqual(a, b)

        let c = RuntimeOSMCourseConverter.deterministicUUID(slug: "test", label: "hole/1")
        XCTAssertNotEqual(a, c)
    }

    func testDeterministicUUIDMatchesBundledMedwayCourseID() {
        // Cross-checks the Swift v5 implementation against the canonical
        // value the Python ingestion script wrote into medway.json (the id
        // at the top of `SwingPal/Resources/Courses/medway.json`). If this
        // diverges the runtime-imported course IDs won't line up with the
        // build-time bundled ones for the same slug.
        let id = DeterministicUUID.v5(
            namespace: DeterministicUUID.urlNamespace,
            name: "swingpal/courses/medway/course"
        )
        XCTAssertEqual(id.uuidString.lowercased(), "a672bfce-4b78-58bb-bf75-db3da0afdbd0")
    }

    // MARK: - Geometry helpers

    func testHaversineMatchesKnownCityPair() {
        // Melbourne CBD → Sydney CBD ≈ 713 km
        let melbourne = CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)
        let sydney = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
        let meters = RuntimeOSMCourseConverter.haversineMeters(melbourne, sydney)
        XCTAssertEqual(meters / 1000, 713, accuracy: 5)
    }

    func testClosestSegmentDistanceReturnsZeroWhenPointOnSegment() {
        let polyline: [SwingPalCourse.Coordinate] = [
            .init(latitude: 0, longitude: 0),
            .init(latitude: 0, longitude: 0.01)
        ]
        let onSegment = SwingPalCourse.Coordinate(latitude: 0, longitude: 0.005)
        let distance = RuntimeOSMCourseConverter.closestSegmentDistanceMeters(onSegment, polyline: polyline)
        XCTAssertLessThan(distance, 1)
    }

    // MARK: - Helpers

    /// Builds an Overpass-style payload with `holeCount` synthetic holes
    /// laid out east-to-east at the given centre, each with a tee + green
    /// polygon close to the hole centerline. Used to exercise the converter
    /// without needing real OSM data.
    private func synthetic9HolePayload(
        courseName: String,
        holeCount: Int = 9,
        holePars: [Int]? = nil,
        centre: SwingPalCourse.Coordinate = .init(latitude: -37.97, longitude: 145.03)
    ) throws -> Data {
        var elements: [[String: Any]] = []
        for index in 0..<holeCount {
            let baseLat = centre.latitude + Double(index) * 0.005
            let baseLon = centre.longitude

            let teeLat = baseLat
            let greenLat = baseLat + 0.0024 // ~270 m north
            let lon = baseLon

            var holeTags: [String: String] = [
                "golf": "hole",
                "ref": String(index + 1)
            ]
            if let par = holePars?[index] {
                holeTags["par"] = String(par)
            }

            elements.append([
                "type": "way",
                "id": 1_000 + index,
                "tags": holeTags,
                "geometry": [
                    ["lat": teeLat, "lon": lon],
                    ["lat": greenLat, "lon": lon]
                ]
            ])

            elements.append([
                "type": "way",
                "id": 2_000 + index,
                "tags": ["golf": "tee"],
                "geometry": teeBox(around: .init(latitude: teeLat, longitude: lon))
            ])

            elements.append([
                "type": "way",
                "id": 3_000 + index,
                "tags": ["golf": "green"],
                "geometry": greenBox(around: .init(latitude: greenLat, longitude: lon))
            ])
        }

        _ = courseName
        let json: [String: Any] = ["elements": elements]
        return try JSONSerialization.data(withJSONObject: json)
    }

    private func teeBox(around point: SwingPalCourse.Coordinate) -> [[String: Double]] {
        let dLat = 0.00005
        let dLon = 0.00005
        return [
            ["lat": point.latitude - dLat, "lon": point.longitude - dLon],
            ["lat": point.latitude + dLat, "lon": point.longitude - dLon],
            ["lat": point.latitude + dLat, "lon": point.longitude + dLon],
            ["lat": point.latitude - dLat, "lon": point.longitude + dLon],
            ["lat": point.latitude - dLat, "lon": point.longitude - dLon]
        ]
    }

    private func greenBox(around point: SwingPalCourse.Coordinate) -> [[String: Double]] {
        let dLat = 0.00010
        let dLon = 0.00010
        return [
            ["lat": point.latitude - dLat, "lon": point.longitude - dLon],
            ["lat": point.latitude + dLat, "lon": point.longitude - dLon],
            ["lat": point.latitude + dLat, "lon": point.longitude + dLon],
            ["lat": point.latitude - dLat, "lon": point.longitude + dLon],
            ["lat": point.latitude - dLat, "lon": point.longitude - dLon]
        ]
    }
}
