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

    var progressLabel: String {
        "\(rawValue + 1) of \(Self.allCases.count)"
    }

    var progressValue: Double {
        Double(rawValue + 1) / Double(Self.allCases.count)
    }

    var title: String {
        switch self {
        case .courses:
            return "Nearby Courses"
        case .detail:
            return "Course Detail"
        case .players:
            return "Players"
        case .live:
            return "Live Round"
        }
    }

    var subtitle: String {
        switch self {
        case .courses:
            return "Find the best nearby course and keep the round setup moving."
        case .detail:
            return "Confirm the right tees and lock the round context."
        case .players:
            return "Choose who is in the round before play starts."
        case .live:
            return "Map-first play with the course context already loaded."
        }
    }

    var eyebrow: String {
        switch self {
        case .courses:
            return "Setup Rail"
        case .detail:
            return "Course Lock"
        case .players:
            return "Player Check"
        case .live:
            return "On Course"
        }
    }

    var accentTitle: String {
        switch self {
        case .courses:
            return "Choose the right nearby start"
        case .detail:
            return "Confirm the tee context"
        case .players:
            return "Line up the foursome"
        case .live:
            return "Play with the full picture"
        }
    }

    var primaryPrompt: String {
        switch self {
        case .courses:
            return "Pick the course that feels right today."
        case .detail:
            return "Lock the tees before the round goes live."
        case .players:
            return "Choose who is in before the first tee shot."
        case .live:
            return "Distance, target, and strategy are already loaded."
        }
    }

    var previousStep: RoundFlowStep? {
        switch self {
        case .courses:
            return nil
        case .detail:
            return .courses
        case .players:
            return .detail
        case .live:
            return .players
        }
    }

    var backButtonTitle: String {
        previousStep?.title ?? ""
    }

    var prefersImmersiveChrome: Bool {
        self == .live
    }

    var prefersCompactFlowHeader: Bool {
        self != .live
    }

    func movement(from previousStep: RoundFlowStep?) -> RoundFlowMovement {
        guard let previousStep else {
            return .forward
        }
        return rawValue >= previousStep.rawValue ? .forward : .backward
    }

    func contextLine(courseName: String, detail: String) -> String {
        switch self {
        case .courses:
            return "Closest first • Choose a course to begin"
        case .detail, .players:
            return "\(courseName) • \(detail)"
        case .live:
            return "\(courseName) • Live round in progress"
        }
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
    @StateObject private var setupState = RoundSetupState(
        repository: CompositeCourseRepository(),
        importCoordinator: CourseImportCoordinator(
            fetcher: LiveOSMCourseGeometryFetcher(),
            aiValidator: FoundationModelsCourseValidator()
        )
    )
    @State private var isShowingReview = false
    @State private var step: RoundFlowStep = .courses
    @State private var movement: RoundFlowMovement = .forward

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
                            players: activeRoundState.reviewPlayers,
                            onDone: {
                                isShowingReview = false
                                appState.completeActiveRound()
                                // `setupState.reset()` already nils out
                                // `selectedCourse` along with tees/players,
                                // so we don't need to mutate it again here.
                                setupState.reset()
                                movement = .backward
                                step = .courses
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
                        }
                    )
                    .transition(stepTransition)
                }
            }
        }
        .id(step)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: step)
    }

    private var flowHeader: some View {
        Group {
            if step.prefersCompactFlowHeader {
                compactFlowHeader
            } else {
                expandedFlowHeader
            }
        }
        .padding(.horizontal, ShellTokens.Spacing.x20)
        .padding(.top, ShellTokens.Spacing.x12)
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
        let liveRound = LiveRoundState(
            hole: .init(number: 1, par: 4),
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

    private var compactFlowHeader: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            HStack(alignment: .firstTextBaseline) {
                Text(step.title)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(ShellTokens.ColorRole.textPrimary)

                Spacer()

                Text(step.progressLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ShellTokens.ColorRole.pine700)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(ShellTokens.ColorRole.surfaceTinted, in: Capsule())
            }

            Text(step.primaryPrompt)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ShellTokens.ColorRole.textPrimary)

            Text(
                step.contextLine(
                    courseName: setupState.roundSetupSummaryTitle,
                    detail: setupState.roundSetupSummaryDetail
                )
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(ShellTokens.ColorRole.textSecondary)
            .lineLimit(2)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ShellTokens.ColorRole.bgGrouped)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ShellTokens.ColorRole.pine700,
                                    ShellTokens.ColorRole.pine500
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * step.progressValue)
                }
            }
            .frame(height: 8)
        }
        .padding(ShellTokens.Spacing.x16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ShellTokens.ColorRole.surfacePrimary,
            in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                .stroke(ShellTokens.ColorRole.strokeDefault, lineWidth: 1)
        )
        .shadow(color: ShellTokens.Shadow.soft, radius: 10, y: 6)
    }

    private var expandedFlowHeader: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(ShellTokens.ColorRole.surfaceOverlay)
                .frame(width: 180, height: 180)
                .offset(x: 48, y: -52)

            Circle()
                .fill(ShellTokens.ColorRole.pine300.opacity(0.16))
                .frame(width: 110, height: 110)
                .offset(x: -12, y: 82)

            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                HStack {
                    Text(step.eyebrow)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ShellTokens.ColorRole.pine700)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(ShellTokens.ColorRole.surfaceOverlay, in: Capsule())
                    Spacer()
                    Text(step.progressLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(ShellTokens.ColorRole.surfaceOverlay, in: Capsule())
                }

                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                    Text(step.title)
                        .font(.system(size: 36, weight: .semibold, design: .serif))
                        .foregroundStyle(ShellTokens.ColorRole.textPrimary)

                    Text(step.accentTitle)
                        .font(.headline)
                        .foregroundStyle(ShellTokens.ColorRole.pine700)

                    Text(step.primaryPrompt)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ShellTokens.ColorRole.textPrimary)

                    Text(step.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                }

                HStack(spacing: ShellTokens.Spacing.x8) {
                    flowChip(
                        step.contextLine(
                            courseName: setupState.roundSetupSummaryTitle,
                            detail: setupState.roundSetupSummaryDetail
                        )
                    )
                    flowChip(step == .live ? "Round is active" : "Setup in motion")
                }
                .contentTransition(.opacity)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(ShellTokens.ColorRole.bgGrouped)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        ShellTokens.ColorRole.pine700,
                                        ShellTokens.ColorRole.pine500
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * step.progressValue)
                    }
                }
                .frame(height: 10)
            }
            .padding(ShellTokens.Spacing.x20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    ShellTokens.ColorRole.surfacePrimary,
                    step == .live ? ShellTokens.ColorRole.surfaceTinted : ShellTokens.ColorRole.surfaceSecondary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: ShellTokens.Radius.lg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.lg)
                .stroke(ShellTokens.ColorRole.strokeDefault, lineWidth: 1)
        )
        .shadow(color: ShellTokens.Shadow.soft, radius: 14, y: 10)
    }

    private func flowChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(ShellTokens.ColorRole.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(ShellTokens.ColorRole.surfaceOverlay, in: Capsule())
    }

    private func navigate(to nextStep: RoundFlowStep) {
        movement = nextStep.movement(from: step)
        step = nextStep
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: movement.insertionEdge).combined(with: .opacity),
            removal: .opacity
        )
    }
}
