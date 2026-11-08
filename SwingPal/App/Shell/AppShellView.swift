import SwiftUI

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
        TabView(selection: Binding(
            get: { appState.selectedTab },
            set: { tab in
                if tab == .round { handleRoundTabTapped() }
                else { appState.selectedTab = tab }
            }
        )) {
            Self.makeHomeView(
                appState: appState,
                onAuthGateRequired: { authGate = $0 },
                onOpenWatchCompanion: { isWatchCompanionPresented = true }
            )
            .tabItem { Label("Home", systemImage: "house") }
            .tag(AppTab.home)

            SocialView(appState: appState)
                .tabItem { Label("Social", systemImage: "person.2") }
                .tag(AppTab.social)

            RoundRootView(appState: appState, onAuthGateRequired: { authGate = $0 })
                .toolbar(showsTabBar ? .visible : .hidden, for: .tabBar)
                .tabItem { Label("Round", systemImage: "flag") }
                .tag(AppTab.round)

            StatsView(model: StatsViewModel(
                previousRounds: appState.previousRounds,
                analyses: UserDefaultsRoundSummaryAnalysisStore().load()
            ))
            .tabItem { Label("Stats", systemImage: "chart.xyaxis.line") }
            .tag(AppTab.stats)

            Self.makeProfileView(
                appState: appState,
                onAuthGateRequired: { authGate = $0 },
                onOpenWatchCompanion: { isWatchCompanionPresented = true }
            )
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(AppTab.profile)
        }
        .tint(CourseStyle.action)
        .background(CourseStyle.ground.ignoresSafeArea())
        .preferredColorScheme(appState.appearanceMode.preferredColorScheme)
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
                appState: appState
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
            },
            availableCourses: nearbyCourses,
            activeHoleNumber: appState.activeRoundState?.hole.number,
            confirmedHoleCount: appState.activeRoundState?.roundConfirmedHoleCount
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

/// The Watch companion: connection state first, then what it can do now.
private struct WatchCompanionLandingView: View {
    let model: WatchCompanionLandingModel
    let onOpenRound: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .center, spacing: 16) {
                        Image(systemName: "applewatch.side.right")
                            .font(.system(size: 44, weight: .light))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Watch").font(Book.Typeface.display)
                            HStack(spacing: 6) {
                                Circle().fill(model.canOpenLiveRound ? Book.stamp : Book.pencil).frame(width: 7, height: 7)
                                Text(model.connectionBadge).font(.subheadline.weight(.medium))
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    VStack(alignment: .leading, spacing: 0) {
                        BookHairline()
                        row("Status", model.setupTitle)
                        row("Changes", model.mutationSourceText)
                    }
                    Text(model.setupDetail)
                        .font(.body)
                        .foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("On your wrist: hole, distance, club, quick shot and hole finish. Changes are confirmed on iPhone.")
                        .font(.subheadline)
                        .foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: onOpenRound) {
                        HStack {
                            Text(model.primaryActionTitle)
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(BookStampButtonStyle())
                }
                .padding(22)
            }
            .background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .tint(Book.stamp)
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).foregroundStyle(Book.pencil)
                Spacer()
                Text(value).multilineTextAlignment(.trailing)
            }
            .font(.subheadline)
            .padding(.vertical, 12)
            BookHairline()
        }
        .accessibilityElement(children: .combine)
    }
}

/// A round is already open: the page you left, and two clear ways forward.
private struct RoundResumePromptView: View {
    let activeRoundTitle: String?
    let onResume: () -> Void
    let onDiscardAndStartNew: () -> Void
    let onDismiss: () -> Void
    @State private var isConfirmingDiscard = false

    private var roundLabel: String { activeRoundTitle ?? "Your round" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Circle().fill(Book.flag).frame(width: 7, height: 7)
                            BookNote("Round in progress", color: Book.ink)
                        }
                        Text(roundLabel)
                            .font(Book.Typeface.display)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Your card is saved where you left it. Pick it back up, or clear it and start a new round.")
                            .font(.body)
                            .foregroundStyle(Book.pencil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(spacing: 12) {
                        Button(action: onResume) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Resume round").font(.headline)
                                    Text("Back to the hole you were on").font(.subheadline).opacity(0.78)
                                }
                                Spacer()
                                Image(systemName: "play.fill")
                            }
                        }
                        .buttonStyle(BookStampButtonStyle())
                        Button { isConfirmingDiscard = true } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Discard and start new").font(.headline)
                                    Text("Clears the unfinished card").font(.subheadline).foregroundStyle(Book.pencil)
                                }
                                Spacer()
                                Image(systemName: "trash")
                            }
                        }
                        .buttonStyle(BookStampButtonStyle(prominent: false))
                        Button("Not now", action: onDismiss)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Book.pencil)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(22)
                .padding(.top, 20)
            }
            .background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Discard \(roundLabel)?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("Discard round", role: .destructive, action: onDiscardAndStartNew)
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("The unfinished card and its shots are removed.")
            }
        }
        .tint(Book.stamp)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Book.paper)
    }
}
