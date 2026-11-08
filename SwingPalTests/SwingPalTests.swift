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

@MainActor
final class AuthViewModelTests: XCTestCase {
    private func makeModel(_ service: MockAuthService) -> AuthViewModel {
        let model = AuthViewModel(authService: service, appleCoordinatorFactory: { AppleSignInCoordinator() })
        model.email = "gabe@example.com"
        model.password = "secret123"
        return model
    }

    func testSocialSignInIsHiddenUntilOAuthIsSetUp() {
        XCTAssertFalse(AuthViewModel.showsSocialSignIn)
    }

    func testSignUpThatNeedsConfirmingSaysSoInsteadOfDoingNothing() async {
        let service = MockAuthService()
        service.requiresEmailConfirmation = true
        let model = makeModel(service)
        model.goTo(.email(.signUp))

        await model.submitEmail()

        XCTAssertEqual(model.step, .confirmEmail(email: "gabe@example.com"))
        XCTAssertNil(model.errorMessage)
        XCTAssertNil(service.currentSessionUser)
        XCTAssertFalse(model.isBusy)
    }

    func testSigningInBeforeConfirmingGoesToTheConfirmStep() async {
        let service = MockAuthService()
        service.unconfirmedEmails = ["gabe@example.com"]
        let model = makeModel(service)
        model.goTo(.email(.signIn))

        await model.submitEmail()

        XCTAssertEqual(model.step, .confirmEmail(email: "gabe@example.com"))
    }

    func testConfirmStepCanResendAndThenSignIn() async {
        let service = MockAuthService()
        service.requiresEmailConfirmation = true
        let model = makeModel(service)
        model.goTo(.email(.signUp))
        await model.submitEmail()

        await model.signInAfterConfirming()
        XCTAssertNotNil(model.errorMessage, "Still unconfirmed")
        XCTAssertNil(service.currentSessionUser)

        await model.resendConfirmation()
        XCTAssertEqual(service.resentConfirmations, ["gabe@example.com"])
        XCTAssertNotNil(model.noticeMessage)

        service.unconfirmedEmails = []
        await model.signInAfterConfirming()
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(service.currentSessionUser?.email, "gabe@example.com")
    }

    func testSigningUpWithARegisteredEmailPointsToSignIn() async {
        let service = MockAuthService()
        service.behaviour = .alwaysFail(.emailAlreadyRegistered)
        let model = makeModel(service)
        model.goTo(.email(.signUp))

        await model.submitEmail()

        XCTAssertEqual(model.step, .email(.signIn))
        XCTAssertEqual(model.errorMessage, "You already have an account with that email. Sign in instead.")
    }

    func testClosingMidRequestStopsItQuietly() async throws {
        let service = MockAuthService()
        service.responseDelay = .seconds(5)
        let model = makeModel(service)
        model.goTo(.email(.signIn))

        model.launch { await $0.submitEmail() }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(model.isBusy)

        model.cancelInFlight()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(model.isBusy)
        XCTAssertNil(model.errorMessage)
        XCTAssertNil(service.currentSessionUser, "The cancelled sign-in never landed")
    }

    func testSupabaseErrorsBecomeMessagesThePlayerCanActOn() {
        func mapped(_ message: String) -> AuthServiceError? {
            SupabaseAuthService.mapError(NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: message])) as? AuthServiceError
        }
        XCTAssertEqual(mapped("Email not confirmed"), .emailNotConfirmed)
        XCTAssertEqual(mapped("Invalid login credentials"), .invalidCredentials)
        XCTAssertEqual(mapped("User already registered"), .emailAlreadyRegistered)
        XCTAssertEqual(mapped("email rate limit exceeded"), .emailRateLimited)
        XCTAssertTrue(SupabaseAuthService.mapError(URLError(.cancelled)) is CancellationError)
    }
}

#if DEBUG
final class GreenScanMathTests: XCTestCase {
    /// A 2 m square of ground rising 2 cm per metre along x and 1 cm per metre along z.
    private func tiltedPatch() -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        for i in 0...40 {
            for j in 0...40 {
                let x = Float(i) * 0.05 - 1, z = Float(j) * 0.05 - 1
                points.append(SIMD3<Float>(x, 0.02 * x + 0.01 * z - 1.2, z))
            }
        }
        return points
    }

    func testReadsTheSlopeOfATiltedPatch() throws {
        let fit = try XCTUnwrap(GreenScanMath.fitGround(tiltedPatch()))
        XCTAssertEqual(fit.slopePercent, 2.236, accuracy: 0.01)
        XCTAssertEqual(fit.rmsResidualMeters, 0, accuracy: 0.0005)
        XCTAssertEqual(fit.spanMeters, 2, accuracy: 0.01)
    }

    func testIgnoresThingsStandingOnTheGround() throws {
        var points = tiltedPatch()
        // A shoe and a flagstick base: well off the plane.
        for i in 0..<60 { points.append(SIMD3<Float>(0.3 + Float(i) * 0.002, -1.1, 0.2)) }
        let fit = try XCTUnwrap(GreenScanMath.fitGround(points))
        XCTAssertEqual(fit.slopePercent, 2.236, accuracy: 0.02)
    }

    func testFallDirectionIsRelativeToWhereThePhonePoints() {
        // Looking along -z; the ground rises to the right (+x), so it falls left.
        let angle = GreenScanMath.fallAngle(gradientX: 0.02, gradientZ: 0, aheadX: 0, aheadZ: -1)
        XCTAssertEqual(angle, -.pi / 2, accuracy: 0.001)
        let reading = GreenScanReading(slopePercent: 2, fallAngleFromAhead: angle, noiseMillimeters: 1, pointCount: 100, spanMeters: 2)
        XCTAssertEqual(reading.fallDescription, "falls to the left")
    }

    func testAPatchWithFurnitureInItIsNotTrusted() throws {
        let clean = try XCTUnwrap(GreenScanMath.fitGround(tiltedPatch()))
        XCTAssertTrue(GreenScanMath.isTrustworthy(clean, patchRadiusMeters: 1))

        // Two surfaces 3 cm apart in the same patch: no single plane fits.
        var stepped: [SIMD3<Float>] = []
        for i in 0...40 {
            for j in 0...40 {
                let x = Float(i) * 0.05 - 1, z = Float(j) * 0.05 - 1
                stepped.append(SIMD3<Float>(x, x > 0 ? 0.03 : 0, z))
            }
        }
        let fit = try XCTUnwrap(GreenScanMath.fitGround(stepped))
        XCTAssertFalse(GreenScanMath.isTrustworthy(fit, patchRadiusMeters: 1))
    }

    func testLevelCheckCancelsWhateverIsFixedToThePhone() {
        // Floor tilts 0.5% along x. The phone rests on its camera bump, which
        // adds 1.5% along its own length: +z the first time, -z after the turn.
        let level = GreenScanLevel.combining(
            first: (gradientX: 0.005, gradientZ: 0.015),
            second: (gradientX: 0.005, gradientZ: -0.015)
        )
        XCTAssertEqual(level.slopePercent, 0.5, accuracy: 0.001)
        XCTAssertEqual(level.gradientX, 0.005, accuracy: 0.00001)
        XCTAssertEqual(level.gradientZ, 0, accuracy: 0.00001)
        XCTAssertEqual(level.phoneOffsetPercent, 1.5, accuracy: 0.001)
    }

    func testTooFewPointsGivesNoReading() {
        XCTAssertNil(GreenScanMath.fitGround([SIMD3<Float>(0, 0, 0)]))
    }
}
#endif
