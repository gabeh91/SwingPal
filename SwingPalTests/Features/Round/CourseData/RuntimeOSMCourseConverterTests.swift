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
        XCTAssertNil(course.distanceKilometers, "Search results without a user origin must not become zero kilometres away")
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

    // MARK: - Filling gaps in OpenStreetMap

    func testMissingGreenIsEstimatedFromThePinAndReported() throws {
        // As at Westgate: hole 4 has a hole line, tee and pin but no green drawn.
        let raw = try synthetic9HolePayload(courseName: "Gap Course", withoutGreenOnHoles: [4], pinOffsetMetres: 6)
        let course = try RuntimeOSMCourseConverter.convert(rawOSM: raw, for: discovered(named: "Gap Course"))

        let hole4 = try XCTUnwrap(course.holes.first { $0.number == 4 })
        let green = try XCTUnwrap(hole4.features.first { $0.kind == .green })
        XCTAssertTrue(green.label.hasSuffix("(estimated)"))
        // Centred on the pin (6 m past the hole line's end), ~12 m across.
        let centre = try XCTUnwrap(RuntimeOSMCourseConverter.centroid(of: green.coordinates))
        let greenEndLat = -37.97 + 3 * 0.005 + 0.0024
        XCTAssertEqual((centre.latitude - greenEndLat) * 110_540, 6, accuracy: 1)

        XCTAssertTrue(DeterministicCourseValidator.validate(course).isEmpty, "An estimated green must not sink the import")
        let notes = RuntimeOSMCourseConverter.importNotes(for: course)
        XCTAssertEqual(notes.count, 1)
        XCTAssertTrue(notes[0].hasPrefix("Hole 4: green estimated"))
        // Every other hole keeps its mapped green.
        XCTAssertEqual(course.holes.filter { $0.features.contains { $0.label == "Green" } }.count, 8)
    }

    func testADoubleGreenIsSplitBetweenItsTwoFlags() throws {
        // As at Westgate (holes 4 and 6): one green is drawn for two holes,
        // with a flag for each ~28 m apart. The green goes to hole 3's line;
        // hole 4 plays back to the other end of it.
        let raw = try synthetic9HolePayload(courseName: "Double", withoutGreenOnHoles: [4], pinOffsetMetres: 0)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        var elements = try XCTUnwrap(json["elements"] as? [[String: Any]])
        let greenLat = -37.97 + 2 * 0.005 + 0.0024
        let lon = 145.03
        let flag4 = (lat: greenLat, lon: lon + 0.00032)
        for index in elements.indices {
            switch elements[index]["id"] as? Int {
            case 1_003: // hole 4 now finishes on hole 3's green
                elements[index]["geometry"] = [["lat": -37.955, "lon": lon], ["lat": flag4.lat, "lon": flag4.lon]]
            case 3_002: // hole 3's green is long enough for both flags
                elements[index]["geometry"] = [
                    ["lat": greenLat - 0.0001, "lon": lon - 0.00012],
                    ["lat": greenLat - 0.0001, "lon": lon + 0.0004],
                    ["lat": greenLat + 0.0001, "lon": lon + 0.0004],
                    ["lat": greenLat + 0.0001, "lon": lon - 0.00012],
                    ["lat": greenLat - 0.0001, "lon": lon - 0.00012]
                ]
            case 4_003: // hole 4's flag
                elements[index]["lat"] = flag4.lat
                elements[index]["lon"] = flag4.lon
            default:
                break
            }
        }
        json["elements"] = elements
        let course = try RuntimeOSMCourseConverter.convert(
            rawOSM: try JSONSerialization.data(withJSONObject: json),
            for: discovered(named: "Double")
        )

        let green3 = try XCTUnwrap(course.holes[2].features.first { $0.kind == .green })
        let green4 = try XCTUnwrap(course.holes[3].features.first { $0.kind == .green })
        XCTAssertEqual(green3.label, "Green (shared with hole 4)")
        XCTAssertEqual(green4.label, "Green (shared with hole 3)")

        // Each hole measures to its own half, centred near its own flag.
        func metresFromCentre(_ feature: SwingPalCourse.Hole.Feature, to lat: Double, _ lon: Double) throws -> Double {
            let centre = try XCTUnwrap(RuntimeOSMCourseConverter.centroid(of: feature.coordinates))
            return RuntimeOSMCourseConverter.haversineMeters(
                .init(latitude: centre.latitude, longitude: centre.longitude),
                .init(latitude: lat, longitude: lon)
            )
        }
        // (The whole green's centre is ~8 m from hole 3's flag and ~20 m from hole 4's.)
        XCTAssertLessThan(try metresFromCentre(green3, to: greenLat, lon), 5)
        XCTAssertLessThan(try metresFromCentre(green4, to: flag4.lat, flag4.lon), 8)

        XCTAssertEqual(DeterministicCourseValidator.validate(course), [])
        XCTAssertEqual(
            RuntimeOSMCourseConverter.importNotes(for: course),
            ["Holes 3 and 4 share a double green. Each hole measures to its own half, split between the two flags."]
        )
    }

    func testSplittingAGreenKeepsEachFlagOnItsOwnSide() throws {
        let origin = SwingPalCourse.Coordinate(latitude: -37.82, longitude: 144.88)
        let plane = RuntimeOSMCourseConverter.LocalPlane(origin: origin)
        let ring = [(-30.0, -10.0), (30, -10), (30, 10), (-30, 10), (-30, -10)].map { plane.coordinate(($0.0, $0.1)) }
        let a = plane.coordinate((-15, 0)), b = plane.coordinate((15, 0))

        let halves = try XCTUnwrap(RuntimeOSMCourseConverter.split(ring, between: a, and: b))
        XCTAssertTrue(RuntimeOSMCourseConverter.ringContains(halves.nearA, a))
        XCTAssertFalse(RuntimeOSMCourseConverter.ringContains(halves.nearA, b))
        XCTAssertTrue(RuntimeOSMCourseConverter.ringContains(halves.nearB, b))
        XCTAssertEqual(halves.nearA.first, halves.nearA.last)
        // Flags on top of each other can't be split.
        XCTAssertNil(RuntimeOSMCourseConverter.split(ring, between: a, and: plane.coordinate((-13, 0))))
    }

    func testMissingGreenWithoutAPinSitsAtTheGreenEndOfTheHoleLine() throws {
        let raw = try synthetic9HolePayload(courseName: "Gap Course", withoutGreenOnHoles: [2])
        let course = try RuntimeOSMCourseConverter.convert(rawOSM: raw, for: discovered(named: "Gap Course"))
        let green = try XCTUnwrap(course.holes[1].features.first { $0.kind == .green })
        let centre = try XCTUnwrap(RuntimeOSMCourseConverter.centroid(of: green.coordinates))
        XCTAssertEqual(centre.latitude, -37.97 + 0.005 + 0.0024, accuracy: 0.00002)
    }

    func testMissingTeeIsEstimatedAtTheTeeEnd() throws {
        let raw = try synthetic9HolePayload(courseName: "Gap Course", withoutTeeOnHoles: [7])
        let course = try RuntimeOSMCourseConverter.convert(rawOSM: raw, for: discovered(named: "Gap Course"))
        let tee = try XCTUnwrap(course.holes[6].features.first { $0.kind == .tee })
        XCTAssertTrue(tee.label.hasSuffix("(estimated)"))
        let centre = try XCTUnwrap(RuntimeOSMCourseConverter.centroid(of: tee.coordinates))
        XCTAssertEqual(centre.latitude, -37.97 + 6 * 0.005, accuracy: 0.00002)
        XCTAssertTrue(DeterministicCourseValidator.validate(course).isEmpty)
    }

    func testMissingHoleNumbersAreNamed() throws {
        // Sixteen holes whose refs go to 18: holes 5 and 12 aren't mapped.
        let refs = Array(1...18).filter { $0 != 5 && $0 != 12 }
        let raw = try synthetic9HolePayload(courseName: "Partial", holeCount: refs.count, refs: refs)
        XCTAssertThrowsError(try RuntimeOSMCourseConverter.convert(rawOSM: raw, for: discovered(named: "Partial"))) { error in
            XCTAssertEqual(error as? RuntimeOSMCourseConverter.ConversionError, .incompleteCourse(expected: 18, missing: [5, 12]))
            XCTAssertEqual((error as? LocalizedError)?.errorDescription, "OpenStreetMap has 16 of this course's 18 holes mapped (missing holes 5, 12).")
        }
    }

    private func discovered(named name: String) -> DiscoveredCourse {
        DiscoveredCourse(
            id: "way-200",
            name: name,
            coordinate: .init(latitude: -37.97, longitude: 145.03),
            osmID: 200,
            osmType: .way,
            countryCode: "AU",
            region: nil,
            distanceKilometers: nil
        )
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
        centre: SwingPalCourse.Coordinate = .init(latitude: -37.97, longitude: 145.03),
        refs: [Int]? = nil,
        withoutGreenOnHoles: Set<Int> = [],
        withoutTeeOnHoles: Set<Int> = [],
        pinOffsetMetres: Double? = nil
    ) throws -> Data {
        var elements: [[String: Any]] = []
        for index in 0..<holeCount {
            let ref = refs?[index] ?? (index + 1)
            let baseLat = centre.latitude + Double(index) * 0.005
            let baseLon = centre.longitude

            let teeLat = baseLat
            let greenLat = baseLat + 0.0024 // ~270 m north
            let lon = baseLon

            var holeTags: [String: String] = [
                "golf": "hole",
                "ref": String(ref)
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

            if !withoutTeeOnHoles.contains(ref) {
                elements.append([
                    "type": "way",
                    "id": 2_000 + index,
                    "tags": ["golf": "tee"],
                    "geometry": teeBox(around: .init(latitude: teeLat, longitude: lon))
                ])
            }

            if !withoutGreenOnHoles.contains(ref) {
                elements.append([
                    "type": "way",
                    "id": 3_000 + index,
                    "tags": ["golf": "green"],
                    "geometry": greenBox(around: .init(latitude: greenLat, longitude: lon))
                ])
            }

            if let pinOffsetMetres {
                elements.append([
                    "type": "node",
                    "id": 4_000 + index,
                    "lat": greenLat + pinOffsetMetres / 110_540,
                    "lon": lon,
                    "tags": ["golf": "pin"]
                ])
            }
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
