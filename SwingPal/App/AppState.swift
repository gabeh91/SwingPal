import Foundation
import Combine
import SwiftUI

enum AppGPSMode: String, Equatable, Codable {
    case live
    case testPreview
}

enum AppAppearanceMode: String, Equatable, Codable {
    case system
    case light
    case dark

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

protocol GPSModeStoring {
    func loadGPSMode() -> AppGPSMode
    func saveGPSMode(_ mode: AppGPSMode)
}

protocol AppearanceModeStoring {
    func loadAppearanceMode() -> AppAppearanceMode
    func saveAppearanceMode(_ mode: AppAppearanceMode)
}

/// Persists the user's preference for whether the club-selector wheel
/// should auto-recommend a club for the current shot. The setting is
/// app-level (not per-round) so that a player who turns it off once
/// keeps it off for every subsequent round.
protocol ClubAutoRecommendationPreferenceStoring {
    func loadClubAutoRecommendationEnabled() -> Bool
    func saveClubAutoRecommendationEnabled(_ isEnabled: Bool)
}

protocol DistanceUnitStoring {
    func loadDistanceUnit() -> DistanceUnit
    func saveDistanceUnit(_ unit: DistanceUnit)
}

struct UserDefaultsGPSModeStore: GPSModeStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "com.ghtech.swingpal.gps-mode"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadGPSMode() -> AppGPSMode {
        guard
            let rawValue = defaults.string(forKey: key),
            let mode = AppGPSMode(rawValue: rawValue)
        else {
            return .live
        }

        return mode
    }

    func saveGPSMode(_ mode: AppGPSMode) {
        defaults.set(mode.rawValue, forKey: key)
    }
}

struct UserDefaultsAppearanceModeStore: AppearanceModeStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "com.ghtech.swingpal.appearance-mode"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadAppearanceMode() -> AppAppearanceMode {
        guard
            let rawValue = defaults.string(forKey: key),
            let mode = AppAppearanceMode(rawValue: rawValue)
        else {
            return .system
        }

        return mode
    }

    func saveAppearanceMode(_ mode: AppAppearanceMode) {
        defaults.set(mode.rawValue, forKey: key)
    }
}

struct UserDefaultsClubAutoRecommendationPreferenceStore: ClubAutoRecommendationPreferenceStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "com.ghtech.swingpal.club-auto-recommendation-enabled"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadClubAutoRecommendationEnabled() -> Bool {
        // `bool(forKey:)` returns `false` when the key has never been set,
        // which would silently flip the user into manual mode the first
        // time they install the app. We want the default to be `true`, so
        // use `object(forKey:)` to detect the "not set yet" case explicitly.
        guard let value = defaults.object(forKey: key) as? Bool else {
            return true
        }
        return value
    }

    func saveClubAutoRecommendationEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: key)
    }
}

struct UserDefaultsDistanceUnitStore: DistanceUnitStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "com.ghtech.swingpal.distance-unit"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadDistanceUnit() -> DistanceUnit {
        guard
            let rawValue = defaults.string(forKey: key),
            let unit = DistanceUnit(rawValue: rawValue)
        else {
            return .meters
        }
        return unit
    }

    func saveDistanceUnit(_ unit: DistanceUnit) {
        defaults.set(unit.rawValue, forKey: key)
    }
}

enum RoundChromeMode: String, Equatable, Codable {
    case setup
    case live
}

struct RoundHistorySummary: Identifiable, Equatable, Hashable, Codable {
    enum Status: String, Equatable, Hashable, Codable {
        case unfinished
        case finished
    }

    let id: UUID
    let courseName: String
    let status: Status
    let holeNumber: Int
    let totalHoleCount: Int
    let playerCount: Int
    let totalStrokes: Int
    let completedHoleCount: Int
    let totalPutts: Int
    let totalPenalties: Int
    let updatedAt: Date

    init(
        id: UUID,
        courseName: String,
        status: Status,
        holeNumber: Int,
        totalHoleCount: Int,
        playerCount: Int,
        totalStrokes: Int = 0,
        completedHoleCount: Int = 0,
        totalPutts: Int = 0,
        totalPenalties: Int = 0,
        updatedAt: Date
    ) {
        self.id = id
        self.courseName = courseName
        self.status = status
        self.holeNumber = holeNumber
        self.totalHoleCount = totalHoleCount
        self.playerCount = playerCount
        self.totalStrokes = totalStrokes
        self.completedHoleCount = completedHoleCount
        self.totalPutts = totalPutts
        self.totalPenalties = totalPenalties
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        courseName = try container.decode(String.self, forKey: .courseName)
        status = try container.decode(Status.self, forKey: .status)
        holeNumber = try container.decode(Int.self, forKey: .holeNumber)
        totalHoleCount = try container.decode(Int.self, forKey: .totalHoleCount)
        playerCount = try container.decode(Int.self, forKey: .playerCount)
        totalStrokes = try container.decodeIfPresent(Int.self, forKey: .totalStrokes) ?? 0
        completedHoleCount = try container.decodeIfPresent(Int.self, forKey: .completedHoleCount) ?? 0
        totalPutts = try container.decodeIfPresent(Int.self, forKey: .totalPutts) ?? 0
        totalPenalties = try container.decodeIfPresent(Int.self, forKey: .totalPenalties) ?? 0
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

struct ActiveRoundSnapshot: Equatable, Codable {
    let id: UUID
    let chromeMode: RoundChromeMode
    let liveRound: LiveRoundState.Snapshot
}

enum RoundEntryRoute: Equatable {
    case nearbyCourses
    case courseDetail(UUID)
}

protocol ActiveRoundStoring {
    func loadActiveRound() -> ActiveRoundSnapshot?
    func saveActiveRound(_ snapshot: ActiveRoundSnapshot?)
}

protocol RoundHistoryStoring {
    func loadRoundHistory() -> [RoundHistorySummary]
    func saveRoundHistory(_ summaries: [RoundHistorySummary])
}

protocol BagStoring {
    func loadBag() -> Bag
    func saveBag(_ bag: Bag)
}

protocol HandicapIndexStoring {
    func loadHandicapSnapshot() -> HandicapIndexSnapshot
    func saveHandicapSnapshot(_ snapshot: HandicapIndexSnapshot)
}

struct UserDefaultsHandicapIndexStore: HandicapIndexStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "com.ghtech.swingpal.handicap-index"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadHandicapSnapshot() -> HandicapIndexSnapshot {
        guard let data = defaults.data(forKey: key) else {
            return HandicapIndexSnapshot()
        }
        return (try? JSONDecoder().decode(HandicapIndexSnapshot.self, from: data)) ?? HandicapIndexSnapshot()
    }

    func saveHandicapSnapshot(_ snapshot: HandicapIndexSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}

struct UserDefaultsActiveRoundStore: ActiveRoundStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "com.ghtech.swingpal.active-round"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadActiveRound() -> ActiveRoundSnapshot? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(ActiveRoundSnapshot.self, from: data)
    }

    func saveActiveRound(_ snapshot: ActiveRoundSnapshot?) {
        guard let snapshot else {
            defaults.removeObject(forKey: key)
            return
        }

        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

struct UserDefaultsRoundHistoryStore: RoundHistoryStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "com.ghtech.swingpal.round-history"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadRoundHistory() -> [RoundHistorySummary] {
        guard let data = defaults.data(forKey: key) else {
            return []
        }

        return (try? JSONDecoder().decode([RoundHistorySummary].self, from: data)) ?? []
    }

    func saveRoundHistory(_ summaries: [RoundHistorySummary]) {
        guard let data = try? JSONEncoder().encode(summaries) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}

struct UserDefaultsBagStore: BagStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "com.ghtech.swingpal.bag"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadBag() -> Bag {
        guard let data = defaults.data(forKey: key) else {
            return .starter
        }

        return (try? JSONDecoder().decode(Bag.self, from: data)) ?? .starter
    }

    func saveBag(_ bag: Bag) {
        guard let data = try? JSONEncoder().encode(bag) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var authState: AuthState = .guest
    @Published var currentUser: AuthSessionUser?
    @Published var entitlements: EntitlementState = .free
    @Published var activeRoundID: UUID?
    @Published var activeRoundState: LiveRoundState?
    @Published var roundChromeMode: RoundChromeMode = .setup
    @Published var pendingRoundEntryRoute: RoundEntryRoute?
    @Published private(set) var previousRounds: [RoundHistorySummary]
    @Published private(set) var bag: Bag
    @Published private(set) var handicapSnapshot: HandicapIndexSnapshot
    @Published var gpsMode: AppGPSMode
    @Published var appearanceMode: AppAppearanceMode
    @Published var clubAutoRecommendationEnabled: Bool
    @Published var distanceUnit: DistanceUnit

    private let store: ActiveRoundStoring
    private let roundHistoryStore: RoundHistoryStoring
    private let bagStore: BagStoring
    private let handicapStore: HandicapIndexStoring
    private let gpsModeStore: GPSModeStoring
    private let appearanceModeStore: AppearanceModeStoring
    private let clubAutoRecommendationPreferenceStore: ClubAutoRecommendationPreferenceStoring
    private let distanceUnitStore: DistanceUnitStoring
    private let roundCompanionSync: RoundCompanionSyncing
    private let weatherLoaderFactory: () -> RoundWeatherLoading
    private let locationProviderFactory: () -> RoundLocationProviding
    private let now: () -> Date
    private(set) var authService: AuthService?
    private var authSubscription: AnyCancellable?

    var isImmersiveRoundActive: Bool {
        selectedTab == .round && activeRoundState != nil && roundChromeMode == .live
    }

    init(
        store: ActiveRoundStoring = UserDefaultsActiveRoundStore(),
        roundHistoryStore: RoundHistoryStoring = UserDefaultsRoundHistoryStore(),
        bagStore: BagStoring = UserDefaultsBagStore(),
        handicapStore: HandicapIndexStoring = UserDefaultsHandicapIndexStore(),
        gpsModeStore: GPSModeStoring = UserDefaultsGPSModeStore(),
        appearanceModeStore: AppearanceModeStoring = UserDefaultsAppearanceModeStore(),
        clubAutoRecommendationPreferenceStore: ClubAutoRecommendationPreferenceStoring = UserDefaultsClubAutoRecommendationPreferenceStore(),
        distanceUnitStore: DistanceUnitStoring = UserDefaultsDistanceUnitStore(),
        roundCompanionSync: RoundCompanionSyncing = WatchConnectivityRoundCompanionSync(),
        weatherLoaderFactory: @escaping () -> RoundWeatherLoading = { AppleWeatherKitLoader() },
        locationProviderFactory: @escaping () -> RoundLocationProviding = { CoreLocationRoundLocationProvider() },
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.roundHistoryStore = roundHistoryStore
        self.bagStore = bagStore
        self.handicapStore = handicapStore
        self.gpsModeStore = gpsModeStore
        self.appearanceModeStore = appearanceModeStore
        self.clubAutoRecommendationPreferenceStore = clubAutoRecommendationPreferenceStore
        self.distanceUnitStore = distanceUnitStore
        self.roundCompanionSync = roundCompanionSync
        self.weatherLoaderFactory = weatherLoaderFactory
        self.locationProviderFactory = locationProviderFactory
        self.now = now
        self.bag = bagStore.loadBag()
        self.handicapSnapshot = handicapStore.loadHandicapSnapshot()
        self.gpsMode = gpsModeStore.loadGPSMode()
        self.appearanceMode = appearanceModeStore.loadAppearanceMode()
        self.clubAutoRecommendationEnabled = clubAutoRecommendationPreferenceStore.loadClubAutoRecommendationEnabled()
        self.distanceUnit = distanceUnitStore.loadDistanceUnit()
        self.previousRounds = roundHistoryStore.loadRoundHistory()
            .sorted(by: { $0.updatedAt > $1.updatedAt })

        // Wire up companion-action callbacks AFTER all stored properties are
        // initialized - the closure captures `self` and Swift requires full
        // self-init before any capture.
        if let actionReceiver = roundCompanionSync as? RoundCompanionActionReceiving {
            actionReceiver.setIncomingActionHandler { [weak self] action in
                self?.handleRoundCompanionAction(action)
            }
        }

        if let snapshot = store.loadActiveRound() {
            let liveRound = makeLiveRound(from: snapshot.liveRound)
            liveRound.setDistanceUnit(distanceUnit)
            bindActiveRound(liveRound)
            activeRoundID = snapshot.id
            activeRoundState = liveRound
            roundChromeMode = snapshot.chromeMode
        }
    }

    // Backwards-compatible initializer retained for test targets / older call sites.
    convenience init(
        store: ActiveRoundStoring,
        roundHistoryStore: RoundHistoryStoring = UserDefaultsRoundHistoryStore(),
        bagStore: BagStoring = UserDefaultsBagStore(),
        handicapStore: HandicapIndexStoring = UserDefaultsHandicapIndexStore(),
        gpsModeStore: GPSModeStoring = UserDefaultsGPSModeStore(),
        appearanceModeStore: AppearanceModeStoring = UserDefaultsAppearanceModeStore(),
        clubAutoRecommendationPreferenceStore: ClubAutoRecommendationPreferenceStoring = UserDefaultsClubAutoRecommendationPreferenceStore(),
        roundCompanionSync: RoundCompanionSyncing = WatchConnectivityRoundCompanionSync(),
        weatherLoaderFactory: @escaping () -> RoundWeatherLoading = { AppleWeatherKitLoader() },
        locationProviderFactory: @escaping () -> RoundLocationProviding = { CoreLocationRoundLocationProvider() },
        now: @escaping () -> Date = Date.init
    ) {
        self.init(
            store: store,
            roundHistoryStore: roundHistoryStore,
            bagStore: bagStore,
            handicapStore: handicapStore,
            gpsModeStore: gpsModeStore,
            appearanceModeStore: appearanceModeStore,
            clubAutoRecommendationPreferenceStore: clubAutoRecommendationPreferenceStore,
            distanceUnitStore: UserDefaultsDistanceUnitStore(),
            roundCompanionSync: roundCompanionSync,
            weatherLoaderFactory: weatherLoaderFactory,
            locationProviderFactory: locationProviderFactory,
            now: now
        )
    }

    func resumeRound(id: UUID, state: LiveRoundState, chromeMode: RoundChromeMode) {
        state.setClubAutoRecommendationEnabled(clubAutoRecommendationEnabled)
        state.setDistanceUnit(distanceUnit)
        bindActiveRound(state)
        activeRoundID = id
        activeRoundState = state
        roundChromeMode = chromeMode
        persistActiveRound()
    }

    func clearActiveRound() {
        activeRoundState?.onRoundUpdated = nil
        roundCompanionSync.clear()
        activeRoundID = nil
        activeRoundState = nil
        roundChromeMode = .setup
        persistActiveRound()
    }

    func suspendActiveRound() {
        guard let activeRoundID, let activeRoundState else { return }
        roundChromeMode = .setup
        upsertRoundHistorySummary(
            makeRoundHistorySummary(
                id: activeRoundID,
                state: activeRoundState,
                status: .unfinished
            )
        )
        persistActiveRound()
    }

    func completeActiveRound() {
        guard let activeRoundID, let activeRoundState else { return }
        upsertRoundHistorySummary(
            makeRoundHistorySummary(
                id: activeRoundID,
                state: activeRoundState,
                status: .finished
            )
        )
        clearActiveRound()
    }

    func discardActiveRound() {
        guard let activeRoundID else {
            clearActiveRound()
            return
        }

        previousRounds.removeAll(where: { $0.id == activeRoundID })
        persistRoundHistory()
        clearActiveRound()
    }

    func makeRoundLocationProvider() -> RoundLocationProviding {
        switch gpsMode {
        case .live:
            return locationProviderFactory()
        case .testPreview:
            return PreviewRoundLocationProvider()
        }
    }

    func setGPSMode(_ mode: AppGPSMode) {
        guard gpsMode != mode else { return }

        gpsMode = mode
        gpsModeStore.saveGPSMode(mode)

        guard let activeRoundID, let snapshot = activeRoundState?.snapshot else {
            return
        }

        activeRoundState?.onRoundUpdated = nil
        let rebuiltRound = makeLiveRound(from: snapshot)
        bindActiveRound(rebuiltRound)
        activeRoundState = rebuiltRound
        self.activeRoundID = activeRoundID
        persistActiveRound()
    }

    func setAppearanceMode(_ mode: AppAppearanceMode) {
        guard appearanceMode != mode else { return }
        appearanceMode = mode
        appearanceModeStore.saveAppearanceMode(mode)
    }

    func completeSignIn() {
        guard authState != .authenticated else { return }
        authState = .authenticated
    }

    /// Wire `AppState` to a concrete `AuthService` (typically constructed
    /// at app launch). Subscribes to its session publisher so that
    /// `authState` + `currentUser` track the real session, and triggers a
    /// one-shot `bootstrap()` to restore any persisted token.
    func attachAuthService(_ service: AuthService) {
        authService = service
        authSubscription = service.sessionUserPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self else { return }
                self.currentUser = user
                self.authState = (user == nil) ? .guest : .authenticated
            }
        Task { [weak self] in
            await service.bootstrap()
            guard let self else { return }
            let user = service.currentSessionUser
            self.currentUser = user
            self.authState = (user == nil) ? .guest : .authenticated
        }
    }

    func signOut() async {
        guard let authService else {
            authState = .guest
            currentUser = nil
            return
        }
        do {
            try await authService.signOut()
        } catch {
            // Network failures during sign-out shouldn't strand the user
            // in the app; flip local state regardless.
            authState = .guest
            currentUser = nil
        }
    }

    func addClubs(_ clubs: [Club]) {
        guard !clubs.isEmpty else { return }
        bag = Bag(clubs: bag.clubs + clubs)
        bagStore.saveBag(bag)
        refreshActiveRoundClubContext()
    }

    func updateClub(_ updatedClub: Club) {
        guard let existingIndex = bag.clubs.firstIndex(where: { $0.id == updatedClub.id }) else {
            return
        }

        var clubs = bag.clubs
        clubs[existingIndex] = updatedClub
        bag = Bag(clubs: clubs)
        bagStore.saveBag(bag)
        refreshActiveRoundClubContext()
    }

    func deleteClub(id: UUID) {
        let filteredClubs = bag.clubs.filter { $0.id != id }
        guard filteredClubs.count != bag.clubs.count else { return }
        bag = Bag(clubs: filteredClubs)
        bagStore.saveBag(bag)
        refreshActiveRoundClubContext()
    }

    func setManualHandicapIndex(_ index: Double?) {
        handicapSnapshot.manualIndex = index
        handicapStore.saveHandicapSnapshot(handicapSnapshot)
    }

    var handicapIndexEstimate: Double? {
        HandicapIndexEstimator.estimateIndex(from: previousRounds)
    }

    var handicapBadgeText: String {
        if let manual = handicapSnapshot.manualIndex {
            return "HI \(manual.formatted(.number.precision(.fractionLength(1))))"
        }
        if let estimate = handicapIndexEstimate {
            return "Est HI \(estimate.formatted(.number.precision(.fractionLength(1))))"
        }
        return "Set handicap"
    }

    func handleRoundCompanionAction(_ action: RoundCompanionAction) {
        activeRoundState?.applyCompanionAction(action, source: .watch)
    }

    func openNearbyCourses() {
        pendingRoundEntryRoute = .nearbyCourses
        selectedTab = .round
    }

    func openNearbyCourseDetail(courseID: UUID) {
        pendingRoundEntryRoute = .courseDetail(courseID)
        selectedTab = .round
    }

    func consumePendingRoundEntryRoute() -> RoundEntryRoute? {
        let route = pendingRoundEntryRoute
        pendingRoundEntryRoute = nil
        return route
    }

    /// Persist a new club-wheel auto-recommendation preference and propagate
    /// it to any active round. Idempotent — callable from inside the wheel
    /// (which calls in via `LiveRoundState.onClubAutoRecommendationPreferenceChanged`)
    /// or from a future settings UI without needing to deduplicate.
    func setClubAutoRecommendationEnabled(_ isEnabled: Bool) {
        if clubAutoRecommendationEnabled != isEnabled {
            clubAutoRecommendationEnabled = isEnabled
            clubAutoRecommendationPreferenceStore.saveClubAutoRecommendationEnabled(isEnabled)
        }
        activeRoundState?.setClubAutoRecommendationEnabled(isEnabled)
    }

    func setDistanceUnit(_ unit: DistanceUnit) {
        guard distanceUnit != unit else { return }
        distanceUnit = unit
        distanceUnitStore.saveDistanceUnit(unit)
        activeRoundState?.setDistanceUnit(unit)
    }

    private func bindActiveRound(_ liveRound: LiveRoundState) {
        liveRound.attachRoundCompanionSync(roundCompanionSync)
        liveRound.setDistanceUnit(distanceUnit)
        liveRound.onRoundUpdated = { [weak self] in
            self?.persistActiveRound()
        }
        // The wheel exposes a toggle that mutates `LiveRoundState` directly;
        // we mirror that change up to the persistent preference here so
        // closing the wheel (or even the app) preserves the choice for the
        // next round.
        liveRound.onClubAutoRecommendationPreferenceChanged = { [weak self] isEnabled in
            guard let self else { return }
            guard self.clubAutoRecommendationEnabled != isEnabled else { return }
            self.clubAutoRecommendationEnabled = isEnabled
            self.clubAutoRecommendationPreferenceStore.saveClubAutoRecommendationEnabled(isEnabled)
        }
    }

    private func makeLiveRound(from snapshot: LiveRoundState.Snapshot) -> LiveRoundState {
        LiveRoundState(
            snapshot: snapshot,
            clubCarryMetersByClubName: liveRoundClubCarryMetersByClubName,
            clubAutoRecommendationEnabled: clubAutoRecommendationEnabled,
            roundCompanionSync: NoOpRoundCompanionSync(),
            weatherLoader: weatherLoaderFactory(),
            locationProvider: makeRoundLocationProvider()
        )
    }

    var liveRoundClubCarryMetersByClubName: [String: Int] {
        bag.clubs.reduce(into: [String: Int]()) { partialResult, club in
            partialResult[club.name] = club.typicalDistanceMeters
        }
    }

    private func persistActiveRound() {
        guard let activeRoundID, let activeRoundState else {
            store.saveActiveRound(nil)
            return
        }

        store.saveActiveRound(
            .init(
                id: activeRoundID,
                chromeMode: roundChromeMode,
                liveRound: activeRoundState.snapshot
            )
        )
    }

    private func refreshActiveRoundClubContext() {
        guard let activeRoundID, let snapshot = activeRoundState?.snapshot else {
            return
        }

        activeRoundState?.onRoundUpdated = nil
        let rebuiltRound = makeLiveRound(from: snapshot)
        bindActiveRound(rebuiltRound)
        activeRoundState = rebuiltRound
        self.activeRoundID = activeRoundID
        persistActiveRound()
    }

    private func makeRoundHistorySummary(
        id: UUID,
        state: LiveRoundState,
        status: RoundHistorySummary.Status
    ) -> RoundHistorySummary {
        let snapshot = state.snapshot
        let totalHoleCount = max(snapshot.courseHoles.count, snapshot.holeSessions.count, 1)
        let totalStrokes = snapshot.holeSessions.reduce(0) { partialResult, hole in
            partialResult + hole.strokeCount
        }
        let completedHoleCount = status == .finished
            ? totalHoleCount
            : snapshot.holeSessions.filter(\.isConfirmed).count
        let totalPutts = snapshot.holeSessions.reduce(0) { partialResult, hole in
            partialResult + resolvedPutts(for: hole)
        }
        let totalPenalties = snapshot.holeSessions.reduce(0) { partialResult, hole in
            partialResult + resolvedPenalties(for: hole)
        }

        return .init(
            id: id,
            courseName: snapshot.courseName,
            status: status,
            holeNumber: status == .finished ? totalHoleCount : min(max(snapshot.hole.number, 1), totalHoleCount),
            totalHoleCount: totalHoleCount,
            playerCount: snapshot.players.count,
            totalStrokes: totalStrokes,
            completedHoleCount: completedHoleCount,
            totalPutts: totalPutts,
            totalPenalties: totalPenalties,
            updatedAt: now()
        )
    }

    private func resolvedPutts(for hole: HoleSession) -> Int {
        if let recordedPutts = hole.recordedPutts {
            return max(0, recordedPutts)
        }

        if let explicitPuttCount = hole.shots.compactMap(\.puttDetail?.puttCount).last {
            return max(0, explicitPuttCount)
        }

        return hole.shots.reduce(0) { partialResult, shot in
            partialResult + ((shot.surface == .green || shot.shotType == .putt) ? 1 : 0)
        }
    }

    private func resolvedPenalties(for hole: HoleSession) -> Int {
        if let recordedPenaltyCount = hole.recordedPenaltyCount {
            return max(0, recordedPenaltyCount)
        }

        return hole.shots.reduce(0) { partialResult, shot in
            partialResult + shot.penaltyCount
        }
    }

    private func upsertRoundHistorySummary(_ summary: RoundHistorySummary) {
        if let existingIndex = previousRounds.firstIndex(where: { $0.id == summary.id }) {
            previousRounds[existingIndex] = summary
        } else {
            previousRounds.append(summary)
        }

        previousRounds.sort(by: { $0.updatedAt > $1.updatedAt })
        persistRoundHistory()
    }

    private func persistRoundHistory() {
        roundHistoryStore.saveRoundHistory(previousRounds)
    }
}
