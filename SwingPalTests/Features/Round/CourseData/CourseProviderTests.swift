import XCTest
@testable import SwingPal

final class CourseProviderTests: XCTestCase {
    func testSeededOpenGolfLoaderReturnsProviderPayloadForKnownCourse() throws {
        let loader = SeededOpenGolfCourseLoader()

        let payload = try XCTUnwrap(loader.coursePayload(named: "Royal Melbourne"))

        XCTAssertEqual(payload.externalID, "og-royal-melbourne")
        XCTAssertEqual(payload.par, 72)
        XCTAssertEqual(payload.holeCount, 18)
        XCTAssertEqual(payload.teeNames, ["Championship", "Member", "Forward"])
    }

    func testSeededOSMLoaderReturnsGeometryPayloadForKnownCourse() throws {
        let loader = SeededOSMCourseGeometryLoader()

        let payload = try XCTUnwrap(loader.geometryPayload(named: "Royal Melbourne"))

        XCTAssertEqual(payload.externalID, "osm-royal-melbourne")
        XCTAssertEqual(payload.coordinate.latitude, -37.9742, accuracy: 0.0001)
        XCTAssertEqual(payload.coordinate.longitude, 145.0338, accuracy: 0.0001)
        XCTAssertGreaterThan(payload.featureCount, 0)
    }
}
