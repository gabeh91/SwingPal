struct ProfileViewModel {
    enum IdentityPrimaryActionIntent: Equatable {
        case requestSignIn
        case statusOnly
    }

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
    let identitySubtitle: String
    let identityAssetName: String
    let membershipTitle: String
    let membershipSubtitle: String
    let bagSummary: String
    let identityPrimaryActionTitle: String
    let identityPrimaryActionIntent: IdentityPrimaryActionIntent
    let identitySecondaryActionTitle: String
    let setupTitle: String
    let setupSubtitle: String
    let clubRecommendationTitle: String
    let appearanceTitle: String
    let appearanceSubtitle: String
    let gpsModeTitle: String
    let gpsModeSubtitle: String
    let diagnosticsTitle: String
    let diagnosticsSubtitle: String
    let premiumTitle: String
    let premiumSubtitle: String
    let premiumCTA: String
    let premiumAssetName: String

    init(
        authState: AuthState,
        entitlements: EntitlementState,
        bag: Bag,
        gpsMode: AppGPSMode
    ) {
        statusTitle = authState == .guest ? "Guest Mode" : "Signed In"
        identityAssetName = "ProfileBagStage"
        bagSummary = "\(bag.clubs.count) club\(bag.clubs.count == 1 ? "" : "s") dialed in"
        setupTitle = "Bag and setup"
        setupSubtitle = "Keep your bag, appearance, and GPS behavior ready before the next round."
        clubRecommendationTitle = "Club starting point"
        appearanceTitle = "Appearance"
        appearanceSubtitle = "Choose light, dark, or follow the system appearance across the app."
        switch gpsMode {
        case .live:
            gpsModeTitle = "Live GPS"
            gpsModeSubtitle = "Use your real on-course location for live yardages and planning."
        case .testPreview:
            gpsModeTitle = "Test GPS"
            gpsModeSubtitle = "Keep the live round pinned to the stable preview location while you build and QA."
        }
        diagnosticsTitle = "Testing and diagnostics"
        diagnosticsSubtitle = "Keep preview GPS and round playback controls tucked away from the main profile flow."

        switch authState {
        case .guest:
            identityTitle = "Keep your golf ready to sync"
            identitySubtitle = "Sign in to save rounds, sync your golf setup, and keep premium tools within reach."
            membershipTitle = "Free Membership"
            membershipSubtitle = "Sign in to save your golf identity and unlock premium intelligence when you're ready."
            identityPrimaryActionTitle = "Sign In to Save"
            identityPrimaryActionIntent = .requestSignIn
            identitySecondaryActionTitle = "Watch benefits"
        case .authenticated:
            identityTitle = "Your golf identity is live"
            identitySubtitle = "Your rounds, clubs, and account state are ready across devices."
            membershipTitle = entitlements == .premium ? "Premium Membership" : "Free Membership"
            membershipSubtitle = entitlements == .premium
                ? "Your premium tools are active, including watch control and deeper round intelligence."
                : "Your free membership is active and ready to upgrade when you want deeper coaching."
            identityPrimaryActionTitle = "Saved to Cloud"
            identityPrimaryActionIntent = .statusOnly
            identitySecondaryActionTitle = "Open Watch Companion"
        }

        premiumTitle = PremiumFeature.watchCompanion.title
        premiumAssetName = "PremiumCoachingStage"
        switch entitlements {
        case .free:
            premiumSubtitle = "Upgrade for Apple Watch live round support, smarter on-course intelligence, and richer post-round coaching."
            premiumCTA = "Unlock Premium"
        case .premium:
            premiumSubtitle = "Your premium tools are active, including live watch support and deeper round intelligence."
            premiumCTA = "Open Watch Companion"
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
