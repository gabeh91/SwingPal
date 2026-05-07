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

    func testResumeHeroAppearsBeforeInsightsWhenRoundIsActive() {
        let model = HomeViewModel(
            activeRoundTitle: "Royal Melbourne",
            previousRounds: [],
            analyses: [],
            nearbyCourses: [],
            handicapBadgeText: "—",
            distanceUnit: .meters
        )

        XCTAssertEqual(model.heroTitle, "Resume Round")
        XCTAssertEqual(model.modules, [HomeModule.insights, .recentRounds, .nearbyCourses])
        XCTAssertEqual(model.heroPrimaryActionTitle, "Open Round")
    }

    func testResumeHeroProvidesLiveRoundHighlights() {
        let model = HomeViewModel(
            activeRoundTitle: "Royal Melbourne",
            previousRounds: [latestRound],
            analyses: [],
            nearbyCourses: [],
            handicapBadgeText: "—",
            distanceUnit: .meters
        )

        XCTAssertEqual(model.heroHighlights, ["Live yardages", "Your bag ready", "Map view"])
        XCTAssertEqual(model.mastheadEditionLabel, "Field Notes 01")
        XCTAssertEqual(model.heroDeck, "Resume the round fast, then scan the strongest signals from your game.")
        XCTAssertEqual(model.commandPresentation, .stackedLead)
        XCTAssertEqual(model.heroAssetName, "HomeLeadStage")
    }

    func testHomeModelProvidesFourRecentFormStatsForDashboardSummary() {
        let model = HomeViewModel(
            activeRoundTitle: nil,
            previousRounds: [latestRound],
            analyses: [],
            nearbyCourses: [],
            handicapBadgeText: "—",
            distanceUnit: .meters
        )

        XCTAssertEqual(model.quickStats.count, 4)
        XCTAssertEqual(model.quickStats.map(\.title), ["Score", "FIR", "GIR", "Putts"])
        XCTAssertEqual(model.quickStats.first?.value, "76")
        XCTAssertEqual(model.quickStats.map(\.note), ["Last completed round", "Rolling average", "Rolling average", "Rolling average"])
        XCTAssertEqual(model.heroDeck, "Start a round, check your signals, and move with less friction.")
        XCTAssertEqual(model.commandPresentation, .stackedLead)
        XCTAssertEqual(model.spotlightAssetName, "PremiumCoachingStage")
        XCTAssertEqual(model.heroPrimaryActionTitle, "Start Round")
    }

    func testHomeModelBuildsAiPreviewFromMostRecentRoundAndLatestAnalysis() {
        let latestAnalysis = RoundSummaryAnalysis(
            roundID: latestRound.id,
            cacheKey: RoundSummaryAnalysis.CacheKey(summary: latestRound).rawValue,
            provider: .foundationModels,
            summary: "Approach play held the round together late.",
            whatWentWell: ["Recovered well after misses."],
            needsWork: ["Distance control faded between 110m and 150m."],
            generatedAt: Date(timeIntervalSince1970: 2_100),
            updatedAt: nil
        )

        let model = HomeViewModel(
            activeRoundTitle: nil,
            previousRounds: [latestRound, olderRound],
            analyses: [latestAnalysis],
            nearbyCourses: [],
            handicapBadgeText: "—",
            distanceUnit: .meters
        )

        XCTAssertEqual(model.spotlight.eyebrow, "AI Round Brief")
        XCTAssertEqual(model.spotlight.title, "The National")
        XCTAssertEqual(model.spotlight.actionTitle, "Open Round Detail")
        XCTAssertEqual(model.spotlightRound?.id, latestRound.id)
        XCTAssertEqual(model.insights.first?.title, "What Went Well")
        XCTAssertEqual(model.insights.first?.detail, "Recovered well after misses.")
        XCTAssertEqual(model.mastheadEditionLabel, "Field Notes 01")
        XCTAssertEqual(model.spotlightPresentation, EditorialStagePresentation.bulletin)
        XCTAssertEqual(model.spotlightAssetName, "PremiumCoachingStage")
    }

    func testHomeModelFallsBackToRoundBriefWhenAnalysisIsMissing() {
        let model = HomeViewModel(
            activeRoundTitle: nil,
            previousRounds: [latestRound],
            analyses: [],
            nearbyCourses: [],
            handicapBadgeText: "—",
            distanceUnit: .meters
        )

        XCTAssertEqual(model.spotlightRound?.id, latestRound.id)
        XCTAssertTrue(model.insights.isEmpty)
        XCTAssertEqual(model.spotlight.subtitle, "Revisit the mood, momentum, and AI notes from your latest round.")
    }

    func testHomeModelBuildsNearbyCourseMiniListLimitedToThreeCourses() {
        let royal = SwingPalCourse.test(name: "Royal Melbourne", distanceKilometers: 3.2, holeCount: 18, par: 72)
        let kingston = SwingPalCourse.test(name: "Kingston Heath", distanceKilometers: 7.4, holeCount: 18, par: 72)
        let peninsula = SwingPalCourse.test(name: "Peninsula Kingswood", distanceKilometers: 14.1, holeCount: 18, par: 72)
        let metro = SwingPalCourse.test(name: "Metropolitan", distanceKilometers: 18.3, holeCount: 18, par: 72)

        let model = HomeViewModel(
            activeRoundTitle: nil,
            previousRounds: [],
            analyses: [],
            nearbyCourses: [royal, kingston, peninsula, metro],
            handicapBadgeText: "—",
            distanceUnit: .meters
        )

        XCTAssertEqual(model.nearbyCoursePreview.count, 3)
        XCTAssertEqual(model.nearbyCoursePreview.map(\.name), ["Royal Melbourne", "Kingston Heath", "Peninsula Kingswood"])
        XCTAssertEqual(model.nearbyCoursePreview.map(\.courseID), [royal.id, kingston.id, peninsula.id])
        XCTAssertEqual(model.nearbyCoursePreview.first?.distanceLabel, "3.2 km")
        XCTAssertEqual(model.nearbyCoursePreview.first?.detail, "18 holes • Par 72")
        XCTAssertEqual(model.nearbyCoursesActionTitle, "See all nearby")
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
