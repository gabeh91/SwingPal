import XCTest
@testable import SwingPal

final class FoundationModelsRoundSummaryAnalyzerTests: XCTestCase {
    func testModelNotesAreKeptWhenTheyCiteTheCard() async throws {
        let summary = RoundRecapWriterTests.summary(RoundRecapWriterTests.sampleCard())
        let session = StubFoundationModelsSession(
            result: .init(
                summary: "You shot 38, 2 over, with two birdies.",
                whatWentWell: [
                    "Birdies on the 3rd and 8th.",
                    "Five straight holes at par or better from the 2nd.",
                    "You saved par on the 2nd without the green."
                ],
                needsWork: [
                    "The 7th cost you a double with a penalty.",
                    "A three-putt on the 7th."
                ]
            )
        )

        let analysis = try await FoundationModelsRoundSummaryAnalyzer(session: session).generateAnalysis(for: summary)

        XCTAssertEqual(analysis.provider, .foundationModels)
        XCTAssertEqual(analysis.summary, "You shot 38, 2 over, with two birdies.")
        XCTAssertEqual(analysis.whatWentWell.count, 3)
        XCTAssertEqual(analysis.needsWork.count, 2)
    }

    func testFillerAndTalkAboutTheAppAreDropped() async throws {
        let summary = RoundRecapWriterTests.summary(RoundRecapWriterTests.sampleCard())
        let session = StubFoundationModelsSession(
            result: .init(
                summary: "You logged a solid round.",
                whatWentWell: [
                    "You completed 9 holes before saving.",
                    "Good rhythm overall.",
                    "Birdies on the 3rd and 8th."
                ],
                needsWork: [
                    "Keep logging each hole cleanly.",
                    "Double bogey on the 7th."
                ]
            )
        )

        let analysis = try await FoundationModelsRoundSummaryAnalyzer(session: session).generateAnalysis(for: summary)

        XCTAssertEqual(analysis.whatWentWell, ["Birdies on the 3rd and 8th."])
        XCTAssertEqual(analysis.needsWork, ["Double bogey on the 7th."])
        XCTAssertEqual(analysis.summary, RoundRecapWriter.summaryLine(for: summary), "An unusable summary falls back to the card's")
    }

    func testAllUnusableNotesFallBackToTheWriter() async {
        let summary = RoundRecapWriterTests.summary(RoundRecapWriterTests.sampleCard())
        let session = StubFoundationModelsSession(
            result: .init(summary: "Nice round.", whatWentWell: ["Great tracking."], needsWork: ["Keep logging."])
        )
        do {
            _ = try await FoundationModelsRoundSummaryAnalyzer(session: session).generateAnalysis(for: summary)
            XCTFail("Expected the analyzer to give way to the writer")
        } catch {}
    }

    func testRoundsWithoutACardAreLeftToTheWriter() async {
        let summary = RoundRecapWriterTests.summary([])
        let session = StubFoundationModelsSession(
            result: .init(summary: "Shot 38.", whatWentWell: ["Birdie on the 3rd."], needsWork: [])
        )
        do {
            _ = try await FoundationModelsRoundSummaryAnalyzer(session: session).generateAnalysis(for: summary)
            XCTFail("Totals alone aren't enough to send to the model")
        } catch {}
    }

    func testPromptCarriesTheCardAndTheWorkedOutPoints() {
        let prompt = FoundationModelsRoundSummaryAnalyzer.makePrompt(
            for: RoundRecapWriterTests.summary(RoundRecapWriterTests.sampleCard())
        )
        XCTAssertTrue(prompt.contains("Score: 38 against a par of 36 (2 over)"), prompt)
        XCTAssertTrue(prompt.contains("Hole 7: par 4, scored 6 (2 over), 3 putts, 1 penalty stroke, fairway missed, green missed in regulation"), prompt)
        XCTAssertTrue(prompt.contains("- Birdies on the 3rd and 8th."), prompt)
        XCTAssertTrue(prompt.contains("- Double bogey on the 7th."), prompt)
    }

    func testPromptCarriesWhatHappenedAroundTheGreen() {
        let card: [RoundHistorySummary.HoleRecord] = [
            .init(number: 1, par: 4, score: 4, putts: 1, shortGameShots: 1, upAndDown: true, firstPuttMeters: 2),
            .init(number: 2, par: 4, score: 6, putts: 2, shortGameShots: 2, upAndDown: false, sandSave: false),
            .init(number: 3, par: 4, score: 3, putts: 0, shortGameShots: 1, upAndDown: true, chippedIn: true)
        ]
        let prompt = FoundationModelsRoundSummaryAnalyzer.makePrompt(for: RoundRecapWriterTests.summary(card))

        XCTAssertTrue(prompt.contains("1 putt, up and down, first putt from 2 m"), prompt)
        XCTAssertTrue(prompt.contains("2 putts, no sand save, 2 shots around the green"), prompt)
        XCTAssertTrue(prompt.contains("holed out from off the green"), prompt)
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
