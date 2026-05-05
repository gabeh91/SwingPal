import XCTest
@testable import SwingPal

final class StatsViewModelTests: XCTestCase {
    func testStatsModelUsesLatestRoundAnalysisAsHero() {
        let summary = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .finished,
            holeNumber: 18,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 76,
            completedHoleCount: 18,
            totalPutts: 31,
            totalPenalties: 1,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let analysis = RoundSummaryAnalysis(
            roundID: summary.id,
            cacheKey: RoundSummaryAnalysis.CacheKey(summary: summary).rawValue,
            provider: .foundationModels,
            summary: "Approach play held the card together, but one loose swing still cost a shot.",
            whatWentWell: ["Solid iron control", "Good pace putting", "Finished cleanly"],
            needsWork: ["Penalty avoidance", "Start lines", "Commitment under pressure"],
            generatedAt: Date(timeIntervalSince1970: 2_010)
        )

        let model = StatsViewModel(
            previousRounds: [summary],
            analyses: [analysis]
        )

        XCTAssertEqual(model.heroTitle, "Latest Round Intelligence")
        XCTAssertEqual(model.heroCourseName, "Royal Melbourne")
        XCTAssertEqual(model.heroSummary, analysis.summary)
        XCTAssertEqual(model.heroStrengths, ["Solid iron control", "Good pace putting", "Finished cleanly"])
        XCTAssertEqual(model.heroSnapshotFacts.map(\.title), ["Latest Score", "Rounds Tracked", "Finished Cards"])
        XCTAssertEqual(model.heroSnapshotFacts.map(\.value), ["76", "1", "1"])
    }

    func testStatsModelBuildsHybridTrendSignalFromRecentRounds() {
        let recent = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .finished,
            holeNumber: 18,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 74,
            completedHoleCount: 18,
            totalPutts: 30,
            totalPenalties: 1,
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        let prior = RoundHistorySummary(
            id: UUID(),
            courseName: "Kingston Heath",
            status: .finished,
            holeNumber: 18,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 79,
            completedHoleCount: 18,
            totalPutts: 34,
            totalPenalties: 3,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        let model = StatsViewModel(
            previousRounds: [recent, prior],
            analyses: []
        )

        XCTAssertEqual(model.trendSignalTitle, "Penalty control improved")
        XCTAssertEqual(model.trendSignalValue, "1 penalty")
        XCTAssertEqual(model.trendSignalDetail, "Down from 3 in the previous round.")
        XCTAssertEqual(model.trendSignalTone, .positive)
    }

    func testStatsModelBuildsSkillAreaSectionsFromTrackedRoundFacts() {
        let recent = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .finished,
            holeNumber: 18,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 76,
            completedHoleCount: 18,
            totalPutts: 31,
            totalPenalties: 1,
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        let prior = RoundHistorySummary(
            id: UUID(),
            courseName: "Kingston Heath",
            status: .finished,
            holeNumber: 18,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 79,
            completedHoleCount: 18,
            totalPutts: 34,
            totalPenalties: 3,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let checkpoint = RoundHistorySummary(
            id: UUID(),
            courseName: "The National",
            status: .unfinished,
            holeNumber: 15,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 63,
            completedHoleCount: 15,
            totalPutts: 27,
            totalPenalties: 0,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        let model = StatsViewModel(
            previousRounds: [recent, prior, checkpoint],
            analyses: []
        )

        XCTAssertEqual(model.sections.map(\.title), ["Driving", "Approach", "Short Game", "Putting"])
        XCTAssertEqual(model.sections[0].facts.map(\.title), ["Latest Penalties", "Recent Avg", "Penalty-Free"])
        XCTAssertEqual(model.sections[0].facts.map(\.value), ["1", "1.3", "1 / 3"])
        XCTAssertEqual(model.sections[1].facts.map(\.title), ["Latest Strokes / Hole", "Recent Avg", "Best Score"])
        XCTAssertEqual(model.sections[1].facts.map(\.value), ["4.2", "4.3", "76"])
        XCTAssertEqual(model.sections[2].facts.map(\.title), ["Finished Rounds", "Saved Checkpoints", "Hole Completion"])
        XCTAssertEqual(model.sections[2].facts.map(\.value), ["2", "1", "94%"])
        XCTAssertEqual(model.sections[3].facts.map(\.title), ["Latest Putts / Hole", "Recent Avg", "Best Round"])
        XCTAssertEqual(model.sections[3].facts.map(\.value), ["1.7", "1.8", "31"])
    }

    func testStatsModelUsesCautionToneWhenPenaltyLoadClimbs() {
        let recent = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .finished,
            holeNumber: 18,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 78,
            completedHoleCount: 18,
            totalPutts: 32,
            totalPenalties: 3,
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        let prior = RoundHistorySummary(
            id: UUID(),
            courseName: "Kingston Heath",
            status: .finished,
            holeNumber: 18,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 77,
            completedHoleCount: 18,
            totalPutts: 31,
            totalPenalties: 1,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        let model = StatsViewModel(
            previousRounds: [recent, prior],
            analyses: []
        )

        XCTAssertEqual(model.trendSignalTitle, "Penalty load climbed")
        XCTAssertEqual(model.trendSignalTone, .caution)
    }

    func testStatsModelBuildsRichRecentRoundCards() {
        let finished = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .finished,
            holeNumber: 18,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 76,
            completedHoleCount: 18,
            totalPutts: 31,
            totalPenalties: 1,
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        let unfinished = RoundHistorySummary(
            id: UUID(),
            courseName: "The National",
            status: .unfinished,
            holeNumber: 15,
            totalHoleCount: 18,
            playerCount: 2,
            totalStrokes: 63,
            completedHoleCount: 15,
            totalPutts: 27,
            totalPenalties: 0,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        let model = StatsViewModel(
            previousRounds: [finished, unfinished],
            analyses: []
        )

        XCTAssertEqual(model.recentRoundCards.count, 2)

        let first = model.recentRoundCards[0]
        XCTAssertEqual(first.courseName, "Royal Melbourne")
        XCTAssertEqual(first.statusTitle, "Finished Round")
        XCTAssertEqual(first.scoreValue, "76")
        XCTAssertEqual(first.scoreCaption, "strokes")
        XCTAssertEqual(first.progressLabel, "18 / 18 holes")
        XCTAssertEqual(first.progressValue, 1.0)
        XCTAssertEqual(first.metadataPills, ["31 putts", "1 penalty", "1 golfer"])

        let second = model.recentRoundCards[1]
        XCTAssertEqual(second.courseName, "The National")
        XCTAssertEqual(second.statusTitle, "Saved to Resume")
        XCTAssertEqual(second.scoreValue, "63")
        XCTAssertEqual(second.progressLabel, "15 / 18 holes")
        XCTAssertEqual(second.progressValue, 15.0 / 18.0, accuracy: 0.0001)
        XCTAssertEqual(second.metadataPills, ["27 putts", "0 penalties", "2 golfers"])
    }

    func testStatsModelBuildsOverviewHighlightsForSkillAreas() {
        let recent = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .finished,
            holeNumber: 18,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 76,
            completedHoleCount: 18,
            totalPutts: 31,
            totalPenalties: 1,
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        let prior = RoundHistorySummary(
            id: UUID(),
            courseName: "Kingston Heath",
            status: .finished,
            holeNumber: 18,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 79,
            completedHoleCount: 18,
            totalPutts: 34,
            totalPenalties: 3,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let checkpoint = RoundHistorySummary(
            id: UUID(),
            courseName: "The National",
            status: .unfinished,
            holeNumber: 15,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 63,
            completedHoleCount: 15,
            totalPutts: 27,
            totalPenalties: 0,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        let model = StatsViewModel(
            previousRounds: [recent, prior, checkpoint],
            analyses: []
        )

        XCTAssertEqual(model.overviewHighlights.map(\.title), ["Driving", "Approach", "Short Game", "Putting"])
        XCTAssertEqual(model.overviewHighlights.map(\.value), ["1", "4.3", "94%", "1.8"])
        XCTAssertEqual(model.overviewHighlights.map(\.detail), ["latest penalties", "recent strokes / hole", "hole completion", "recent putts / hole"])
    }
}
