import XCTest
@testable import SwingPal

final class StatsViewModelTests: XCTestCase {

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

        XCTAssertEqual(model.sections.map(\.title), ["Penalties", "Scoring", "Round History", "Putting"])
        XCTAssertEqual(model.sections[0].facts.map(\.title), ["Latest Penalties", "Recent Avg", "Penalty-Free"])
        XCTAssertEqual(model.sections[0].facts.map(\.value), ["1", "2.0", "0 / 2"])
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

}

private extension StatsViewModelTests {
    func round(status: RoundHistorySummary.Status = .finished, holes: Int = 18,
               strokes: Int = 76, putts: Int = 31, penalties: Int = 1, time: Double) -> RoundHistorySummary {
        RoundHistorySummary(id: UUID(), courseName: "Course", status: status,
                            holeNumber: holes, totalHoleCount: holes, playerCount: 1,
                            totalStrokes: strokes, completedHoleCount: holes,
                            totalPutts: putts, totalPenalties: penalties,
                            updatedAt: Date(timeIntervalSince1970: time))
    }
}

extension StatsViewModelTests {
    func testUnfinishedRoundDoesNotCreateImprovementOrChangePerformanceAverages() {
        let finished = round(penalties: 3, time: 1_000)
        let checkpoint = round(status: .unfinished, holes: 3, strokes: 12, putts: 6,
                               penalties: 0, time: 2_000)
        let model = StatsViewModel(previousRounds: [checkpoint, finished], analyses: [])
        XCTAssertEqual(model.trendSignalTone, .neutral)
        XCTAssertEqual(model.trendSignalTitle, "Latest scorecard loaded")
        XCTAssertEqual(model.sections[0].facts.map(\.value), ["3", "3.0", "0 / 1"])
    }

    func testDifferentRoundLengthsAreNotComparedAsImprovement() {
        let model = StatsViewModel(previousRounds: [
            round(holes: 9, strokes: 39, putts: 16, penalties: 1, time: 2_000),
            round(strokes: 74, putts: 30, penalties: 2, time: 1_000)
        ], analyses: [])
        XCTAssertEqual(model.trendSignalTone, .neutral)
        XCTAssertEqual(model.sections[1].facts.last?.value, "39")
        XCTAssertEqual(model.sections[0].facts[1].detail, "Last 1 finished 9-hole round")
    }

    func testEqualPuttingAndPenaltiesDoNotClaimEqualScores() {
        let model = StatsViewModel(previousRounds: [
            round(strokes: 99, time: 2_000), round(strokes: 76, time: 1_000)
        ], analyses: [])
        XCTAssertEqual(model.trendSignalTitle, "Penalty and putting totals unchanged")
        XCTAssertFalse(model.trendSignalDetail.contains("similar range"))
    }

    func testOnlyCheckpointsDoNotBecomeBestRoundsOrPerformanceStats() {
        let model = StatsViewModel(previousRounds: [round(status: .unfinished, time: 1_000)], analyses: [])
        XCTAssertEqual(model.trendSignalTitle, "No trend yet")
        XCTAssertTrue(model.sections[0].facts.allSatisfy { $0.value == "--" })
        XCTAssertTrue(model.sections[1].facts.allSatisfy { $0.value == "--" })
        XCTAssertEqual(model.sections[2].facts[1].value, "1")
        XCTAssertTrue(model.sections[3].facts.allSatisfy { $0.value == "--" })
    }
}
