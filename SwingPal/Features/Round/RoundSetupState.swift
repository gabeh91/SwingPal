import Foundation
import Combine
import CoreLocation

@MainActor
final class RoundSetupState: ObservableObject {
    @Published var courses: [SwingPalCourse]
    @Published var selectedCourse: SwingPalCourse?
    @Published var selectedTeeName: String?
    @Published var selectedTeeYards: Int?
    @Published var players: [RoundPlayerDraft] = [
        .init(name: "You", kind: .selfPlayer)
    ]

    // MARK: - Discovery state (Phase 1)

    @Published private(set) var userLocation: CLLocationCoordinate2D?
    @Published private(set) var userCountryCode: String?
    @Published private(set) var nearbyDiscoveries: [DiscoveredCourse] = []
    @Published var searchQuery: String = ""
    @Published private(set) var searchResults: [DiscoveredCourse] = []
    @Published private(set) var isLoadingNearby: Bool = false
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var discoveryStatusMessage: String?

    // MARK: - Import state (Phase 2)

    @Published private(set) var currentImportStage: CourseImportStage?
    @Published private(set) var lastImportValidation: CourseValidationResult?
    @Published private(set) var lastImportedCourse: SwingPalCourse?
    @Published private(set) var pendingImportDiscovery: DiscoveredCourse?

    private let repository: CourseRepository
    private let discovery: any OSMCourseDiscovering
    private let deviceLocation: any DeviceLocationProviding
    private let countryCodeGeocoder: any CountryCodeGeocoding
    private let importCoordinator: CourseImportCoordinator
    private let importedStore: ImportedCourseStore
    private let nearbyRadiusKilometres: Double

    private var pendingSearchTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?
    private var didLoadNearbyOnce = false

    init(
        repository: CourseRepository,
        discovery: any OSMCourseDiscovering = LiveOSMCourseDiscovery(),
        deviceLocation: (any DeviceLocationProviding)? = nil,
        countryCodeGeocoder: any CountryCodeGeocoding = AppleCountryCodeGeocoder(),
        importCoordinator: CourseImportCoordinator = CourseImportCoordinator(),
        importedStore: ImportedCourseStore = ImportedCourseStore(),
        nearbyRadiusKilometres: Double = 10
    ) {
        self.repository = repository
        self.discovery = discovery
        self.deviceLocation = deviceLocation ?? DeviceLocationProvider()
        self.countryCodeGeocoder = countryCodeGeocoder
        self.importCoordinator = importCoordinator
        self.importedStore = importedStore
        self.nearbyRadiusKilometres = nearbyRadiusKilometres
        courses = repository.nearbyCourses()
    }

    var sortedCourses: [SwingPalCourse] {
        courses.sorted { $0.distanceKilometers < $1.distanceKilometers }
    }

    var availableTees: [SwingPalCourse.Tee] {
        selectedCourse?.tees ?? []
    }

    var selectedTee: SwingPalCourse.Tee? {
        guard let selectedTeeName else { return nil }
        return availableTees.first(where: { $0.name == selectedTeeName })
    }

    var canStartRound: Bool {
        selectedCourse != nil && selectedTee != nil && !players.isEmpty
    }

    var roundSetupSummaryTitle: String {
        selectedCourse?.name ?? "Choose your setup"
    }

    var roundSetupSummaryDetail: String {
        guard selectedCourse != nil else {
            return "Pick a course, lock the tees, then add players."
        }

        let teeLabel = selectedTeeName.map { "\($0) tees" } ?? "Choose tees"
        let yardageLabel = selectedTeeYards.map { "\($0) yds" } ?? "Yardage pending"
        let golferCount = players.count == 1 ? "1 golfer ready" : "\(players.count) golfers ready"

        return "\(teeLabel) • \(yardageLabel) • \(golferCount)"
    }

    /// Names of bundled / cached courses (case-folded). Used to suppress
    /// "discover" rows for courses we already have geometry for.
    private var bundledNameSet: Set<String> {
        Set(courses.map { $0.name.lowercased() })
    }

    /// Country-scoped placeholder copy for the search field. Falls back to
    /// "your country" when reverse geocoding hasn't completed yet.
    var searchFieldPlaceholder: String {
        if let userCountryCode {
            return "Search courses in \(userCountryCode)"
        }
        return "Search courses in your country"
    }

    func selectCourse(_ course: SwingPalCourse) {
        if selectedCourse?.id != course.id {
            selectedTeeName = nil
            selectedTeeYards = nil
        }
        selectedCourse = course
    }

    func selectTee(_ tee: SwingPalCourse.Tee) {
        selectedTeeName = tee.name
        selectedTeeYards = tee.yards
    }

    func addGuest(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        players.append(.init(name: trimmedName, kind: .guest))
    }

    func removeGuest(id: UUID) {
        players.removeAll { $0.id == id && $0.kind == .guest }
    }

    func reset() {
        courses = repository.nearbyCourses()
        selectedCourse = nil
        selectedTeeName = nil
        selectedTeeYards = nil
        players = [.init(name: "You", kind: .selfPlayer)]
        searchQuery = ""
        searchResults = []
        pendingSearchTask?.cancel()
        pendingSearchTask = nil
        discoveryStatusMessage = nil
    }

    // MARK: - Discovery (Phase 1)

    /// Best-effort location + country resolution + 10 km Overpass lookup.
    /// Idempotent; safe to call from `.onAppear` repeatedly.
    func loadNearbyCoursesIfNeeded() async {
        guard !didLoadNearbyOnce, !isLoadingNearby else { return }
        didLoadNearbyOnce = true
        isLoadingNearby = true
        discoveryStatusMessage = nil
        defer { isLoadingNearby = false }

        let location: CLLocation
        do {
            location = try await deviceLocation.currentLocation()
        } catch {
            discoveryStatusMessage = "Location unavailable. Use search to find a course."
            return
        }
        userLocation = location.coordinate

        if let country = try? await countryCodeGeocoder.countryCode(for: location) {
            userCountryCode = country
        }

        do {
            let discoveries = try await discovery.nearbyCourses(
                around: location.coordinate,
                radiusKilometres: nearbyRadiusKilometres
            )
            nearbyDiscoveries = filterOutBundled(discoveries)
        } catch {
            discoveryStatusMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't find nearby courses."
        }
    }

    /// Updates the search query, debounces input, and kicks off Nominatim
    /// when the user has typed at least three characters AND we know what
    /// country to scope to.
    func updateSearchQuery(_ query: String) {
        searchQuery = query
        pendingSearchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            searchResults = []
            isSearching = false
            return
        }

        pendingSearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self, !Task.isCancelled else { return }

            // Resolve country lazily if discovery hasn't kicked off yet.
            if self.userCountryCode == nil {
                await self.loadNearbyCoursesIfNeeded()
            }

            guard let countryCode = self.userCountryCode else {
                self.discoveryStatusMessage =
                    "Allow location access to search courses in your country."
                return
            }

            await self.runSearch(query: trimmed, countryCode: countryCode)
        }
    }

    private func runSearch(query: String, countryCode: String) async {
        isSearching = true
        defer { isSearching = false }

        do {
            let results = try await discovery.searchCourses(
                named: query,
                countryCode: countryCode
            )
            guard !Task.isCancelled else { return }
            searchResults = filterOutBundled(results)
            discoveryStatusMessage = searchResults.isEmpty
                ? "No matching courses in \(countryCode)."
                : nil
        } catch is CancellationError {
            return
        } catch {
            searchResults = []
            discoveryStatusMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't search for courses right now."
        }
    }

    private func filterOutBundled(_ candidates: [DiscoveredCourse]) -> [DiscoveredCourse] {
        let bundled = bundledNameSet
        return candidates.filter { !bundled.contains($0.name.lowercased()) }
    }

    // MARK: - Import (Phase 2)

    /// Drives a discovered course through the on-device import pipeline.
    /// Idempotent: a second call while one is in progress is a no-op.
    func startImport(_ discovered: DiscoveredCourse) {
        guard currentImportStage == nil else { return }
        importTask?.cancel()
        pendingImportDiscovery = discovered
        currentImportStage = .fetchingGeometry
        lastImportValidation = nil
        lastImportedCourse = nil

        importTask = Task { [weak self, importCoordinator] in
            guard let self else { return }
            for await stage in importCoordinator.importCourse(discovered) {
                self.currentImportStage = stage
                if case let .completed(course, validation) = stage {
                    self.lastImportedCourse = course
                    self.lastImportValidation = validation
                    if validation.outcome == .approved {
                        self.acceptImportedCourse()
                    }
                }
            }
        }
    }

    func cancelImport() {
        importTask?.cancel()
        importTask = nil
        currentImportStage = nil
        lastImportValidation = nil
        lastImportedCourse = nil
        pendingImportDiscovery = nil
    }

    /// Confirms the imported course (typical path for `.approved`, opt-in
    /// for `.provisional`). Persists the course to the imported store, adds
    /// it to the in-memory course list, selects it as the active course,
    /// and dismisses the loading overlay.
    func acceptImportedCourse() {
        guard let course = lastImportedCourse else { return }
        if let discovered = pendingImportDiscovery, let validation = lastImportValidation {
            importedStore.save(course: course, discovered: discovered, validation: validation)
        }
        if !courses.contains(where: { $0.id == course.id }) {
            courses.append(course)
        }
        selectCourse(course)
        importTask = nil
        currentImportStage = nil
        pendingImportDiscovery = nil
    }
}
