import SwiftUI
import Supabase

@main
struct SwingPalApp: App {
    @StateObject private var appState: AppState
    @State private var showsLaunchSplash: Bool
    private let authService: AuthService

    init() {
        let service: AuthService
        #if DEBUG
        if DesignReviewScenario.current != nil {
            service = MissingConfigurationAuthService()
        } else {
            service = SwingPalAuthServiceFactory.make()
        }
        #else
        service = SwingPalAuthServiceFactory.make()
        #endif
        let state: AppState
        #if DEBUG
        if DesignReviewScenario.current != nil {
            // Never restore a real round (and start its location service) behind a fixture.
            state = AppState(store: DesignReviewActiveRoundStore())
        } else {
            state = AppState()
        }
        #else
        state = AppState()
        #endif
        state.attachAuthService(service)
        _appState = StateObject(wrappedValue: state)
        authService = service
        var splash = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        #if DEBUG
        if DesignReviewScenario.current != nil { splash = false }
        #endif
        _showsLaunchSplash = State(initialValue: splash)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                rootContent
                if showsLaunchSplash {
                    // Continues LaunchScreen.storyboard, then lifts away on its own.
                    LaunchSplashView { showsLaunchSplash = false }
                        .zIndex(1)
                }
            }
            .preferredColorScheme(reviewColorScheme ?? appState.appearanceMode.preferredColorScheme)
            .task {
                #if DEBUG
                guard DesignReviewScenario.current == nil,
                      ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
                #endif
                await ClubCatalogStore.shared.refreshIfNeeded()
            }
            .onOpenURL { url in
                if let userId = FollowDeepLink.userId(from: url) {
                    appState.presentFollowInvite(userId: userId, displayName: nil)
                    return
                }
                Task { await authService.handleAuthCallback(url: url) }
            }
        }
    }

    /// Review fixtures ending in `-night` render the night book regardless of the saved appearance.
    private var reviewColorScheme: ColorScheme? {
        #if DEBUG
        if DesignReviewScenario.current?.hasSuffix("-night") == true { return .dark }
        #endif
        return nil
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if DesignReviewScenario.current == "splash" {
            DesignReviewSplash()
        } else if DesignReviewScenario.current == "brand" {
            DesignReviewBrandSheet()
        } else if let scenario = DesignReviewScenario.current {
            NativeDesignReview(scenario: scenario.replacingOccurrences(of: "-night", with: ""))
        } else {
            AppShellView(appState: appState, authService: authService)
        }
        #else
        AppShellView(appState: appState, authService: authService)
        #endif
    }

}

/// Resolves which `AuthService` to use at launch. If `SUPABASE_URL` /
/// `SUPABASE_ANON_KEY` are present we use the real `SupabaseAuthService`;
/// otherwise sign-in reports that configuration is unavailable.
enum SwingPalAuthServiceFactory {
    @MainActor
    static func make() -> AuthService {
        switch AppAuthServiceMode.resolve(hasSupabaseConfig: SupabaseConfig.loadFromEnvironment() != nil) {
        case .missingConfiguration:
            SupabaseShared.setClient(nil)
            return MissingConfigurationAuthService()
        case .supabase:
            break
        }
        guard let config = SupabaseConfig.loadFromEnvironment() else {
            SupabaseShared.setClient(nil)
            return MissingConfigurationAuthService()
        }
        let options = SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(redirectToURL: config.redirectURL)
        )
        let client = SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.anonKey,
            options: options
        )
        SupabaseShared.setClient(client)
        return SupabaseAuthService(client: client)
    }
}


#if DEBUG
/// Opt-in review fixtures: launch with SWINGPAL_DESIGN_REVIEW=home|live|live-unavailable|live-played|live-logger|review|complete|stats|setup|bag|splash|brand.
/// Append `-night` (e.g. `live-night`) to render the night book.
enum DesignReviewScenario {
    static var current: String? { ProcessInfo.processInfo.environment["SWINGPAL_DESIGN_REVIEW"] ?? override }
    /// Local review convenience only; keep nil in commits.
    static let override: String? = nil
}

/// Explicit opt-in native review fixtures. Preview providers and no-op callbacks keep
/// sample records out of persistence, authentication, companion sync and social feeds.
private struct NativeDesignReview: View {
    let scenario: String
    @StateObject private var round: LiveRoundState
    @StateObject private var setup: RoundSetupState
    @State private var showsPlayingReview = false

    init(scenario: String) {
        self.scenario = scenario
        let course = SeededCourseRepository().nearbyCourses().first!
        let tee = course.holes.first?.features.first(where: { $0.kind == .tee })?.coordinates.first
        let location = DesignReviewLocationProvider(coordinate: scenario == "live-unavailable" ? nil : tee ?? course.coordinate)
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: course.holes.first?.par ?? 4),
            courseName: course.name,
            courseCoordinate: .init(latitude: course.coordinate.latitude, longitude: course.coordinate.longitude),
            courseHoles: course.holes,
            selectedTeeName: course.tees.first?.name,
            players: [.init(name: "You", kind: .selfPlayer), .init(name: "Alex", kind: .guest)],
            clubCarryMetersByClubName: ["Driver": 220, "7 Iron": 140, "Pitching Wedge": 95, "Putter": 10],
            locationProvider: location
        )
        if scenario == "review" || scenario == "complete" {
            let count = scenario == "complete" ? course.holes.count : 3
            let offsets = [0, 1, -1, 0, 2, 0, 1, 0, -1, 0, 1, 1, 0, -2, 0, 1, 0, 2]
            for index in 0..<count {
                state.presentHoleConfirmation()
                let par = course.holes.indices.contains(index) ? course.holes[index].par : 4
                state.setPendingHoleScore(max(1, par + offsets[index % offsets.count]))
                state.setPendingHolePutts(offsets[index % offsets.count] < 0 ? 1 : 2)
                _ = state.confirmCurrentHole()
            }
        }
        if scenario == "live-played" || scenario == "live-logger" {
            // Three holes on the card and a tee shot logged on the fourth.
            let offsets = [0, 1, -1]
            for index in 0..<3 {
                state.presentHoleConfirmation()
                let par = course.holes.indices.contains(index) ? course.holes[index].par : 4
                state.setPendingHoleScore(max(1, par + offsets[index]))
                state.setPendingHolePutts(offsets[index] < 0 ? 1 : 2)
                _ = state.confirmCurrentHole()
            }
            state.logShot(clubName: "Driver", distanceToTargetMeters: 350, surface: .tee)
            if scenario == "live-logger" { state.presentShotLogger() }
        }
        if scenario == "live-clubs" {
            state.setClubAutoRecommendationEnabled(false)
            state.selectClubFromWheel(named: "PW")
            state.presentClubWheel()
        }
        if scenario == "live-marked" {
            state.logShot(clubName: "Driver", distanceToTargetMeters: 388, surface: .tee)
            state.markBall()
        }
        _round = StateObject(wrappedValue: state)
        let setupState = RoundSetupState(repository: SeededCourseRepository())
        if scenario == "setup-selected" {
            setupState.selectCourse(course)
            if let tee = course.tees.first { setupState.selectTee(tee) }
        }
        _setup = StateObject(wrappedValue: setupState)
    }

    private var sampleHistory: [RoundHistorySummary] {
        [
            .init(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, courseName: "Medway Golf Club", status: .finished, holeNumber: 18, totalHoleCount: 18, playerCount: 1, totalStrokes: 84, completedHoleCount: 18, totalPutts: 32, totalPenalties: 2, updatedAt: Date(timeIntervalSince1970: 1789858800)),
            .init(id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!, courseName: "Royal Melbourne", status: .finished, holeNumber: 18, totalHoleCount: 18, playerCount: 1, totalStrokes: 89, completedHoleCount: 18, totalPutts: 35, totalPenalties: 3, updatedAt: Date(timeIntervalSince1970: 1789254000)),
            .init(id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!, courseName: "Medway Golf Club", status: .finished, holeNumber: 18, totalHoleCount: 18, playerCount: 2, totalStrokes: 87, completedHoleCount: 18, totalPutts: 34, totalPenalties: 2, updatedAt: Date(timeIntervalSince1970: 1788649200)),
            .init(id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!, courseName: "Medway Golf Club", status: .unfinished, holeNumber: 11, totalHoleCount: 18, playerCount: 1, totalStrokes: 47, completedHoleCount: 10, totalPutts: 18, totalPenalties: 1, updatedAt: Date(timeIntervalSince1970: 1788303600)),
            .init(id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!, courseName: "Royal Melbourne", status: .finished, holeNumber: 18, totalHoleCount: 18, playerCount: 1, totalStrokes: 91, completedHoleCount: 18, totalPutts: 36, totalPenalties: 4, updatedAt: Date(timeIntervalSince1970: 1787785200)),
            .init(id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!, courseName: "Medway Golf Club", status: .finished, holeNumber: 18, totalHoleCount: 18, playerCount: 1, totalStrokes: 86, completedHoleCount: 18, totalPutts: 33, totalPenalties: 2, updatedAt: Date(timeIntervalSince1970: 1787180400))
        ]
    }

    var body: some View {
        Group {
            switch scenario {
            case "review", "complete":
                NavigationStack {
                    RoundReviewView(state: round, onInspectHole: { round.inspectHole(at: $0) }, onDone: {})
                }
            case "live", "live-unavailable", "live-clubs", "live-marked", "live-played", "live-logger":
                FreshLiveRoundScreen(state: round, onFinishHole: { showsPlayingReview = true }, onSaveAndExitRound: {}, onDiscardRound: {}, onReviewRound: { showsPlayingReview = true })
                    .sheet(isPresented: $showsPlayingReview) {
                        NavigationStack {
                            RoundReviewView(state: round, onInspectHole: { number in
                                round.inspectHole(at: number)
                                showsPlayingReview = false
                            }, onDone: { showsPlayingReview = false })
                        }
                    }
            case "setup", "setup-selected":
                NavigationStack {
                    RoundSetupView(state: setup, onStartRound: {}, onExitSetup: {})
                }
            case "bag", "bag-yards":
                AddClubReviewFixture(distanceUnit: scenario == "bag-yards" ? .yards : .meters)
            case "stats":
                StatsView(model: StatsViewModel(previousRounds: sampleHistory, analyses: []))
            default:
                HomeView(model: HomeViewModel(activeRoundTitle: "Medway Golf Club", previousRounds: sampleHistory, analyses: [], nearbyCourses: SeededCourseRepository().nearbyCourses(), handicapBadgeText: "Not set", distanceUnit: .meters), entitlements: .free, onOpenRound: {}, onOpenNearbyCourse: { _ in }, onOpenNearbyCourses: {}, onOpenWatchCompanion: {}, availableCourses: SeededCourseRepository().nearbyCourses(), activeHoleNumber: 4, confirmedHoleCount: 3)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text("Design review · sample data")
                .font(.caption).dynamicTypeSize(.small ... .large).foregroundStyle(CourseStyle.muted)
                .frame(maxWidth: .infinity).padding(5).background(CourseStyle.ground)
        }
    }
}
/// The launch splash slowed six-fold; tap to replay.
private struct DesignReviewSplash: View {
    @State private var take = 0

    var body: some View {
        ZStack {
            Book.paper.ignoresSafeArea()
            LaunchSplashView(pace: 6).id(take)
        }
        .contentShape(Rectangle())
        .onTapGesture { take += 1 }
    }
}

/// The mark at Home Screen, Settings and Spotlight sizes, and on the day and night page.
private struct DesignReviewBrandSheet: View {
    var body: some View {
        VStack(spacing: 0) {
            panel.environment(\.colorScheme, .light)
            panel.environment(\.colorScheme, .dark)
        }
        .ignoresSafeArea()
    }

    private var panel: some View {
        VStack(spacing: 18) {
            HStack(alignment: .bottom, spacing: 14) {
                SwingPalMarkTile(size: 76)
                SwingPalMarkTile(size: 60)
                SwingPalMarkTile(size: 40)
                SwingPalMarkTile(size: 29)
            }
            HStack(spacing: 18) {
                SwingPalMark(colorway: .page).frame(width: 150)
                VStack(alignment: .leading, spacing: 6) {
                    Text("SwingPal").font(Book.Typeface.display).foregroundStyle(Book.ink)
                    BookNote("Your yardage book")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Book.paper)
    }
}

private struct DesignReviewActiveRoundStore: ActiveRoundStoring {
    func loadActiveRound() -> ActiveRoundSnapshot? { nil }
    func saveActiveRound(_ snapshot: ActiveRoundSnapshot?) {}
}

private final class DesignReviewLocationProvider: RoundLocationProviding {
    let currentSnapshot: RoundLocationSnapshot?
    var currentStatus: RoundLocationStatus { currentSnapshot == nil ? .permissionDenied : .ready }
    init(coordinate: SwingPalCourse.Coordinate?) {
        currentSnapshot = coordinate.map {
            RoundLocationSnapshot(coordinate: .init(latitude: $0.latitude, longitude: $0.longitude), headingDegrees: 0, horizontalAccuracyMeters: 8)
        }
    }
    func setUpdateHandler(_ handler: @escaping (RoundLocationSnapshot) -> Void) {}
    func setStatusHandler(_ handler: @escaping (RoundLocationStatus) -> Void) {}
    func startUpdating() {}
    func stopUpdating() {}
}
#endif
