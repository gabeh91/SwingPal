import XCTest
@testable import SwingPal

final class SwingPalTests: XCTestCase {
    func testUserFacingScreensDoNotUseDirectRoundedFonts() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let screenPaths = [
            "SwingPal/Features/Home/Views/HomeView.swift",
            "SwingPal/Features/Home/Views/BlankScorecardGlyph.swift",
            "SwingPal/Features/Home/Views/HomeRoundAnalysisDetailView.swift",
            "SwingPal/Features/Social/Views/SocialView.swift",
            "SwingPal/Features/Social/Views/SocialPalette.swift",
            "SwingPal/Features/Social/Views/SocialScorecardDetailView.swift",
            "SwingPal/Features/Stats/Views/StatsView.swift",
            "SwingPal/Features/Stats/Views/BookTabs.swift",
            "SwingPal/Features/Stats/Views/StrokeLineChart.swift",
            "SwingPal/Features/Stats/Views/GraphPaper.swift",
            "SwingPal/Features/Profile/Views/ProfileView.swift",
            "SwingPal/Features/Profile/Views/PublicProfileEditorSheet.swift",
            "SwingPal/Features/Profile/Bag/Views/ProfileBagManagementView.swift",
            "SwingPal/Features/Profile/Bag/Views/ProfileEditClubSheet.swift",
            "SwingPal/Features/Profile/Bag/Views/CarryLadder.swift",
            "SwingPal/Features/Round/Live/Views/FreshLiveRoundScreen.swift",
            "SwingPal/Features/Round/Live/Views/Sheets/FreshLiveRoundHoleInspectorSheet.swift",
            "SwingPal/Features/Round/Live/Views/Sheets/FreshLiveRoundCurrentHoleEditorSheet.swift",
            "SwingPal/Features/Round/Live/Views/Sheets/FreshLiveRoundShotHistorySheet.swift",
            "SwingPal/Features/Round/Live/Views/Sheets/FreshLiveRoundConditionsSheet.swift",
            "SwingPal/Features/Round/Live/Views/Sheets/FreshLiveRoundEndRoundSheet.swift",
            "SwingPal/Features/Round/Live/Views/Sheets/FreshLiveRoundHoleConfirmationSheet.swift",
            "SwingPal/Features/Round/Live/Views/ShotLogger/FreshLiveRoundShotLoggerSheet.swift",
            "SwingPal/Features/Round/Live/Views/ShotLogger/FreshLiveRoundShotOutcomeNode.swift",
            "SwingPal/Features/Round/Live/Views/ShotLogger/FreshLiveRoundShotOutcomeIntensity.swift",
            "SwingPal/Features/Round/Live/Views/ShotLogger/FreshLiveRoundShotOutcomeLayout.swift",
            "SwingPal/Features/Round/Live/Views/ShotLogger/FreshLiveRoundAnnularSegmentShape.swift",
            "SwingPal/Features/Round/Live/Views/LiveMapDrawingCache.swift",
            "SwingPal/DesignSystem/Molecules/ScorecardStub.swift"
        ]

        let offenders = try screenPaths.compactMap { relativePath -> String? in
            let fileURL = repoRoot.appendingPathComponent(relativePath)
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            return source.contains("design: .rounded") ? relativePath : nil
        }

        XCTAssertEqual(
            offenders,
            [],
            "User-facing screens should use the shared typography system or default system fonts, not direct rounded fonts."
        )
    }

    func testDisplayNameMatchesAppBrand() {
        XCTAssertEqual(AppIdentity.displayName, "SwingPal")
    }

    func testSignInGateUsesFullAuthFlowPresentation() {
        XCTAssertEqual(
            AuthModalPresentation.resolve(for: .signIn),
            .authFlow
        )
        XCTAssertEqual(
            AuthModalPresentation.resolve(for: .premium),
            .premiumGate
        )
    }

    func testAuthFlowServiceSourcePrefersInjectedThenAppStateThenFallback() {
        XCTAssertEqual(
            AuthFlowServiceSource.resolve(hasInjectedService: true, hasAppStateService: true),
            .injected
        )
        XCTAssertEqual(
            AuthFlowServiceSource.resolve(hasInjectedService: false, hasAppStateService: true),
            .appState
        )
        XCTAssertEqual(
            AuthFlowServiceSource.resolve(hasInjectedService: false, hasAppStateService: false),
            .fallbackMock
        )
    }

    func testAppAuthServiceModeUsesRealServiceWhenConfiguredAndMissingConfigIsNotMock() {
        XCTAssertEqual(
            AppAuthServiceMode.resolve(hasSupabaseConfig: true),
            .supabase
        )
        XCTAssertEqual(
            AppAuthServiceMode.resolve(hasSupabaseConfig: false),
            .missingConfiguration
        )
    }
}
