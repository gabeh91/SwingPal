import SwiftUI

enum AppChromeMetrics {
    static let floatingRoundButtonSize: CGFloat = 68
    static let floatingRoundButtonLift: CGFloat = 28
    static let tabBarHeight: CGFloat = 96
    static let tabBarTopAllowance: CGFloat = 18
    static let tabBarBottomPadding: CGFloat = 10
    static let tabBarOccupiedHeight: CGFloat = tabBarHeight + tabBarTopAllowance + tabBarBottomPadding
    static let centerDockReservation: CGFloat = floatingRoundButtonSize + 44
    static let bottomContentInset: CGFloat = tabBarOccupiedHeight + 56
    static let roundScreenBottomPadding: CGFloat = bottomContentInset + 32
    static let horizontalPadding: CGFloat = 16
}

struct AppTabBarLayout: Equatable {
    let itemWidth: CGFloat
    let centerLaneWidth: CGFloat
    let iconPointSize: CGFloat
    let labelHeight: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat
    let itemContentHeight: CGFloat

    static func layout(forContainerWidth width: CGFloat) -> AppTabBarLayout {
        let horizontalPadding = AppChromeMetrics.horizontalPadding
        let availableWidth = max(width - (horizontalPadding * 2), 280)
        let centerLaneWidth = max(AppChromeMetrics.floatingRoundButtonSize + 18, min(AppChromeMetrics.floatingRoundButtonSize + 28, availableWidth * 0.24))
        let itemWidth = max(64, (availableWidth - centerLaneWidth) / 4)

        return .init(
            itemWidth: itemWidth,
            centerLaneWidth: centerLaneWidth,
            iconPointSize: 18,
            labelHeight: 14,
            topInset: 14,
            bottomInset: 10,
            itemContentHeight: 58
        )
    }
}

enum AppTabBarTone: Equatable {
    case active
    case inactive
}

enum AppTabBarSelectionStyle: Equatable {
    case none
    case pill
}

struct AppTabBarItemPresentation: Equatable {
    let title: String
    let symbolName: String
    let selectionStyle: AppTabBarSelectionStyle
    let tone: AppTabBarTone
}

struct AppRoundActionPresentation: Equatable {
    let title: String
    let isSelected: Bool
    let showsHalo: Bool
}

struct AppTabBarPalette {
    let prefersDarkChrome: Bool
    let shellBackground: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let border: Color
    let topHighlight: Color
    let roundHalo: Color
    let activeTint: Color
    let inactiveTint: Color
    let roundLabelTint: Color
    let roundGradientTop: Color
    let roundGradientBottom: Color
    let roundStroke: Color
    let activePillTop: Color
    let activePillBottom: Color
    let activePillBorder: Color
    let activePillHighlight: Color
    let activePillShadow: Color
    let topHighlightOpacity: Double
    let roundHaloOpacity: Double

    static func forColorScheme(_ colorScheme: ColorScheme) -> AppTabBarPalette {
        switch colorScheme {
        case .dark:
            let backgroundTop = Color(red: 0.14, green: 0.18, blue: 0.16).opacity(0.96)
            let backgroundBottom = Color(red: 0.08, green: 0.10, blue: 0.09).opacity(0.94)
            let border = Color.white.opacity(0.18)
            let topHighlight = Color.white.opacity(0.16)
            let roundHalo = ShellTokens.ColorRole.pine500.opacity(0.18)
            let inactiveTint = Color.white.opacity(0.58)
            let roundLabelTint = Color.white.opacity(0.72)
            let roundStroke = Color.white.opacity(0.18)
            let activePillTop = Color.white.opacity(0.08)
            let activePillBottom = ShellTokens.ColorRole.pine500.opacity(0.20)
            let activePillBorder = Color.white.opacity(0.20)
            let activePillHighlight = Color.white.opacity(0.10)
            let activePillShadow = ShellTokens.ColorRole.pine500.opacity(0.18)

            return .init(
                prefersDarkChrome: true,
                shellBackground: ShellTokens.ColorRole.bgApp,
                backgroundTop: backgroundTop,
                backgroundBottom: backgroundBottom,
                border: border,
                topHighlight: topHighlight,
                roundHalo: roundHalo,
                activeTint: ShellTokens.ColorRole.pine500,
                inactiveTint: inactiveTint,
                roundLabelTint: roundLabelTint,
                roundGradientTop: ShellTokens.ColorRole.pine500,
                roundGradientBottom: ShellTokens.ColorRole.pine700,
                roundStroke: roundStroke,
                activePillTop: activePillTop,
                activePillBottom: activePillBottom,
                activePillBorder: activePillBorder,
                activePillHighlight: activePillHighlight,
                activePillShadow: activePillShadow,
                topHighlightOpacity: 0.16,
                roundHaloOpacity: 0.18
            )
        default:
            let backgroundTop = Color.white.opacity(0.90)
            let topHighlight = Color.white.opacity(0.52)
            let roundStroke = Color.white.opacity(0.28)
            let activePillTop = Color.white.opacity(0.74)
            let activePillBottom = ShellTokens.ColorRole.pine300.opacity(0.38)
            let activePillBorder = Color.white.opacity(0.72)
            let activePillHighlight = Color.white.opacity(0.56)
            let activePillShadow = ShellTokens.ColorRole.pine700.opacity(0.10)

            return .init(
                prefersDarkChrome: false,
                shellBackground: ShellTokens.ColorRole.bgApp,
                backgroundTop: backgroundTop,
                backgroundBottom: ShellTokens.ColorRole.surfaceOverlay,
                border: ShellTokens.ColorRole.strokeDefault,
                topHighlight: topHighlight,
                roundHalo: ShellTokens.ColorRole.surfaceOverlay,
                activeTint: ShellTokens.ColorRole.pine700,
                inactiveTint: ShellTokens.ColorRole.textTertiary,
                roundLabelTint: ShellTokens.ColorRole.textTertiary,
                roundGradientTop: ShellTokens.ColorRole.pine700,
                roundGradientBottom: ShellTokens.ColorRole.pine500,
                roundStroke: roundStroke,
                activePillTop: activePillTop,
                activePillBottom: activePillBottom,
                activePillBorder: activePillBorder,
                activePillHighlight: activePillHighlight,
                activePillShadow: activePillShadow,
                topHighlightOpacity: 0.52,
                roundHaloOpacity: 1.0
            )
        }
    }
}

enum AppTabBarPresentation {
    static func item(for tab: AppTab, selectedTab: AppTab) -> AppTabBarItemPresentation {
        let isSelected = tab == selectedTab
        switch tab {
        case .home:
            return .init(
                title: "Home",
                symbolName: "house",
                selectionStyle: isSelected ? .pill : .none,
                tone: isSelected ? .active : .inactive
            )
        case .social:
            return .init(
                title: "Social",
                symbolName: "person.2",
                selectionStyle: isSelected ? .pill : .none,
                tone: isSelected ? .active : .inactive
            )
        case .stats:
            return .init(
                title: "Stats",
                symbolName: "chart.line.uptrend.xyaxis.circle",
                selectionStyle: isSelected ? .pill : .none,
                tone: isSelected ? .active : .inactive
            )
        case .profile:
            return .init(
                title: "Profile",
                symbolName: "person.crop.circle",
                selectionStyle: isSelected ? .pill : .none,
                tone: isSelected ? .active : .inactive
            )
        case .round:
            return .init(
                title: "Round",
                symbolName: "flag.filled.and.flag.crossed",
                selectionStyle: .none,
                tone: .active
            )
        }
    }

    static func roundAction(selectedTab: AppTab) -> AppRoundActionPresentation {
        .init(
            title: "Round",
            isSelected: selectedTab == .round,
            showsHalo: true
        )
    }
}

struct WatchCompanionLandingModel: Equatable {
    let connectionBadge: String
    let setupTitle: String
    let setupDetail: String
    let mutationSourceText: String
    let canOpenLiveRound: Bool
    let primaryActionTitle: String
}

enum WatchCompanionEntryResolution: Equatable {
    case gated(GateRequirement)
    case landing(WatchCompanionLandingModel)
}

struct AppShellView: View {
    /// Allow `SwingPalApp` to supply the same `AppState` it uses for the
    /// auth gate; previews and `ContentView` keep using the default
    /// `AppState()` by passing `nil`.
    @StateObject private var appState: AppState
    private let injectedAuthService: AuthService?
    @Environment(\.colorScheme) private var colorScheme
    @State private var authGate: GateRequirement = .none

    init(appState: AppState? = nil, authService: AuthService? = nil) {
        _appState = StateObject(wrappedValue: appState ?? AppState())
        injectedAuthService = authService
    }
    @State private var isWatchCompanionPresented = false
    @State private var isRoundResumePromptPresented = false

    private var showsTabBar: Bool {
        !(appState.selectedTab == .round && appState.roundChromeMode == .setup)
        && !appState.isImmersiveRoundActive
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .home:
                    Self.makeHomeView(
                        appState: appState,
                        onAuthGateRequired: { requirement in
                            authGate = requirement
                        },
                        onOpenWatchCompanion: {
                            isWatchCompanionPresented = true
                        }
                    )

                case .social:
                    SocialView(appState: appState)

                case .stats:
                    StatsView(
                        model: StatsViewModel(
                            previousRounds: appState.previousRounds,
                            analyses: UserDefaultsRoundSummaryAnalysisStore().load()
                        )
                    )

                case .round:
                    RoundRootView(
                        appState: appState,
                        onAuthGateRequired: { requirement in
                            authGate = requirement
                        }
                    )

                case .profile:
                    Self.makeProfileView(
                        appState: appState,
                        onAuthGateRequired: { requirement in
                            authGate = requirement
                        },
                        onOpenWatchCompanion: {
                            isWatchCompanionPresented = true
                        }
                    )
                }
            }

            if showsTabBar {
                SwingPalTabBar(
                    selectedTab: $appState.selectedTab,
                    onRoundAction: handleRoundTabTapped
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(ShellTokens.ColorRole.bgApp.ignoresSafeArea())
        .preferredColorScheme(appState.appearanceMode.preferredColorScheme)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: showsTabBar)
        .onChange(of: appState.authState) { _, authState in
            if authState == .authenticated, authGate == .signIn {
                authGate = .none
            }
        }
        .sheet(isPresented: Binding(
            get: { authGate == .signIn },
            set: { isPresented in
                if !isPresented {
                    authGate = .none
                }
            }
        )) {
            switch AuthModalPresentation.resolve(for: .signIn) {
            case .authFlow:
                AuthFlowModalView(
                    authService: resolvedAuthService,
                    onDismiss: { authGate = .none }
                )
                .preferredColorScheme(appState.appearanceMode.preferredColorScheme)
            case .premiumGate:
                EmptyView()
            }
        }
        .sheet(isPresented: Binding(
            get: { authGate == .premium },
            set: { isPresented in
                if !isPresented {
                    authGate = .none
                }
            }
        )) {
            PremiumGateView(
                onUpgrade: {
                    appState.entitlements = .premium
                    authGate = .none
                },
                onDismiss: {
                    authGate = .none
                }
            )
        }
        .sheet(isPresented: $isWatchCompanionPresented) {
            WatchCompanionLandingView(
                model: Self.watchCompanionLandingModel(for: appState),
                onOpenRound: {
                    isWatchCompanionPresented = false
                    appState.selectedTab = .round
                },
                onDismiss: {
                    isWatchCompanionPresented = false
                }
            )
        }
        .sheet(isPresented: $isRoundResumePromptPresented) {
            RoundResumePromptView(
                activeRoundTitle: appState.activeRoundState?.courseName,
                onResume: {
                    isRoundResumePromptPresented = false
                    appState.roundChromeMode = .live
                    appState.selectedTab = .round
                },
                onDiscardAndStartNew: {
                    isRoundResumePromptPresented = false
                    appState.discardActiveRound()
                    appState.selectedTab = .round
                },
                onDismiss: {
                    isRoundResumePromptPresented = false
                }
            )
            .preferredColorScheme(appState.appearanceMode.preferredColorScheme)
            .presentationSizing(.page)
        }
        .sheet(item: $appState.followInvite) { invite in
            FollowInviteSheet(
                invite: invite,
                appState: appState,
                palette: SocialPalette.forColorScheme(colorScheme)
            )
            .presentationDetents([.medium])
        }
    }

    private var resolvedAuthService: AuthService {
        switch AuthFlowServiceSource.resolve(
            hasInjectedService: injectedAuthService != nil,
            hasAppStateService: appState.authService != nil
        ) {
        case .injected:
            return injectedAuthService!
        case .appState:
            return appState.authService!
        case .fallbackMock:
            return MockAuthService()
        }
    }

    private func handleRoundTabTapped() {
        if appState.selectedTab != .round, appState.activeRoundState != nil {
            isRoundResumePromptPresented = true
            return
        }

        appState.selectedTab = .round
    }

    static func makeHomeView(
        appState: AppState,
        onAuthGateRequired: @escaping (GateRequirement) -> Void = { _ in },
        onOpenWatchCompanion: @escaping () -> Void = {}
    ) -> HomeView {
        let nearbyCourses = CompositeCourseRepository().nearbyCourses()
        return HomeView(
            model: HomeViewModel(
                activeRoundTitle: appState.activeRoundState?.courseName,
                previousRounds: appState.previousRounds,
                analyses: UserDefaultsRoundSummaryAnalysisStore().load(),
                nearbyCourses: nearbyCourses,
                handicapBadgeText: appState.handicapBadgeText,
                distanceUnit: appState.distanceUnit
            ),
            entitlements: appState.entitlements,
            onOpenRound: { appState.selectedTab = .round },
            onOpenNearbyCourse: { courseID in
                appState.openNearbyCourseDetail(courseID: courseID)
                appState.selectedTab = .round
            },
            onOpenNearbyCourses: {
                appState.openNearbyCourses()
                appState.selectedTab = .round
            },
            onOpenWatchCompanion: {
                switch watchCompanionEntryResolution(for: appState) {
                case .gated(let requirement):
                    onAuthGateRequired(requirement)
                case .landing:
                    onOpenWatchCompanion()
                }
            }
        )
    }

    static func makeProfileView(
        appState: AppState,
        onAuthGateRequired: @escaping (GateRequirement) -> Void = { _ in },
        onOpenWatchCompanion: @escaping () -> Void = {}
    ) -> ProfileView {
        ProfileView(
            authState: appState.authState,
            entitlements: appState.entitlements,
            bag: appState.bag,
            previousRounds: appState.previousRounds,
            gpsMode: appState.gpsMode,
            appearanceMode: appState.appearanceMode,
            distanceUnit: appState.distanceUnit,
            onGPSModeChanged: { mode in
                appState.setGPSMode(mode)
            },
            onAppearanceModeChanged: { mode in
                appState.setAppearanceMode(mode)
            },
            onDistanceUnitChanged: { unit in
                appState.setDistanceUnit(unit)
            },
            onSignInTapped: {
                onAuthGateRequired(.signIn)
            },
            onSignOut: {
                Task { await appState.signOut() }
            },
            onAddClubs: { clubs in
                appState.addClubs(clubs)
            },
            onUpdateClub: { club in
                appState.updateClub(club)
            },
            onDeleteClub: { clubID in
                appState.deleteClub(id: clubID)
            },
            onWatchCompanionTapped: {
                switch watchCompanionEntryResolution(for: appState) {
                case .gated(let requirement):
                    onAuthGateRequired(requirement)
                case .landing:
                    onOpenWatchCompanion()
                }
            },
            handicapSnapshot: appState.handicapSnapshot,
            handicapEstimate: appState.handicapIndexEstimate,
            onSetManualHandicapIndex: { appState.setManualHandicapIndex($0) },
            currentUserDisplayName: Self.accountDisplayLabel(for: appState),
            cloudProfile: appState.cloudUserProfile,
            onRefreshProfile: { await appState.refreshUserProfile() },
            onSavePublicProfile: { update in
                try await appState.savePublicProfile(update)
            }
        )
    }

    private static func accountDisplayLabel(for appState: AppState) -> String? {
        if let name = appState.cloudUserProfile?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        if let name = appState.currentUser?.displayName, !name.isEmpty {
            return name
        }
        if let email = appState.currentUser?.email, !email.isEmpty {
            return email
        }
        return nil
    }

    static func watchCompanionEntryResolution(for appState: AppState) -> WatchCompanionEntryResolution {
        let resolver = GatedActionResolver(
            authState: appState.authState,
            entitlements: appState.entitlements
        )

        let requirement = resolver.watchCompanionRequirement()
        guard requirement == .none else {
            return .gated(requirement)
        }

        return .landing(watchCompanionLandingModel(for: appState))
    }

    static func watchCompanionLandingModel(for appState: AppState) -> WatchCompanionLandingModel {
        guard let snapshot = appState.activeRoundState?.roundCompanionSnapshot else {
            return .init(
                connectionBadge: "Offline",
                setupTitle: "Setup Not Ready",
                setupDetail: "Start or resume a round on iPhone to activate watch sync and live controls.",
                mutationSourceText: "Phone authoritative",
                canOpenLiveRound: false,
                primaryActionTitle: "Open Round Setup"
            )
        }

        let connectionBadge: String
        switch snapshot.connectionState {
        case .connected:
            connectionBadge = "Connected"
        case .syncing:
            connectionBadge = "Syncing"
        case .disconnected:
            connectionBadge = "Offline"
        }

        let mutationSourceText: String
        switch snapshot.lastMutationSource {
        case .phone:
            mutationSourceText = "Last update from iPhone"
        case .watch:
            mutationSourceText = "Last update from Watch"
        }

        return .init(
            connectionBadge: connectionBadge,
            setupTitle: "Live Round Ready",
            setupDetail: "Your watch companion can mirror yardages, club context, and quick actions for the active round.",
            mutationSourceText: mutationSourceText,
            canOpenLiveRound: true,
            primaryActionTitle: "Open Live Round"
        )
    }
}

private struct WatchCompanionLandingView: View {
    let model: WatchCompanionLandingModel
    let onOpenRound: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("APPLE WATCH COMPANION")
                            .font(ShellTokens.Typography.eyebrow)
                            .tracking(1.2)
                            .foregroundStyle(ShellTokens.ColorRole.pine700)

                        Text("Keep live round control ready on your wrist.")
                            .font(ShellTokens.Typography.sectionTitle)
                            .foregroundStyle(ShellTokens.ColorRole.textPrimary)

                        Text("Check connection trust, confirm setup, and jump straight back into the live round when you’re ready.")
                            .font(ShellTokens.Typography.body)
                            .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                    }

                    watchStatusCard
                    setupCard

                    Button(action: onOpenRound) {
                        HStack {
                            Text(model.primaryActionTitle)
                                .font(.headline.weight(.semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(ShellTokens.ColorRole.pine700, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(ShellTokens.ColorRole.bgApp.ignoresSafeArea())
            .navigationTitle("Watch Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }

    private var watchStatusCard: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(ShellTokens.ColorRole.surfaceOverlay)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(ShellTokens.ColorRole.strokeDefault, lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connection")
                        .font(ShellTokens.Typography.microEyebrow)
                        .tracking(1.2)
                        .foregroundStyle(ShellTokens.ColorRole.textTertiary)

                    Text(model.connectionBadge)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(ShellTokens.ColorRole.textPrimary)

                    Text(model.mutationSourceText)
                        .font(ShellTokens.Typography.body)
                        .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                }
                .padding(20)
            }
            .frame(height: 154)
    }

    private var setupCard: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(ShellTokens.ColorRole.surfaceSecondary)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(ShellTokens.ColorRole.strokeDefault, lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Setup Readiness")
                        .font(ShellTokens.Typography.microEyebrow)
                        .tracking(1.2)
                        .foregroundStyle(ShellTokens.ColorRole.textTertiary)

                    Text(model.setupTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(ShellTokens.ColorRole.textPrimary)

                    Text(model.setupDetail)
                        .font(ShellTokens.Typography.body)
                        .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                }
                .padding(20)
            }
            .frame(height: 178)
    }
}

private struct SwingPalTabBar: View {
    @Binding var selectedTab: AppTab
    let onRoundAction: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let layout = AppTabBarLayout.layout(forContainerWidth: proxy.size.width)
            let roundAction = AppTabBarPresentation.roundAction(selectedTab: selectedTab)
            let palette = AppTabBarPalette.forColorScheme(colorScheme)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.backgroundTop,
                                palette.backgroundBottom
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(palette.border, lineWidth: 1)
                    )
                    .frame(height: AppChromeMetrics.tabBarHeight)
                    .shadow(color: ShellTokens.Shadow.soft, radius: 24, y: 10)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(palette.topHighlight)
                            .frame(height: 1)
                            .padding(.horizontal, 24)
                            .padding(.top, 1)
                    }

                HStack(spacing: 0) {
                    tabButton(tab: .home, layout: layout)
                    tabButton(tab: .social, layout: layout)
                    Color.clear
                        .frame(width: layout.centerLaneWidth)
                    tabButton(tab: .stats, layout: layout)
                    tabButton(tab: .profile, layout: layout)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, layout.topInset)
                .padding(.bottom, layout.bottomInset)
                .frame(height: AppChromeMetrics.tabBarHeight, alignment: .top)

                VStack(spacing: 6) {
                    Button(action: onRoundAction) {
                        ZStack {
                            if roundAction.showsHalo {
                                Circle()
                                    .fill(palette.roundHalo)
                                    .frame(width: AppChromeMetrics.floatingRoundButtonSize + 20, height: AppChromeMetrics.floatingRoundButtonSize + 20)
                                    .blur(radius: 4)
                            }

                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            palette.roundGradientTop,
                                            palette.roundGradientBottom
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: AppChromeMetrics.floatingRoundButtonSize, height: AppChromeMetrics.floatingRoundButtonSize)
                                .shadow(color: ShellTokens.Shadow.floating, radius: 14, y: 8)
                                .overlay(
                                    Circle()
                                        .stroke(palette.roundStroke, lineWidth: 1)
                                )
                            Image(systemName: SwingPalBrandMark.systemImageName)
                                .foregroundStyle(ShellTokens.ColorRole.textInverse)
                                .font(.system(size: SwingPalBrandMark.symbolPointSize, weight: .semibold))
                        }
                    }
                    .offset(y: -AppChromeMetrics.floatingRoundButtonLift)
                    .accessibilityLabel("Round")

                    Text(roundAction.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            roundAction.isSelected
                            ? palette.activeTint
                            : palette.roundLabelTint
                        )
                        .offset(y: -20)
                }
            }
            .padding(.horizontal, AppChromeMetrics.horizontalPadding)
            .padding(.bottom, AppChromeMetrics.tabBarBottomPadding)
            .background(.clear)
        }
        .frame(height: AppChromeMetrics.tabBarHeight + AppChromeMetrics.tabBarTopAllowance)
    }

    private func tabButton(tab: AppTab, layout: AppTabBarLayout) -> some View {
        let presentation = AppTabBarPresentation.item(for: tab, selectedTab: selectedTab)
        let palette = AppTabBarPalette.forColorScheme(colorScheme)
        let isSelected = presentation.selectionStyle == .pill

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: presentation.symbolName)
                    .font(.system(size: layout.iconPointSize, weight: .semibold))
                    .frame(height: 20)
                Text(presentation.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(height: layout.labelHeight)
            }
            .foregroundStyle(
                presentation.tone == .active
                ? palette.activeTint
                : palette.inactiveTint
            )
            .frame(width: layout.itemWidth - 10, height: layout.itemContentHeight - 6)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.activePillTop,
                                palette.activePillBottom
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(isSelected ? 1 : 0)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(palette.activePillBorder, lineWidth: 1)
                    .opacity(isSelected ? 1 : 0)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(palette.activePillHighlight)
                            .frame(height: 1)
                            .padding(.horizontal, 14)
                            .padding(.top, 1)
                            .opacity(isSelected ? 1 : 0)
                    }
            }
            .shadow(
                color: isSelected ? palette.activePillShadow : .clear,
                radius: 10,
                y: 6
            )
            .frame(width: layout.itemWidth, height: layout.itemContentHeight, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct RoundResumePromptView: View {
    @Environment(\.colorScheme) private var colorScheme
    let activeRoundTitle: String?
    let onResume: () -> Void
    let onDiscardAndStartNew: () -> Void
    let onDismiss: () -> Void

    private struct Palette {
        let background: Color
        let card: Color
        let secondaryCard: Color
        let border: Color
        let primaryText: Color
        let secondaryText: Color
        let tertiaryText: Color
        let accent: Color
        let accentForeground: Color

        static func forScheme(_ colorScheme: ColorScheme) -> Palette {
            switch colorScheme {
            case .dark:
                return .init(
                    background: Color(red: 0.05, green: 0.08, blue: 0.07),
                    card: Color(red: 0.12, green: 0.16, blue: 0.14),
                    secondaryCard: Color(red: 0.10, green: 0.13, blue: 0.12),
                    border: Color.white.opacity(0.14),
                    primaryText: Color.white.opacity(0.96),
                    secondaryText: Color.white.opacity(0.74),
                    tertiaryText: Color.white.opacity(0.56),
                    accent: ShellTokens.ColorRole.pine500,
                    accentForeground: .white
                )
            default:
                return .init(
                    background: ShellTokens.ColorRole.bgApp,
                    card: ShellTokens.ColorRole.surfaceOverlay,
                    secondaryCard: ShellTokens.ColorRole.surfaceSecondary,
                    border: ShellTokens.ColorRole.strokeDefault,
                    primaryText: ShellTokens.ColorRole.textPrimary,
                    secondaryText: ShellTokens.ColorRole.textSecondary,
                    tertiaryText: ShellTokens.ColorRole.textTertiary,
                    accent: ShellTokens.ColorRole.pine700,
                    accentForeground: ShellTokens.ColorRole.textInverse
                )
            }
        }
    }

    private var roundLabel: String {
        activeRoundTitle ?? "Current Round"
    }

    private var palette: Palette {
        Palette.forScheme(colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ROUND IN PROGRESS")
                            .font(ShellTokens.Typography.eyebrow)
                            .tracking(1.2)
                            .foregroundStyle(palette.accent)

                        Text("Pick up where you left off?")
                            .font(ShellTokens.Typography.sectionTitle)
                            .foregroundStyle(palette.primaryText)

                        Text("You already have \(roundLabel) in progress.")
                            .font(ShellTokens.Typography.body)
                            .foregroundStyle(palette.secondaryText)
                    }

                    roundStatusCard

                    VStack(spacing: 12) {
                        Button(action: onResume) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Resume Round")
                                        .font(.headline.weight(.semibold))
                                    Text("Continue where you left off")
                                        .font(ShellTokens.Typography.body)
                                        .foregroundStyle(palette.accentForeground.opacity(0.86))
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(palette.accentForeground)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(palette.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button(action: onDiscardAndStartNew) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Discard & Start New")
                                        .font(.headline.weight(.semibold))
                                    Text("Cancel the unfinished round and start a new one")
                                        .font(ShellTokens.Typography.body)
                                        .foregroundStyle(palette.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "trash")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(palette.primaryText)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(palette.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        Button("Not now", action: onDismiss)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(20)
                .padding(.top, 50)
                .padding(.bottom, 10)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(palette.background)
    }

    private var roundStatusCard: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.secondaryCard)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("In Progress")
                        .font(ShellTokens.Typography.microEyebrow)
                        .tracking(1.2)
                        .foregroundStyle(palette.tertiaryText)

                    Text(roundLabel)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.primaryText)

                    Text("Resume the saved live state, or clear it and begin a new round from setup.")
                        .font(ShellTokens.Typography.body)
                        .foregroundStyle(palette.secondaryText)
                }
                .padding(20)
            }
            .frame(height: 166)
    }
}
