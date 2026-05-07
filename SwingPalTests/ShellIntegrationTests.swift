import XCTest
@testable import SwingPal

@MainActor
final class ShellIntegrationTests: XCTestCase {
    func testProfileProductionViewCanCompleteSignInIntoAppState() {
        let state = AppState()
        _ = AppShellView.makeProfileView(appState: state)

        XCTAssertEqual(state.authState, .guest)

        state.completeSignIn()

        XCTAssertEqual(state.authState, .authenticated)
    }

    func testProfileProductionViewCanAddClubsIntoAppState() {
        let state = AppState()
        let view = AppShellView.makeProfileView(appState: state)
        let club = Club(name: "7I", typicalDistanceMeters: 150, brand: "Titleist", family: "T250", source: .catalog)

        view.onAddClubs([club])

        XCTAssertTrue(state.bag.clubs.contains(club))
    }

    func testProfileProductionViewCanDeleteClubsFromAppState() {
        let existing = Club(name: "7I", typicalDistanceMeters: 150, brand: "Titleist", family: "T250", source: .catalog)
        let bagStore = StubBagStore(bag: Bag(clubs: [existing]))
        let state = AppState(
            store: StubActiveRoundStore(),
            bagStore: bagStore,
            gpsModeStore: StubGPSModeStore(),
            appearanceModeStore: StubAppearanceModeStore()
        )
        let view = AppShellView.makeProfileView(appState: state)

        view.onDeleteClub(existing.id)

        XCTAssertFalse(state.bag.clubs.contains(existing))
    }

    func testFreeWatchCompanionEntryStillRequiresPremiumGate() {
        let state = AppState()
        state.entitlements = .free

        let resolution = AppShellView.watchCompanionEntryResolution(for: state)

        XCTAssertEqual(resolution, .gated(.premium))
    }

    func testPremiumWatchCompanionEntryOpensLandingWithoutActiveRound() {
        let state = AppState()
        state.entitlements = .premium

        let resolution = AppShellView.watchCompanionEntryResolution(for: state)

        guard case .landing(let model) = resolution else {
            return XCTFail("Expected premium watch companion landing")
        }

        XCTAssertEqual(model.connectionBadge, "Offline")
        XCTAssertEqual(model.setupTitle, "Setup Not Ready")
        XCTAssertFalse(model.canOpenLiveRound)
        XCTAssertEqual(model.primaryActionTitle, "Open Round Setup")
    }

    func testPremiumWatchCompanionEntryCanDeepLinkIntoLiveRoundWhenRoundIsActive() {
        let state = AppState()
        state.entitlements = .premium
        state.activeRoundID = UUID()
        state.activeRoundState = LiveRoundState(hole: HoleSession(number: 1, par: 4))

        let resolution = AppShellView.watchCompanionEntryResolution(for: state)

        guard case .landing(let model) = resolution else {
            return XCTFail("Expected premium watch companion landing")
        }

        XCTAssertTrue(model.canOpenLiveRound)
        XCTAssertEqual(model.primaryActionTitle, "Open Live Round")
        XCTAssertEqual(model.setupTitle, "Live Round Ready")
    }

    func testFloatingTabBarReservesEnoughBottomClearanceForContent() {
        XCTAssertGreaterThanOrEqual(
            AppChromeMetrics.bottomContentInset,
            AppChromeMetrics.tabBarOccupiedHeight + 56
        )
        XCTAssertGreaterThan(AppChromeMetrics.floatingRoundButtonLift, 0)
    }

    func testFloatingTabBarReservesDedicatedCenterLaneForRoundAction() {
        XCTAssertGreaterThanOrEqual(
            AppChromeMetrics.centerDockReservation,
            AppChromeMetrics.floatingRoundButtonSize + 40
        )
    }

    func testRoundTabCanBeSelectedFromInitialState() {
        let state = AppState()
        state.selectedTab = .round
        XCTAssertEqual(state.selectedTab, .round)
    }

    func testNearbyCoursesIntentSelectsRoundTabAndStoresCoursesRoute() {
        let state = AppState()

        state.openNearbyCourses()

        XCTAssertEqual(state.selectedTab, .round)
        XCTAssertEqual(state.pendingRoundEntryRoute, .nearbyCourses)
    }

    func testCoursePreviewIntentSelectsRoundTabAndStoresCourseDetailRoute() {
        let state = AppState()
        let courseID = UUID()

        state.openNearbyCourseDetail(courseID: courseID)

        XCTAssertEqual(state.selectedTab, .round)
        XCTAssertEqual(state.pendingRoundEntryRoute, .courseDetail(courseID))
    }

    func testConsumingPendingRoundEntryRouteClearsIntent() {
        let state = AppState()
        let courseID = UUID()
        state.openNearbyCourseDetail(courseID: courseID)

        XCTAssertEqual(state.consumePendingRoundEntryRoute(), .courseDetail(courseID))
        XCTAssertNil(state.pendingRoundEntryRoute)
    }

    func testSelectedHomeTabUsesActiveDockPresentation() {
        let presentation = AppTabBarPresentation.item(for: .home, selectedTab: .home)

        XCTAssertEqual(presentation.symbolName, "house")
        XCTAssertEqual(presentation.selectionStyle, .pill)
        XCTAssertEqual(presentation.tone, .active)
    }

    func testUnselectedSocialTabUsesQuietDockPresentation() {
        let presentation = AppTabBarPresentation.item(for: .social, selectedTab: .home)

        XCTAssertEqual(presentation.symbolName, "person.2")
        XCTAssertEqual(presentation.selectionStyle, .none)
        XCTAssertEqual(presentation.tone, .inactive)
    }

    func testSelectedStatsTabUsesActiveDockPresentation() {
        let presentation = AppTabBarPresentation.item(for: .stats, selectedTab: .stats)

        XCTAssertEqual(presentation.title, "Stats")
        XCTAssertEqual(presentation.symbolName, "chart.line.uptrend.xyaxis.circle")
        XCTAssertEqual(presentation.selectionStyle, .pill)
        XCTAssertEqual(presentation.tone, .active)
    }

    func testTabBarLayoutKeepsEnoughLaneWidthForLabeledTabsOnCompactPhones() {
        let layout = AppTabBarLayout.layout(forContainerWidth: 393)

        XCTAssertGreaterThanOrEqual(layout.itemWidth, 64)
        XCTAssertGreaterThanOrEqual(layout.iconPointSize, 18)
        XCTAssertGreaterThanOrEqual(layout.labelHeight, 14)
    }

    func testTabBarLayoutUsesSmallerButSufficientCenterLaneThanPrototypeGap() {
        let layout = AppTabBarLayout.layout(forContainerWidth: 393)

        XCTAssertLessThan(layout.centerLaneWidth, AppChromeMetrics.centerDockReservation)
        XCTAssertGreaterThanOrEqual(layout.centerLaneWidth, AppChromeMetrics.floatingRoundButtonSize + 18)
    }

    func testTabBarOccupiedHeightIncludesExtraFootprintBeyondBaseBarHeight() {
        XCTAssertGreaterThan(AppChromeMetrics.tabBarOccupiedHeight, AppChromeMetrics.tabBarHeight)
    }

    func testRoundActionPresentationStaysEmphasizedAndReflectsSelection() {
        let active = AppTabBarPresentation.roundAction(selectedTab: .round)
        let inactive = AppTabBarPresentation.roundAction(selectedTab: .home)

        XCTAssertEqual(active.title, "Round")
        XCTAssertTrue(active.isSelected)
        XCTAssertTrue(active.showsHalo)
        XCTAssertFalse(inactive.isSelected)
        XCTAssertTrue(inactive.showsHalo)
    }

    func testTabBarPaletteAdaptsToLightAndDarkColorSchemes() {
        let light = AppTabBarPalette.forColorScheme(.light)
        let dark = AppTabBarPalette.forColorScheme(.dark)

        XCTAssertFalse(light.prefersDarkChrome)
        XCTAssertTrue(dark.prefersDarkChrome)
        XCTAssertGreaterThan(light.topHighlightOpacity, dark.topHighlightOpacity)
        XCTAssertGreaterThan(light.roundHaloOpacity, dark.roundHaloOpacity)
    }

    func testRoundScreensUseBottomPaddingBeyondDockInset() {
        XCTAssertGreaterThan(
            AppChromeMetrics.roundScreenBottomPadding,
            AppChromeMetrics.bottomContentInset
        )
    }

    func testActiveRoundCanBeSetAndCleared() {
        let state = AppState()
        let roundID = UUID()

        state.activeRoundID = roundID
        XCTAssertEqual(state.activeRoundID, roundID)

        state.activeRoundID = nil
        XCTAssertNil(state.activeRoundID)
    }

    func testRoundFlowStepUsesSetupSummaryForPlayersContext() {
        XCTAssertEqual(RoundFlowStep.players.progressLabel, "3 of 4")
        XCTAssertEqual(RoundFlowStep.players.progressValue, 0.75)
        XCTAssertEqual(
            RoundFlowStep.players.contextLine(
                courseName: "Royal Melbourne",
                detail: "Member tees • 6420 yds • 2 golfers ready"
            ),
            "Royal Melbourne • Member tees • 6420 yds • 2 golfers ready"
        )
    }

    func testRoundFlowStepReframesLiveContextAroundPlayState() {
        XCTAssertEqual(RoundFlowStep.live.progressLabel, "4 of 4")
        XCTAssertEqual(RoundFlowStep.live.progressValue, 1.0)
        XCTAssertEqual(
            RoundFlowStep.live.contextLine(
                courseName: "Royal Melbourne",
                detail: "Member tees • 6420 yds • 2 golfers ready"
            ),
            "Royal Melbourne • Live round in progress"
        )
    }

    func testRoundFlowStepProvidesRicherStageChromeForPlayers() {
        XCTAssertEqual(RoundFlowStep.players.eyebrow, "Player Check")
        XCTAssertEqual(RoundFlowStep.players.accentTitle, "Line up the foursome")
        XCTAssertEqual(RoundFlowStep.players.primaryPrompt, "Choose who is in before the first tee shot.")
    }

    func testRoundFlowStepChoosesForwardMovementWhenAdvancing() {
        XCTAssertEqual(
            RoundFlowStep.live.movement(from: .players),
            .forward
        )
    }

    func testRoundFlowStepChoosesBackwardMovementWhenReturning() {
        XCTAssertEqual(
            RoundFlowStep.detail.movement(from: .players),
            .backward
        )
    }

    func testRoundFlowStepExposesPreviousStepForBackNavigation() {
        XCTAssertEqual(RoundFlowStep.detail.previousStep, .courses)
        XCTAssertEqual(RoundFlowStep.players.previousStep, .detail)
        XCTAssertNil(RoundFlowStep.courses.previousStep)
    }

    func testRoundFlowStepUsesSourceStageNameForBackButtonLabel() {
        XCTAssertEqual(RoundFlowStep.detail.backButtonTitle, "Nearby Courses")
        XCTAssertEqual(RoundFlowStep.live.backButtonTitle, "Players")
    }

    func testLiveRoundStepRequestsImmersiveChrome() {
        XCTAssertTrue(RoundFlowStep.live.prefersImmersiveChrome)
        XCTAssertFalse(RoundFlowStep.players.prefersImmersiveChrome)
    }

    func testSetupRoundFlowStepsPreferCompactFlowHeader() {
        XCTAssertTrue(RoundFlowStep.courses.prefersCompactFlowHeader)
        XCTAssertTrue(RoundFlowStep.detail.prefersCompactFlowHeader)
        XCTAssertTrue(RoundFlowStep.players.prefersCompactFlowHeader)
        XCTAssertFalse(RoundFlowStep.live.prefersCompactFlowHeader)
    }

    func testRoundEntryRouteResolverKeepsNearbyIntentOnCourseList() {
        let resolution = RoundEntryRouteResolver.resolve(
            route: .nearbyCourses,
            courses: [.test(name: "Royal Melbourne", distanceKilometers: 3.2)]
        )

        XCTAssertEqual(resolution.step, .courses)
        XCTAssertNil(resolution.selectedCourse)
    }

    func testRoundEntryRouteResolverSelectsMatchingCourseDetail() {
        let selected = SwingPalCourse.test(name: "Royal Melbourne", distanceKilometers: 3.2)
        let other = SwingPalCourse.test(name: "Kingston Heath", distanceKilometers: 7.4)

        let resolution = RoundEntryRouteResolver.resolve(
            route: .courseDetail(selected.id),
            courses: [other, selected]
        )

        XCTAssertEqual(resolution.step, .detail)
        XCTAssertEqual(resolution.selectedCourse, selected)
    }

    func testRoundEntryRouteResolverFallsBackToCoursesWhenCourseIsMissing() {
        let resolution = RoundEntryRouteResolver.resolve(
            route: .courseDetail(UUID()),
            courses: [.test(name: "Royal Melbourne", distanceKilometers: 3.2)]
        )

        XCTAssertEqual(resolution.step, .courses)
        XCTAssertNil(resolution.selectedCourse)
    }

    func testInitialRoundPresentationPrefersNearbyCoursesIntentOverActiveRound() {
        let resolution = RoundInitialPresentationResolver.resolve(
            activeRoundExists: true,
            route: .nearbyCourses,
            courses: [.test(name: "Royal Melbourne", distanceKilometers: 3.2)]
        )

        XCTAssertEqual(resolution.step, .courses)
        XCTAssertNil(resolution.selectedCourse)
    }

    func testInitialRoundPresentationUsesLiveStepWhenNoIntentOverridesActiveRound() {
        let resolution = RoundInitialPresentationResolver.resolve(
            activeRoundExists: true,
            route: nil,
            courses: [.test(name: "Royal Melbourne", distanceKilometers: 3.2)]
        )

        XCTAssertEqual(resolution.step, .live)
        XCTAssertNil(resolution.selectedCourse)
    }
}

private struct StubActiveRoundStore: ActiveRoundStoring {
    func loadActiveRound() -> ActiveRoundSnapshot? { nil }
    func saveActiveRound(_ snapshot: ActiveRoundSnapshot?) {}
}

private struct StubBagStore: BagStoring {
    let bag: Bag

    func loadBag() -> Bag { bag }
    func saveBag(_ bag: Bag) {}
}

private struct StubGPSModeStore: GPSModeStoring {
    func loadGPSMode() -> AppGPSMode { .live }
    func saveGPSMode(_ mode: AppGPSMode) {}
}

private struct StubAppearanceModeStore: AppearanceModeStoring {
    func loadAppearanceMode() -> AppAppearanceMode { .system }
    func saveAppearanceMode(_ mode: AppAppearanceMode) {}
}
