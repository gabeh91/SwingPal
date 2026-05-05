import XCTest
@testable import SwingPal

final class ProfileViewModelTests: XCTestCase {
    func testGuestFreeModelFramesProfileAroundSavingAndPremiumUpgrade() {
        let model = ProfileViewModel(
            authState: .guest,
            entitlements: .free,
            bag: Bag(clubs: [
                Club(name: "Driver", typicalDistanceMeters: 235),
                Club(name: "7i", typicalDistanceMeters: 150),
                Club(name: "PW", typicalDistanceMeters: 115)
            ]),
            gpsMode: .live
        )

        XCTAssertEqual(model.statusTitle, "Guest Mode")
        XCTAssertEqual(model.identityTitle, "Keep your golf ready to sync")
        XCTAssertEqual(model.identitySubtitle, "Sign in to save rounds, sync your golf setup, and keep premium tools within reach.")
        XCTAssertEqual(model.membershipTitle, "Free Membership")
        XCTAssertEqual(model.membershipSubtitle, "Sign in to save your golf identity and unlock premium intelligence when you're ready.")
        XCTAssertEqual(model.identityPrimaryActionTitle, "Sign In to Save")
        XCTAssertEqual(model.identitySecondaryActionTitle, "Watch benefits")
        XCTAssertEqual(model.setupTitle, "Bag and setup")
        XCTAssertEqual(model.setupSubtitle, "Keep your bag, appearance, and GPS behavior ready before the next round.")
        XCTAssertEqual(model.clubRecommendationTitle, "Club starting point")
        XCTAssertEqual(model.bagSummary, "3 clubs dialed in")
        XCTAssertEqual(model.premiumCTA, "Unlock Premium")
        XCTAssertEqual(model.gpsModeTitle, "Live GPS")
        XCTAssertEqual(model.gpsModeSubtitle, "Use your real on-course location for live yardages and planning.")
        XCTAssertEqual(model.appearanceTitle, "Appearance")
        XCTAssertEqual(model.appearanceSubtitle, "Choose light, dark, or follow the system appearance across the app.")
        XCTAssertEqual(model.diagnosticsTitle, "Testing and diagnostics")
        XCTAssertEqual(model.diagnosticsSubtitle, "Keep preview GPS and round playback controls tucked away from the main profile flow.")
        XCTAssertEqual(model.identityAssetName, "ProfileBagStage")
        XCTAssertEqual(model.premiumAssetName, "PremiumCoachingStage")
    }

    func testPremiumAuthenticatedModelReframesActionsAroundAccess() {
        let model = ProfileViewModel(
            authState: .authenticated,
            entitlements: .premium,
            bag: Bag(clubs: [
                Club(name: "Driver", typicalDistanceMeters: 235),
                Club(name: "3W", typicalDistanceMeters: 210),
                Club(name: "5i", typicalDistanceMeters: 175),
                Club(name: "7i", typicalDistanceMeters: 150)
            ]),
            gpsMode: .testPreview
        )

        XCTAssertEqual(model.statusTitle, "Signed In")
        XCTAssertEqual(model.identityTitle, "Your golf identity is live")
        XCTAssertEqual(model.identitySubtitle, "Your rounds, clubs, and account state are ready across devices.")
        XCTAssertEqual(model.membershipTitle, "Premium Membership")
        XCTAssertEqual(model.membershipSubtitle, "Your premium tools are active, including watch control and deeper round intelligence.")
        XCTAssertEqual(model.identityPrimaryActionTitle, "Saved to Cloud")
        XCTAssertEqual(model.identitySecondaryActionTitle, "Open Watch Companion")
        XCTAssertEqual(model.setupTitle, "Bag and setup")
        XCTAssertEqual(model.bagSummary, "4 clubs dialed in")
        XCTAssertEqual(model.premiumCTA, "Open Watch Companion")
        XCTAssertEqual(model.gpsModeTitle, "Test GPS")
        XCTAssertEqual(model.gpsModeSubtitle, "Keep the live round pinned to the stable preview location while you build and QA.")
        XCTAssertEqual(model.appearanceTitle, "Appearance")
        XCTAssertEqual(model.diagnosticsTitle, "Testing and diagnostics")
        XCTAssertEqual(model.identityAssetName, "ProfileBagStage")
        XCTAssertEqual(model.premiumAssetName, "PremiumCoachingStage")
    }

    func testPreviousRoundSheetModelFramesUnfinishedRoundForSummarySheet() {
        let summary = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .unfinished,
            holeNumber: 7,
            totalHoleCount: 18,
            playerCount: 2,
            totalStrokes: 27,
            completedHoleCount: 4,
            totalPutts: 8,
            totalPenalties: 2,
            updatedAt: .distantPast
        )

        let model = ProfileViewModel.previousRoundSheetModel(for: summary)

        XCTAssertEqual(model.title, "Royal Melbourne")
        XCTAssertEqual(model.statusTitle, "Saved to Resume")
        XCTAssertEqual(model.statusDetail, "This round was saved before it was finished.")
        XCTAssertEqual(model.progressTitle, "Hole 7 of 18")
        XCTAssertEqual(model.playersTitle, "2 golfers")
        XCTAssertEqual(model.strokesTitle, "27 strokes logged")
        XCTAssertEqual(model.holesCompletedTitle, "4 holes completed")
        XCTAssertEqual(model.puttsTitle, "8 putts tracked")
        XCTAssertEqual(model.penaltiesTitle, "2 penalties")
    }

    func testPreviousRoundAnalysisModelHighlightsStrengthsAndImprovementAreas() {
        let summary = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .unfinished,
            holeNumber: 7,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 27,
            completedHoleCount: 4,
            totalPutts: 6,
            totalPenalties: 2,
            updatedAt: .distantPast
        )

        let model = ProfileViewModel.previousRoundAnalysisModel(for: summary)

        XCTAssertEqual(model.heading, "Round insights")
        XCTAssertEqual(model.summary, "This saved round captured enough scoring context to show where the round was trending before you stopped.")
        XCTAssertEqual(model.strengths.count, 3)
        XCTAssertEqual(model.improvements.count, 3)
        XCTAssertEqual(model.strengths.first, "You completed 4 holes before saving, giving the round a useful scoring baseline.")
        XCTAssertEqual(model.improvements.first, "2 penalty strokes were logged, so keeping the next ball in play is the clearest scoring gain.")
    }

    func testPreviousRoundAnalysisModelCanBeBuiltFromCachedAnalysis() {
        let analysis = RoundSummaryAnalysis(
            roundID: UUID(),
            cacheKey: "cache-key",
            provider: .foundationModels,
            summary: "Your round stayed stable through the saved holes.",
            whatWentWell: ["Short-game logging stayed sharp", "Penalty damage stayed manageable"],
            needsWork: ["Keep the ball in play off the tee", "Convert more saved holes into confirmed holes"],
            generatedAt: .distantPast
        )

        let model = ProfileViewModel.previousRoundAnalysisModel(for: analysis)

        XCTAssertEqual(model.heading, "Round insights")
        XCTAssertEqual(model.summary, "Your round stayed stable through the saved holes.")
        XCTAssertEqual(model.strengths.count, 2)
        XCTAssertEqual(model.improvements.count, 2)
    }

    func testPreviousRoundAnalysisModelFiltersBlankBulletItems() {
        let analysis = RoundSummaryAnalysis(
            roundID: UUID(),
            cacheKey: "cache-key",
            provider: .foundationModels,
            summary: "Your round stayed stable through the saved holes.",
            whatWentWell: ["Short-game logging stayed sharp", "", "Penalty damage stayed manageable", " "],
            needsWork: ["", "Keep the ball in play off the tee", " ", "Convert more saved holes into confirmed holes"],
            generatedAt: .distantPast
        )

        let model = ProfileViewModel.previousRoundAnalysisModel(for: analysis)

        XCTAssertEqual(model.strengths, ["Short-game logging stayed sharp", "Penalty damage stayed manageable"])
        XCTAssertEqual(model.improvements, ["Keep the ball in play off the tee", "Convert more saved holes into confirmed holes"])
    }

    func testAnalysisActionLabelsReflectIdleLoadingAndReadyStates() {
        XCTAssertEqual(ProfileViewModel.previousRoundAnalysisButtonTitle(for: .idle), "View Analysis")
        XCTAssertEqual(ProfileViewModel.previousRoundAnalysisButtonTitle(for: .loading), "Analyzing…")

        let ready = RoundSummaryAnalysis(
            roundID: UUID(),
            cacheKey: "cache-key",
            provider: .deterministic,
            summary: "Ready",
            whatWentWell: ["One", "Two"],
            needsWork: ["Three", "Four"],
            generatedAt: .distantPast
        )
        XCTAssertEqual(ProfileViewModel.previousRoundAnalysisButtonTitle(for: .ready(ready)), "Analysis Ready")
    }

    func testAnalysisActionDisablesButtonWhenLoadingOrReady() {
        XCTAssertFalse(ProfileViewModel.previousRoundAnalysisButtonIsDisabled(for: .idle))
        XCTAssertTrue(ProfileViewModel.previousRoundAnalysisButtonIsDisabled(for: .loading))

        let ready = RoundSummaryAnalysis(
            roundID: UUID(),
            cacheKey: "cache-key",
            provider: .deterministic,
            summary: "Ready",
            whatWentWell: ["One", "Two"],
            needsWork: ["Three", "Four"],
            generatedAt: .distantPast
        )
        XCTAssertTrue(ProfileViewModel.previousRoundAnalysisButtonIsDisabled(for: .ready(ready)))
    }

    func testCachedAnalysisShouldAutoPresentWhenReady() {
        XCTAssertFalse(ProfileViewModel.previousRoundAnalysisShouldBePresented(for: .idle))
        XCTAssertFalse(ProfileViewModel.previousRoundAnalysisShouldBePresented(for: .loading))

        let ready = RoundSummaryAnalysis(
            roundID: UUID(),
            cacheKey: "cache-key",
            provider: .foundationModels,
            summary: "Ready",
            whatWentWell: ["One", "Two"],
            needsWork: ["Three", "Four"],
            generatedAt: .distantPast
        )
        XCTAssertTrue(ProfileViewModel.previousRoundAnalysisShouldBePresented(for: .ready(ready)))
    }

    func testAnalysisActionUsesAnimatedGlyphOnlyWhileLoading() {
        XCTAssertFalse(ProfileViewModel.previousRoundAnalysisShowsLoadingGlyph(for: .idle))
        XCTAssertTrue(ProfileViewModel.previousRoundAnalysisShowsLoadingGlyph(for: .loading))

        let ready = RoundSummaryAnalysis(
            roundID: UUID(),
            cacheKey: "cache-key",
            provider: .foundationModels,
            summary: "Ready",
            whatWentWell: ["One", "Two"],
            needsWork: ["Three", "Four"],
            generatedAt: .distantPast
        )
        XCTAssertFalse(ProfileViewModel.previousRoundAnalysisShowsLoadingGlyph(for: .ready(ready)))
    }

    func testBagSwipeBehaviorKeepsClosedRowFollowingFinger() {
        XCTAssertEqual(
            ProfileBagSwipeBehavior.contentOffset(
                dragTranslation: -18,
                isRevealed: false
            ),
            -18,
            accuracy: 0.001
        )
    }

    func testBagSwipeBehaviorKeepsDeleteActionHiddenWhenRowIsClosed() {
        XCTAssertEqual(
            ProfileBagSwipeBehavior.actionWidth(forContentOffset: 0),
            0,
            accuracy: 0.001
        )
    }

    func testBrandSearchReturnsAllBrandsWhenQueryIsEmpty() {
        let brands = ["Titleist", "TaylorMade", "PING"]

        XCTAssertEqual(
            ProfileClubBrandSearch.filteredBrands(
                query: "",
                allBrands: brands
            ),
            brands
        )
    }

    func testBrandSearchFiltersBrandsCaseInsensitively() {
        let brands = ["Titleist", "TaylorMade", "PING", "PXG"]

        XCTAssertEqual(
            ProfileClubBrandSearch.filteredBrands(
                query: "pi",
                allBrands: brands
            ),
            ["PING"]
        )
    }

    func testAddClubSummaryGuardDisablesInteractiveDismissalOnSummaryStage() {
        XCTAssertFalse(
            ProfileAddClubSummaryGuard.interactiveDismissDisabled(isSummaryStage: false)
        )
        XCTAssertTrue(
            ProfileAddClubSummaryGuard.interactiveDismissDisabled(isSummaryStage: true)
        )
    }

    func testAddClubSummaryGuardRequiresCancelConfirmationOnlyOnSummaryStage() {
        XCTAssertFalse(
            ProfileAddClubSummaryGuard.requiresCancelConfirmation(isSummaryStage: false)
        )
        XCTAssertTrue(
            ProfileAddClubSummaryGuard.requiresCancelConfirmation(isSummaryStage: true)
        )
    }
}
