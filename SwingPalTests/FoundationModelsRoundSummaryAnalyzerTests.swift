import XCTest
@testable import SwingPal

final class FoundationModelsRoundSummaryAnalyzerTests: XCTestCase {
    func testStructuredPromptModelMapsIntoRoundSummaryAnalysis() async throws {
        let summary = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .unfinished,
            holeNumber: 7,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 27,
            completedHoleCount: 4,
            totalPutts: 6,
            totalPenalties: 2,
            updatedAt: .distantPast
        )

        let session = StubFoundationModelsSession(
            result: .init(
                summary: "You kept the round organized through the holes you completed.",
                whatWentWell: [
                    "You tracked the short game well.",
                    "You gave yourself a usable scoring baseline."
                ],
                needsWork: [
                    "Penalties were the clearest scoring leak.",
                    "Finishing more holes will strengthen the pattern."
                ]
            )
        )

        let analyzer = FoundationModelsRoundSummaryAnalyzer(session: session)

        let analysis = try await analyzer.generateAnalysis(for: summary)

        XCTAssertEqual(analysis.provider, .foundationModels)
        XCTAssertEqual(analysis.whatWentWell.count, 2)
        XCTAssertEqual(analysis.needsWork.count, 2)
    }

    func testStructuredPromptModelPreservesMoreThanTwoAnalysisPoints() async throws {
        let summary = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .unfinished,
            holeNumber: 7,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 27,
            completedHoleCount: 4,
            totalPutts: 6,
            totalPenalties: 2,
            updatedAt: .distantPast
        )

        let session = StubFoundationModelsSession(
            result: .init(
                summary: "You kept enough signal in the round to identify several useful patterns.",
                whatWentWell: [
                    "You tracked the short game well.",
                    "You created a usable scoring baseline.",
                    "You logged enough shots to make the recap more trustworthy."
                ],
                needsWork: [
                    "Penalties were the clearest scoring leak.",
                    "Finishing more holes will strengthen the pattern.",
                    "A cleaner tee-ball pattern would reduce recovery shots."
                ]
            )
        )

        let analyzer = FoundationModelsRoundSummaryAnalyzer(session: session)

        let analysis = try await analyzer.generateAnalysis(for: summary)

        XCTAssertEqual(analysis.whatWentWell.count, 3)
        XCTAssertEqual(analysis.needsWork.count, 3)
    }

    func testParsesJSONStringResponseIntoStructuredRoundSummary() throws {
        let raw = """
        {
          "summary": "You stayed organized through the holes you completed.",
          "whatWentWell": ["You tracked the short game well.", "You created a useful scoring baseline."],
          "needsWork": ["Penalties remain the clearest scoring leak.", "Finishing more holes will sharpen the pattern."]
        }
        """

        let parsed = try FoundationModelsRoundSummaryAnalyzer.parseResponseContent(raw)

        XCTAssertEqual(parsed.summary, "You stayed organized through the holes you completed.")
        XCTAssertEqual(parsed.whatWentWell.count, 2)
        XCTAssertEqual(parsed.needsWork.count, 2)
    }
}

private struct StubFoundationModelsSession: FoundationModelsRoundSummarySessioning {
    let result: FoundationModelsRoundSummaryResponse

    func generate(prompt: String) async throws -> FoundationModelsRoundSummaryResponse {
        result
    }
}
