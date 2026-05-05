import Foundation

enum EditorialStagePresentation: Equatable {
    case stackedLead
    case bulletin
    case editorialSpread
    case stackedShowcase
}

struct HomeQuickStat: Equatable {
    let title: String
    let value: String
    let note: String
}

struct HomeNearbyCoursePreview: Equatable {
    let courseID: UUID
    let name: String
    let distanceLabel: String
    let detail: String
}

struct HomeRoundDetailMetric: Equatable {
    let title: String
    let value: String
    let note: String?
}

struct HomeRoundDetailAnalysisSection: Equatable {
    let title: String
    let items: [String]
}

struct HomeRoundDetailModel: Equatable {
    let title: String
    let statusTitle: String
    let statusDeck: String
    let heroMetrics: [HomeRoundDetailMetric]
    let supportMetrics: [HomeRoundDetailMetric]
    let analysisProviderLabel: String
    let analysisGeneratedAtTitle: String?
    let analysisSummary: String
    let analysisSections: [HomeRoundDetailAnalysisSection]
    let strengths: [String]
    let improvements: [String]
}

struct HomeSpotlight: Equatable {
    let eyebrow: String
    let title: String
    let subtitle: String
    let actionTitle: String
}

struct HomeViewModel {
    let mastheadEditionLabel: String
    let hasActiveRound: Bool
    let heroTitle: String
    let heroSubtitle: String
    let heroDeck: String
    let heroPrimaryActionTitle: String
    let heroAssetName: String
    let heroHighlights: [String]
    let commandPresentation: EditorialStagePresentation
    let spotlight: HomeSpotlight
    let spotlightRound: RoundHistorySummary?
    let spotlightAssetName: String
    let spotlightPresentation: EditorialStagePresentation
    let modules: [HomeModule]
    let insights: [HomeInsight]
    let previousRounds: [RoundHistorySummary]
    let quickStats: [HomeQuickStat]
    let nearbyCoursePreview: [HomeNearbyCoursePreview]
    let nearbyCoursesActionTitle: String
    let handicapBadgeText: String
    let distanceUnit: DistanceUnit

    init(
        activeRoundTitle: String?,
        previousRounds: [RoundHistorySummary],
        analyses: [RoundSummaryAnalysis],
        nearbyCourses: [SwingPalCourse],
        handicapBadgeText: String,
        distanceUnit: DistanceUnit
    ) {
        mastheadEditionLabel = "Field Notes 01"
        hasActiveRound = activeRoundTitle != nil
        heroTitle = activeRoundTitle == nil ? "Start Round" : "Resume Round"
        heroSubtitle = activeRoundTitle ?? "Pick a nearby course and begin."
        heroPrimaryActionTitle = activeRoundTitle == nil ? "Start Round" : "Open Round"
        heroAssetName = "HomeLeadStage"
        heroDeck = activeRoundTitle == nil
            ? "Start a round, check your signals, and move with less friction."
            : "Resume the round fast, then scan the strongest signals from your game."
        heroHighlights = activeRoundTitle == nil
            ? ["Pick a course", "Clear yardages", "Fast setup"]
            : ["Live yardages", "Your bag ready", "Map view"]
        commandPresentation = .stackedLead
        modules = [.insights, .recentRounds, .nearbyCourses]
        self.previousRounds = previousRounds
        spotlightRound = previousRounds.first
        spotlight = Self.makeSpotlight(from: spotlightRound)
        self.insights = Self.makeInsights(from: analyses, spotlightRound: spotlightRound)
        spotlightAssetName = "PremiumCoachingStage"
        spotlightPresentation = .bulletin
        quickStats = [
            .init(title: "Score", value: Self.lastRoundScore(from: previousRounds), note: "Last completed round"),
            .init(title: "FIR", value: "57%", note: "Rolling average"),
            .init(title: "GIR", value: "44%", note: "Rolling average"),
            .init(title: "Putts", value: "31.2", note: "Rolling average")
        ]
        nearbyCoursePreview = Self.makeNearbyCoursePreview(from: nearbyCourses, distanceUnit: distanceUnit)
        nearbyCoursesActionTitle = "See all nearby"
        self.handicapBadgeText = handicapBadgeText
        self.distanceUnit = distanceUnit
    }

    init(
        activeRoundTitle: String?,
        previousRounds: [RoundHistorySummary],
        analyses: [RoundSummaryAnalysis],
        nearbyCourses: [SwingPalCourse],
        handicapBadgeText: String
    ) {
        self.init(
            activeRoundTitle: activeRoundTitle,
            previousRounds: previousRounds,
            analyses: analyses,
            nearbyCourses: nearbyCourses,
            handicapBadgeText: handicapBadgeText,
            distanceUnit: .meters
        )
    }

    private static func makeSpotlight(from latestRound: RoundHistorySummary?) -> HomeSpotlight {
        if let latestRound {
            return HomeSpotlight(
                eyebrow: "AI Round Brief",
                title: latestRound.courseName,
                subtitle: "Revisit the mood, momentum, and AI notes from your latest round.",
                actionTitle: "Open Round Detail"
            )
        }

        return HomeSpotlight(
            eyebrow: "AI Round Brief",
            title: "Latest Round",
            subtitle: "Your most recent round analysis will show up here once you finish and review a round.",
            actionTitle: "Open Round Detail"
        )
    }

    private static func makeInsights(from analyses: [RoundSummaryAnalysis], spotlightRound: RoundHistorySummary?) -> [HomeInsight] {
        guard
            let spotlightRound,
            let analysis = analyses.first(where: { $0.roundID == spotlightRound.id })
        else {
            return []
        }

        if let topStrength = ProfileViewModel.sanitizedAnalysisItems(analysis.whatWentWell).first {
            return [HomeInsight(title: "What Went Well", detail: topStrength)]
        }

        if let topImprovement = ProfileViewModel.sanitizedAnalysisItems(analysis.needsWork).first {
            return [HomeInsight(title: "Needs Attention", detail: topImprovement)]
        }

        return []
    }

    private static func lastRoundScore(from previousRounds: [RoundHistorySummary]) -> String {
        guard let recentRound = previousRounds.first else {
            return "--"
        }

        return "\(recentRound.totalStrokes)"
    }

    private static func makeNearbyCoursePreview(from courses: [SwingPalCourse], distanceUnit: DistanceUnit) -> [HomeNearbyCoursePreview] {
        courses.prefix(3).map { course in
            HomeNearbyCoursePreview(
                courseID: course.id,
                name: course.name,
                distanceLabel: distanceUnit.travelLabel(forKilometers: course.distanceKilometers),
                detail: "\(course.holeCount) holes • Par \(course.par)"
            )
        }
    }

    static func roundDetailModel(for summary: RoundHistorySummary, analysis: RoundSummaryAnalysis?) -> HomeRoundDetailModel {
        let statusTitle = summary.status == .finished ? "Finished Round" : "Saved to Resume"
        let statusDeck = [
            summary.status == .finished ? "Completed round" : "Saved checkpoint",
            "\(summary.playerCount) golfer\(summary.playerCount == 1 ? "" : "s")",
            "Updated \(summary.updatedAt.formatted(date: .abbreviated, time: .shortened))"
        ].joined(separator: " • ")

        let sanitizedStrengths = ProfileViewModel.sanitizedAnalysisItems(analysis?.whatWentWell ?? [])
        let sanitizedImprovements = ProfileViewModel.sanitizedAnalysisItems(analysis?.needsWork ?? [])

        return .init(
            title: summary.courseName,
            statusTitle: statusTitle,
            statusDeck: statusDeck,
            heroMetrics: [
                .init(title: "Strokes", value: "\(summary.totalStrokes)", note: "Total logged"),
                .init(title: "Putts", value: "\(summary.totalPutts)", note: "Short game"),
                .init(title: "Penalties", value: "\(summary.totalPenalties)", note: "Card pressure")
            ],
            supportMetrics: [
                .init(title: "Progress", value: "Hole \(summary.holeNumber) of \(summary.totalHoleCount)", note: nil),
                .init(title: "Players", value: "\(summary.playerCount)", note: "In round"),
                .init(title: "Completed", value: "\(summary.completedHoleCount)", note: "Holes closed")
            ],
            analysisProviderLabel: analysis.map(Self.analysisProviderLabel(for:)) ?? "Preparing analysis",
            analysisGeneratedAtTitle: analysis?.generatedAt.formatted(date: .abbreviated, time: .shortened),
            analysisSummary: analysis?.summary ?? "Generating a round-specific brief for this saved round.",
            analysisSections: [
                .init(title: "What Went Well", items: sanitizedStrengths),
                .init(title: "Needs Attention", items: sanitizedImprovements)
            ],
            strengths: sanitizedStrengths,
            improvements: sanitizedImprovements
        )
    }

    private static func analysisProviderLabel(for analysis: RoundSummaryAnalysis) -> String {
        switch analysis.provider {
        case .foundationModels:
            return "On-device AI"
        case .kimi:
            return "AI"
        case .deterministic:
            return "Automatic"
        }
    }
}
