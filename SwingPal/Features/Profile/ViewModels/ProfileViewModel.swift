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
        .init(
            heading: "Round insights",
            summary: RoundRecapWriter.summaryLine(for: summary),
            strengths: RoundRecapWriter.strengths(for: summary),
            improvements: RoundRecapWriter.needsWork(for: summary)
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
}
