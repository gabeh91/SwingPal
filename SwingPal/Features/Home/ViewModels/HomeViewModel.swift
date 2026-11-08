import Foundation

enum EditorialStagePresentation: Equatable {
    case stackedLead
    case bulletin
    case editorialSpread
    case stackedShowcase
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

struct HomeViewModel {
    let hasActiveRound: Bool
    let heroSubtitle: String
    let previousRounds: [RoundHistorySummary]
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
        hasActiveRound = activeRoundTitle != nil
        heroSubtitle = activeRoundTitle ?? "Pick a course and begin."
        self.previousRounds = previousRounds.sorted { $0.updatedAt > $1.updatedAt }
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
