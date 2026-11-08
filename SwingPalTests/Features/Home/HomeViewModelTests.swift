import XCTest
@testable import SwingPal

final class HomeViewModelTests: XCTestCase {
    private let latestRound = RoundHistorySummary(
        id: UUID(),
        courseName: "The National",
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

    private let olderRound = RoundHistorySummary(
        id: UUID(),
        courseName: "Moonah Links",
        status: .finished,
        holeNumber: 18,
        totalHoleCount: 18,
        playerCount: 1,
        totalStrokes: 79,
        completedHoleCount: 18,
        totalPutts: 33,
        totalPenalties: 2,
        updatedAt: Date(timeIntervalSince1970: 1_000)
    )

    func testActiveRoundIdentityRemainsAvailableToTheBook() {
        let model = HomeViewModel(
            activeRoundTitle: "Royal Melbourne",
            previousRounds: [],
            analyses: [],
            nearbyCourses: [],
            handicapBadgeText: "—",
            distanceUnit: .meters
        )

        XCTAssertTrue(model.hasActiveRound)
        XCTAssertEqual(model.heroSubtitle, "Royal Melbourne")
    }

    func testRoundDetailModelPromotesHeroMetricsAndAnalysisContext() {
        let analysis = RoundSummaryAnalysis(
            roundID: latestRound.id,
            cacheKey: RoundSummaryAnalysis.CacheKey(summary: latestRound).rawValue,
            provider: .foundationModels,
            summary: "Approach play held the round together late.",
            whatWentWell: ["Recovered well after misses.", "Short putts stayed tidy."],
            needsWork: ["Distance control faded between 110m and 150m.", "Penalty avoidance can still improve."],
            generatedAt: Date(timeIntervalSince1970: 2_100),
            updatedAt: nil
        )

        let detail = HomeViewModel.roundDetailModel(for: latestRound, analysis: analysis)

        XCTAssertEqual(detail.title, "The National")
        XCTAssertEqual(detail.statusTitle, "Finished Round")
        XCTAssertTrue(
            detail.statusDeck.hasPrefix("Completed round • 1 golfer • Updated"),
            "Unexpected status deck: \(detail.statusDeck)"
        )
        XCTAssertEqual(detail.heroMetrics.map { $0.title }, ["Strokes", "Putts", "Penalties"])
        XCTAssertEqual(detail.heroMetrics.map { $0.value }, ["76", "31", "1"])
        XCTAssertEqual(detail.supportMetrics.map { $0.title }, ["Progress", "Players", "Completed"])
        XCTAssertEqual(detail.analysisProviderLabel, "On-device AI")
        XCTAssertEqual(detail.analysisSummary, "Approach play held the round together late.")
        XCTAssertEqual(detail.analysisSections.map { $0.title }, ["What Went Well", "Needs Attention"])
        XCTAssertEqual(detail.analysisSections.first?.items, ["Recovered well after misses.", "Short putts stayed tidy."])
        XCTAssertEqual(detail.analysisSections.last?.items, ["Distance control faded between 110m and 150m.", "Penalty avoidance can still improve."])
        XCTAssertEqual(detail.strengths, ["Recovered well after misses.", "Short putts stayed tidy."])
        XCTAssertEqual(detail.improvements, ["Distance control faded between 110m and 150m.", "Penalty avoidance can still improve."])
    }

    func testRoundDetailModelFallsBackWhenAnalysisIsMissing() {
        let detail = HomeViewModel.roundDetailModel(for: latestRound, analysis: nil)

        XCTAssertEqual(detail.analysisProviderLabel, "Preparing analysis")
        XCTAssertNil(detail.analysisGeneratedAtTitle)
        XCTAssertEqual(detail.analysisSummary, "Generating a round-specific brief for this saved round.")
        XCTAssertEqual(detail.analysisSections.map(\.title), ["What Went Well", "Needs Attention"])
        XCTAssertEqual(detail.analysisSections.first?.items, [])
        XCTAssertEqual(detail.analysisSections.last?.items, [])
        XCTAssertTrue(detail.strengths.isEmpty)
        XCTAssertTrue(detail.improvements.isEmpty)
    }
}
