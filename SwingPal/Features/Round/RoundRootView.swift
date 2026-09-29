import SwiftUI
import CoreLocation

enum RoundFlowMovement: Equatable {
    case forward
    case backward

    var insertionEdge: Edge {
        switch self {
        case .forward:
            return .trailing
        case .backward:
            return .leading
        }
    }
}

enum RoundFlowStep: Int, CaseIterable {
    case courses
    case detail
    case players
    case live

    var prefersImmersiveChrome: Bool {
        self == .live
    }

    func movement(from previousStep: RoundFlowStep?) -> RoundFlowMovement {
        guard let previousStep else {
            return .forward
        }
        return rawValue >= previousStep.rawValue ? .forward : .backward
    }

}

struct RoundEntryRouteResolution: Equatable {
    let step: RoundFlowStep
    let selectedCourse: SwingPalCourse?
}

enum RoundInitialPresentationResolver {
    static func resolve(
        activeRoundExists: Bool,
        route: RoundEntryRoute?,
        courses: [SwingPalCourse]
    ) -> RoundEntryRouteResolution {
        if let route {
            return RoundEntryRouteResolver.resolve(route: route, courses: courses)
        }

        if activeRoundExists {
            return .init(step: .live, selectedCourse: nil)
        }

        return .init(step: .courses, selectedCourse: nil)
    }
}

enum RoundEntryRouteResolver {
    static func resolve(route: RoundEntryRoute?, courses: [SwingPalCourse]) -> RoundEntryRouteResolution {
        switch route {
        case .nearbyCourses, .none:
            return .init(step: .courses, selectedCourse: nil)
        case .courseDetail(let courseID):
            guard let selectedCourse = courses.first(where: { $0.id == courseID }) else {
                return .init(step: .courses, selectedCourse: nil)
            }
            return .init(step: .detail, selectedCourse: selectedCourse)
        }
    }
}

struct RoundRootView: View {
    @ObservedObject var appState: AppState
    let onAuthGateRequired: (GateRequirement) -> Void
    @StateObject private var setupState = RoundSetupState(
        repository: CompositeCourseRepository(),
        importCoordinator: CourseImportCoordinator(
            fetcher: LiveOSMCourseGeometryFetcher(),
            aiValidator: FoundationModelsCourseValidator()
        )
    )
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingReview = false
    @State private var step: RoundFlowStep = .courses
    @State private var movement: RoundFlowMovement = .forward

    init(appState: AppState, onAuthGateRequired: @escaping (GateRequirement) -> Void = { _ in }) {
        self.appState = appState
        self.onAuthGateRequired = onAuthGateRequired
    }

    var body: some View {
        NavigationStack {
            Group {
                if step.prefersImmersiveChrome {
                    liveRoundScreen
                } else {
                    setupFlowScreen
                }
            }
            .toolbar(step.prefersImmersiveChrome ? .hidden : .visible, for: .navigationBar)
            .onAppear {
                applyInitialPresentation()
                appState.roundChromeMode = step.prefersImmersiveChrome ? .live : .setup
            }
            .onChange(of: step, initial: false) { _, newValue in
                appState.roundChromeMode = newValue.prefersImmersiveChrome ? .live : .setup
            }
            .onDisappear {
                appState.roundChromeMode = .setup
            }
            .sheet(isPresented: $isShowingReview) {
                NavigationStack {
                    if let activeRoundState = appState.activeRoundState {
                        RoundReviewView(
                            state: activeRoundState,
                            onInspectHole: { index in
                                activeRoundState.inspectHole(at: index)
                                isShowingReview = false
                            },
                            onDone: {
                                isShowingReview = false
                                appState.completeActiveRound()
                                // `setupState.reset()` already nils out
                                // `selectedCourse` along with tees/players,
                                // so we don't need to mutate it again here.
                                setupState.reset()
                                movement = .backward
                                step = .courses
                                appState.selectedTab = .home
                            }
                        )
                    }
                }
            }
        }
    }

    private var setupFlowScreen: some View {
        RoundSetupView(
            state: setupState,
            distanceUnit: appState.distanceUnit,
            requiresLocationPermissionPrimer: shouldExplainLocationPermission,
            onStartRound: {
                startRound()
            },
            onExitSetup: {
                setupState.reset()
                movement = .backward
                step = .courses
                appState.selectedTab = .home
            },
            authState: appState.authState,
            onAuthGateRequired: onAuthGateRequired,
            myUserId: UUID(uuidString: appState.currentUser?.id ?? ""),
            onSearchPlayers: { query in
                try await appState.searchProfiles(query: query)
            },
            onFetchPlayerProfileById: { userId in
                try await appState.fetchProfile(userId: userId)
            },
            onDiscoveredCourseSelected: { discovered in
                setupState.startImport(discovered)
            }
        )
        .fullScreenCover(
            isPresented: Binding(
                get: { setupState.currentImportStage != nil },
                set: { isShowing in
                    if !isShowing { setupState.cancelImport() }
                }
            )
        ) {
            CourseImportLoadingOverlay(
                courseName: setupState.pendingImportDiscovery?.name ?? "Course",
                stage: setupState.currentImportStage,
                validation: setupState.lastImportValidation,
                onUseProvisional: {
                    setupState.acceptImportedCourse()
                },
                onRetry: {
                    if let discovered = setupState.pendingImportDiscovery {
                        setupState.cancelImport()
                        setupState.startImport(discovered)
                    } else {
                        setupState.cancelImport()
                    }
                },
                onDismiss: {
                    setupState.cancelImport()
                }
            )
        }
    }

    private var shouldExplainLocationPermission: Bool {
        CLLocationManager.authorizationStatus() == .notDetermined
    }

    private var liveRoundScreen: some View {
        ZStack(alignment: .topLeading) {
            roundStepBody
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var roundStepBody: some View {
        ZStack {
            switch step {
            case .courses:
                setupFlowScreen
                    .transition(stepTransition)

            case .detail:
                setupFlowScreen
                    .transition(stepTransition)

            case .players:
                setupFlowScreen
                    .transition(stepTransition)

            case .live:
                if let liveRoundState = appState.activeRoundState {
                    FreshLiveRoundScreen(
                        state: liveRoundState,
                        onFinishHole: {
                            if !liveRoundState.advanceToNextHole() {
                                isShowingReview = true
                            }
                        },
                        onSaveAndExitRound: {
                            appState.suspendActiveRound()
                            setupState.reset()
                            movement = .backward
                            step = .courses
                            appState.selectedTab = .home
                        },
                        onDiscardRound: {
                            appState.discardActiveRound()
                            setupState.reset()
                            movement = .backward
                            step = .courses
                            appState.selectedTab = .home
                        },
                        onReviewRound: {
                            isShowingReview = true
                        }
                    )
                    .transition(stepTransition)
                }
            }
        }
        .id(step)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.88), value: step)
    }

    private func applyInitialPresentation() {
        let resolution = RoundInitialPresentationResolver.resolve(
            activeRoundExists: appState.activeRoundState != nil,
            route: appState.consumePendingRoundEntryRoute(),
            courses: setupState.sortedCourses
        )

        if resolution.step == .live {
            movement = .forward
            step = .live
            return
        }

        setupState.reset()

        if let selected = resolution.selectedCourse {
            setupState.selectCourse(selected)
        }

        movement = .forward
        step = resolution.step
    }

    private func startRound() {
        let roundID = UUID()
        guard let selectedCourse = setupState.selectedCourse else {
            // Defensive: `canStartRound` should prevent this path.
            return
        }
        let firstHole = selectedCourse.holes.min { $0.number < $1.number }
        let liveRound = LiveRoundState(
            hole: .init(number: firstHole?.number ?? 1, par: firstHole?.par ?? 4),
            courseName: selectedCourse.name,
            courseCoordinate: .init(
                latitude: selectedCourse.coordinate.latitude,
                longitude: selectedCourse.coordinate.longitude
            ),
            courseHoles: selectedCourse.holes,
            selectedTeeName: setupState.selectedTeeName,
            selectedTeeYards: setupState.selectedTeeYards,
            players: setupState.players,
            clubCarryMetersByClubName: appState.liveRoundClubCarryMetersByClubName,
            clubAutoRecommendationEnabled: appState.clubAutoRecommendationEnabled,
            weatherLoader: AppleWeatherKitLoader(),
            locationProvider: appState.makeRoundLocationProvider()
        )
        appState.resumeRound(id: roundID, state: liveRound, chromeMode: .live)
        navigate(to: .live)
    }

    private func navigate(to nextStep: RoundFlowStep) {
        movement = nextStep.movement(from: step)
        step = nextStep
    }

    private var stepTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: movement.insertionEdge).combined(with: .opacity),
            removal: .opacity
        )
    }
}
