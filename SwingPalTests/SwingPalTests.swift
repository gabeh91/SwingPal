import XCTest
@testable import SwingPal

final class SwingPalTests: XCTestCase {
    func testUserFacingScreensDoNotUseDirectRoundedFonts() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let screenPaths = [
            "SwingPal/Features/Home/HomeView.swift",
            "SwingPal/Features/Social/SocialView.swift",
            "SwingPal/Features/Stats/StatsView.swift",
            "SwingPal/Features/Profile/ProfileView.swift",
            "SwingPal/Features/Round/FreshLiveRoundScreen.swift"
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
