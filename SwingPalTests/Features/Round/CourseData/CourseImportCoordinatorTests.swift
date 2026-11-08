import XCTest
@testable import SwingPal

final class CourseImportCoordinatorTests: XCTestCase {
    func testImportEmitsExpectedStagesForSyntheticCourse() async throws {
        let raw = try syntheticPayload()
        let coordinator = CourseImportCoordinator(
            fetcher: StubGeometryFetcher(payload: raw),
            aiValidator: StubAIValidator(review: .unavailable)
        )

        let stages = await collectStages(
            from: coordinator.importCourse(stubDiscoveredCourse())
        )

        XCTAssertEqual(stages.map(\.id), [
            "fetchingGeometry",
            "converting",
            "runningDeterministicGates",
            "runningAIReview",
            "completed"
        ])
    }

    func testImportFailsLoudlyWhenDeterministicGatesFail() async {
        // Empty payload → no holes → conversion fails → coordinator emits
        // `failed`, never reaches the AI step.
        let coordinator = CourseImportCoordinator(
            fetcher: StubGeometryFetcher(payload: Data(#"{"elements":[]}"#.utf8)),
            aiValidator: StubAIValidator(review: .unavailable)
        )

        let stages = await collectStages(
            from: coordinator.importCourse(stubDiscoveredCourse())
        )

        XCTAssertEqual(stages.last?.id, "failed")
        XCTAssertFalse(stages.contains(where: { $0.id == "runningAIReview" }))
    }

    func testImportEmitsProvisionalOutcomeWhenAIIsUnavailable() async throws {
        let raw = try syntheticPayload()
        let coordinator = CourseImportCoordinator(
            fetcher: StubGeometryFetcher(payload: raw),
            aiValidator: StubAIValidator(review: .unavailable)
        )

        let stages = await collectStages(
            from: coordinator.importCourse(stubDiscoveredCourse())
        )

        guard case .completed(let course, let validation) = stages.last else {
            XCTFail("Expected completed stage; got \(String(describing: stages.last))")
            return
        }
        XCTAssertEqual(validation.outcome, .provisional)
        XCTAssertFalse(validation.aiAvailable)
        XCTAssertEqual(course.quality.overallConfidence, .provisional)
    }

    func testImportEmitsApprovedWhenAIReturnsOK() async throws {
        let raw = try syntheticPayload()
        let coordinator = CourseImportCoordinator(
            fetcher: StubGeometryFetcher(payload: raw),
            aiValidator: StubAIValidator(review: AICourseReview(
                verdict: .ok,
                concerns: [],
                oneLineSummary: "Looks great",
                aiAvailable: true
            ))
        )
        let stages = await collectStages(
            from: coordinator.importCourse(stubDiscoveredCourse())
        )

        guard case .completed(let course, let validation) = stages.last else {
            XCTFail("Expected completed stage; got \(String(describing: stages.last))")
            return
        }
        XCTAssertEqual(validation.outcome, .approved)
        XCTAssertEqual(course.quality.overallConfidence, .reviewed)
    }

    func testImportEmitsFailedWhenAIReturnsBroken() async throws {
        let raw = try syntheticPayload()
        let coordinator = CourseImportCoordinator(
            fetcher: StubGeometryFetcher(payload: raw),
            aiValidator: StubAIValidator(review: AICourseReview(
                verdict: .broken,
                concerns: ["Half the holes are missing greens."],
                oneLineSummary: "Course geometry is too sparse to play.",
                aiAvailable: true
            ))
        )
        let stages = await collectStages(
            from: coordinator.importCourse(stubDiscoveredCourse())
        )
        XCTAssertEqual(stages.last?.id, "failed")
    }

    // MARK: - Helpers

    private func collectStages(
        from stream: AsyncStream<CourseImportStage>
    ) async -> [CourseImportStage] {
        var collected: [CourseImportStage] = []
        for await stage in stream {
            collected.append(stage)
        }
        return collected
    }

    private func stubDiscoveredCourse() -> DiscoveredCourse {
        DiscoveredCourse(
            id: "way-200",
            name: "Stub Course",
            coordinate: .init(latitude: -37.97, longitude: 145.03),
            osmID: 200,
            osmType: .way,
            countryCode: "AU",
            region: "Victoria",
            distanceKilometers: 4.5
        )
    }

    private func syntheticPayload() throws -> Data {
        var elements: [[String: Any]] = []
        for index in 0..<9 {
            let baseLat = -37.97 + Double(index) * 0.005
            let lon = 145.03

            elements.append([
                "type": "way",
                "id": 1_000 + index,
                "tags": ["golf": "hole", "ref": String(index + 1)],
                "geometry": [
                    ["lat": baseLat, "lon": lon],
                    ["lat": baseLat + 0.0024, "lon": lon]
                ]
            ])
            elements.append([
                "type": "way",
                "id": 2_000 + index,
                "tags": ["golf": "tee"],
                "geometry": polygon(around: .init(latitude: baseLat, longitude: lon))
            ])
            elements.append([
                "type": "way",
                "id": 3_000 + index,
                "tags": ["golf": "green"],
                "geometry": polygon(around: .init(latitude: baseLat + 0.0024, longitude: lon))
            ])
        }
        return try JSONSerialization.data(withJSONObject: ["elements": elements])
    }

    private func polygon(around point: SwingPalCourse.Coordinate) -> [[String: Double]] {
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

private struct StubGeometryFetcher: OSMCourseGeometryFetching {
    let payload: Data
    func fetchGeometry(for course: DiscoveredCourse) async throws -> Data { payload }
}

private struct StubAIValidator: AICourseValidating {
    let review: AICourseReview
    func review(_ course: SwingPalCourse) async -> AICourseReview { review }
}
