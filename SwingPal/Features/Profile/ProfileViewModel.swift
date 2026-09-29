struct ProfileViewModel {
    struct PreviousRoundSheetModel: Equatable {
        let title: String
        let statusTitle: String
        let statusDetail: String
        let progressTitle: String
        let playersTitle: String
        let strokesTitle: String
        let holesCompletedTitle: String
        let puttsTitle: String
        let penaltiesTitle: String
    }

    struct PreviousRoundAnalysisModel: Equatable {
        let heading: String
        let summary: String
        let strengths: [String]
        let improvements: [String]
    }

    enum PreviousRoundAnalysisState: Equatable {
        case idle
        case loading
        case ready(RoundSummaryAnalysis)
    }

    let statusTitle: String
    let identityTitle: String
    let gpsModeSubtitle: String
    let premiumTitle: String
    let premiumSubtitle: String

    init(
        authState: AuthState,
        entitlements: EntitlementState,
        bag: Bag,
        gpsMode: AppGPSMode
    ) {
        statusTitle = authState == .guest ? "Guest Mode" : "Signed In"
        switch gpsMode {
        case .live:
            gpsModeSubtitle = "Use your real on-course location for live yardages and planning."
        case .testPreview:
            gpsModeSubtitle = "Keep the live round pinned to the stable preview location while you build and QA."
        }

        switch authState {
        case .guest:
            identityTitle = "Guest profile"
        case .authenticated:
            identityTitle = "Your profile"
        }

        premiumTitle = PremiumFeature.watchCompanion.title
        switch entitlements {
        case .free:
            premiumSubtitle = "Premium purchases are not available in this version. Check availability for the Apple Watch companion."
        case .premium:
            premiumSubtitle = "Apple Watch companion access is enabled."
        }
    }

    static func previousRoundSheetModel(for summary: RoundHistorySummary) -> PreviousRoundSheetModel {
        .init(
            title: summary.courseName,
            statusTitle: summary.status == .finished ? "Finished Round" : "Saved to Resume",
            statusDetail: summary.status == .finished
                ? "This round was completed and archived in your history."
                : "This round was saved before it was finished.",
            progressTitle: "Hole \(summary.holeNumber) of \(summary.totalHoleCount)",
            playersTitle: "\(summary.playerCount) golfer\(summary.playerCount == 1 ? "" : "s")",
            strokesTitle: "\(summary.totalStrokes) stroke\(summary.totalStrokes == 1 ? "" : "s") logged",
            holesCompletedTitle: "\(summary.completedHoleCount) hole\(summary.completedHoleCount == 1 ? "" : "s") completed",
            puttsTitle: "\(summary.totalPutts) putt\(summary.totalPutts == 1 ? "" : "s") tracked",
            penaltiesTitle: "\(summary.totalPenalties) penalt\(summary.totalPenalties == 1 ? "y" : "ies")"
        )
    }

    static func previousRoundAnalysisModel(for summary: RoundHistorySummary) -> PreviousRoundAnalysisModel {
        let strengths = legacyStrengths(for: summary)
        let improvements = legacyImprovements(for: summary)

        return .init(
            heading: "Round insights",
            summary: legacySummary(for: summary),
            strengths: strengths,
            improvements: improvements
        )
    }

    static func previousRoundAnalysisModel(for analysis: RoundSummaryAnalysis) -> PreviousRoundAnalysisModel {
        .init(
            heading: "Round insights",
            summary: analysis.summary,
            strengths: sanitizedAnalysisItems(analysis.whatWentWell),
            improvements: sanitizedAnalysisItems(analysis.needsWork)
        )
    }

    static func previousRoundAnalysisButtonTitle(for state: PreviousRoundAnalysisState) -> String {
        switch state {
        case .idle:
            return "View Analysis"
        case .loading:
            return "Analyzing…"
        case .ready:
            return "Analysis Ready"
        }
    }

    static func previousRoundAnalysisButtonIsDisabled(for state: PreviousRoundAnalysisState) -> Bool {
        switch state {
        case .idle:
            return false
        case .loading, .ready:
            return true
        }
    }

    static func previousRoundAnalysisShouldBePresented(for state: PreviousRoundAnalysisState) -> Bool {
        switch state {
        case .ready:
            return true
        case .idle, .loading:
            return false
        }
    }

    static func previousRoundAnalysisShowsLoadingGlyph(for state: PreviousRoundAnalysisState) -> Bool {
        switch state {
        case .loading:
            return true
        case .idle, .ready:
            return false
        }
    }

    static func sanitizedAnalysisItems(_ items: [String]) -> [String] {
        items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func legacySummary(for summary: RoundHistorySummary) -> String {
        if summary.status == .finished {
            return "This completed round shows the scoring patterns that mattered most over all \(summary.totalHoleCount) holes."
        }

        if summary.completedHoleCount > 0 {
            return "This saved round captured enough scoring context to show where the round was trending before you stopped."
        }

        return "This saved round only captured a small checkpoint, so the analysis focuses on the limited data logged so far."
    }

    static func legacyStrengths(for summary: RoundHistorySummary) -> [String] {
        var strengths: [String] = []

        if summary.completedHoleCount > 0 {
            strengths.append("You completed \(summary.completedHoleCount) hole\(summary.completedHoleCount == 1 ? "" : "s") before saving, giving the round a useful scoring baseline.")
        }

        if summary.totalPenalties == 0 {
            strengths.append("No penalties were logged, which kept the card cleaner than most mid-round saves.")
        }

        if summary.totalPutts > 0 {
            strengths.append("You tracked \(summary.totalPutts) putt\(summary.totalPutts == 1 ? "" : "s"), which gives the round useful short-game context.")
        }

        if summary.totalStrokes > 0 {
            strengths.append("You logged \(summary.totalStrokes) total stroke\(summary.totalStrokes == 1 ? "" : "s"), so this recap has enough context to be worth reviewing.")
        }

        return Array(strengths.prefix(3))
    }

    static func legacyImprovements(for summary: RoundHistorySummary) -> [String] {
        var improvements: [String] = []

        if summary.totalPenalties > 0 {
            improvements.append("\(summary.totalPenalties) penalty stroke\(summary.totalPenalties == 1 ? "" : "s") were logged, so keeping the next ball in play is the clearest scoring gain.")
        }

        if summary.status == .unfinished {
            improvements.append("Finishing more holes will make the pattern data more reliable than this saved checkpoint alone.")
        }

        if summary.completedHoleCount == 0 {
            improvements.append("Confirming holes as you go will make later round summaries much easier to trust.")
        }

        if improvements.count < 2 {
            improvements.append("Keep logging each hole cleanly so the next recap can separate real scoring trends from noise.")
        }

        if improvements.count < 3 {
            improvements.append("Sharper distance control on approach shots would make the next summary more actionable than this saved checkpoint.")
        }

        return Array(improvements.prefix(3))
    }
}
