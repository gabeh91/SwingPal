import XCTest
@testable import SwingPal

final class FoundationModelsCourseValidatorTests: XCTestCase {
    func testReviewMapsOKVerdictWithAvailability() async {
        let session = StubSession(result: .success(FoundationModelsCourseReviewResponse(
            verdict: "ok",
            concerns: [],
            oneLineSummary: "Course looks great."
        )))
        let validator = FoundationModelsCourseValidator(session: session)
        let review = await validator.review(.test(name: "Stub", distanceKilometers: 0))

        XCTAssertEqual(review.verdict, .ok)
        XCTAssertTrue(review.aiAvailable)
        XCTAssertEqual(review.oneLineSummary, "Course looks great.")
    }

    func testReviewMapsConcernsVerdictWithBullets() async {
        let session = StubSession(result: .success(FoundationModelsCourseReviewResponse(
            verdict: "concerns",
            concerns: [
                "12 of 18 holes have no fairway polygon at all.",
                "Greens are unusually small (~50 m²)."
            ],
            oneLineSummary: "Geometry is sparse but playable."
        )))
        let validator = FoundationModelsCourseValidator(session: session)
        let review = await validator.review(.test(name: "Stub", distanceKilometers: 0))

        XCTAssertEqual(review.verdict, .concerns)
        XCTAssertEqual(review.concerns.count, 2)
        XCTAssertTrue(review.aiAvailable)
    }

    func testReviewMapsBrokenVerdictAsBroken() async {
        let session = StubSession(result: .success(FoundationModelsCourseReviewResponse(
            verdict: "broken",
            concerns: ["No greens detected on any hole."],
            oneLineSummary: "Course geometry is unusable."
        )))
        let validator = FoundationModelsCourseValidator(session: session)
        let review = await validator.review(.test(name: "Stub", distanceKilometers: 0))

        XCTAssertEqual(review.verdict, .broken)
        XCTAssertTrue(review.aiAvailable)
    }

    func testReviewFallsBackToUnavailableWhenModelUnavailable() async {
        let session = StubSession(
            result: .failure(FoundationModelsCourseValidatorError.modelUnavailable)
        )
        let validator = FoundationModelsCourseValidator(session: session)
        let review = await validator.review(.test(name: "Stub", distanceKilometers: 0))

        XCTAssertEqual(review.verdict, .ok)
        XCTAssertFalse(review.aiAvailable)
        XCTAssertNil(review.oneLineSummary)
    }

    func testReviewFallsBackToUnavailableWhenFrameworkUnavailable() async {
        let session = StubSession(
            result: .failure(FoundationModelsCourseValidatorError.frameworkUnavailable)
        )
        let validator = FoundationModelsCourseValidator(session: session)
        let review = await validator.review(.test(name: "Stub", distanceKilometers: 0))

        XCTAssertEqual(review.verdict, .ok)
        XCTAssertFalse(review.aiAvailable)
    }

    func testReviewFallsBackToUnavailableWhenResponseUnparseable() async {
        let session = StubSession(
            result: .failure(FoundationModelsCourseValidatorError.invalidResponse)
        )
        let validator = FoundationModelsCourseValidator(session: session)
        let review = await validator.review(.test(name: "Stub", distanceKilometers: 0))

        XCTAssertFalse(review.aiAvailable)
    }

    func testParseResponseContentExtractsJSONFromNoise() throws {
        let raw = """
        Sure, here's the JSON:
        {"verdict":"concerns","concerns":["Half the holes are missing fairways."],"oneLineSummary":"Sparse geometry."}
        Hope that helps!
        """
        let parsed = try FoundationModelsCourseValidator.parseResponseContent(raw)
        XCTAssertEqual(parsed.verdict, "concerns")
        XCTAssertEqual(parsed.concerns.count, 1)
    }

    func testStructuredSummaryCapturesParDistribution() {
        let course = SwingPalCourse.test(name: "Stub", distanceKilometers: 0)
        let summary = FoundationModelsCourseValidator.makeStructuredSummary(for: course)

        XCTAssertEqual(summary.holeCount, course.holes.count)
        XCTAssertEqual(summary.totalPar, course.holes.reduce(0) { $0 + $1.par })
        XCTAssertEqual(summary.featureCountsPerHole.count, course.holes.count)
        XCTAssertEqual(summary.par3HoleCount + summary.par4HoleCount + summary.par5HoleCount, course.holes.count)
    }
}

private struct StubSession: FoundationModelsCourseSessioning {
    let result: Result<FoundationModelsCourseReviewResponse, Error>

    func review(prompt: String) async throws -> FoundationModelsCourseReviewResponse {
        try result.get()
    }
}
