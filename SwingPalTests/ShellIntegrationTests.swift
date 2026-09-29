import XCTest
@testable import SwingPal

@MainActor
final class ShellIntegrationTests: XCTestCase {
    func testProfileProductionViewCanCompleteSignInIntoAppState() {
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: .starter), gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())
        _ = AppShellView.makeProfileView(appState: state)

        XCTAssertEqual(state.authState, .guest)

        state.completeSignIn()

        XCTAssertEqual(state.authState, .authenticated)
    }

    func testProfileProductionViewCanAddClubsIntoAppState() {
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: .starter), gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())
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
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: .starter), gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())
        state.entitlements = .free

        let resolution = AppShellView.watchCompanionEntryResolution(for: state)

        XCTAssertEqual(resolution, .gated(.premium))
    }

    func testPremiumWatchCompanionEntryOpensLandingWithoutActiveRound() {
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: .starter), gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())
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
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: .starter), gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())
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

    func testRoundTabCanBeSelectedFromInitialState() {
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: .starter), gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())
        state.selectedTab = .round
        XCTAssertEqual(state.selectedTab, .round)
    }

    func testNearbyCoursesIntentSelectsRoundTabAndStoresCoursesRoute() {
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: .starter), gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())

        state.openNearbyCourses()

        XCTAssertEqual(state.selectedTab, .round)
        XCTAssertEqual(state.pendingRoundEntryRoute, .nearbyCourses)
    }

    func testCoursePreviewIntentSelectsRoundTabAndStoresCourseDetailRoute() {
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: .starter), gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())
        let courseID = UUID()

        state.openNearbyCourseDetail(courseID: courseID)

        XCTAssertEqual(state.selectedTab, .round)
        XCTAssertEqual(state.pendingRoundEntryRoute, .courseDetail(courseID))
    }

    func testConsumingPendingRoundEntryRouteClearsIntent() {
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: .starter), gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())
        let courseID = UUID()
        state.openNearbyCourseDetail(courseID: courseID)

        XCTAssertEqual(state.consumePendingRoundEntryRoute(), .courseDetail(courseID))
        XCTAssertNil(state.pendingRoundEntryRoute)
    }

    func testActiveRoundCanBeSetAndCleared() {
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: .starter), gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())
        let roundID = UUID()

        state.activeRoundID = roundID
        XCTAssertEqual(state.activeRoundID, roundID)

        state.activeRoundID = nil
        XCTAssertNil(state.activeRoundID)
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

    func testLiveRoundStepRequestsImmersiveChrome() {
        XCTAssertTrue(RoundFlowStep.live.prefersImmersiveChrome)
        XCTAssertFalse(RoundFlowStep.players.prefersImmersiveChrome)
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
