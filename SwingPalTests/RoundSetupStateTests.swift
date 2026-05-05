import XCTest
import CoreLocation
@testable import SwingPal

@MainActor
final class RoundSetupStateTests: XCTestCase {
    func testCoursesAreSortedByAscendingDistance() {
        let state = RoundSetupState(repository: StubCourseRepository(courses: [
            .test(name: "Course B", distanceKilometers: 12.0),
            .test(name: "Course A", distanceKilometers: 3.5)
        ]))

        XCTAssertEqual(state.sortedCourses.map(\.name), ["Course A", "Course B"])
    }

    func testAddingGuestPlayerCreatesGuestDraft() {
        let state = RoundSetupState(repository: StubCourseRepository(courses: []))

        state.addGuest(named: "Ben")

        XCTAssertEqual(state.players.last?.name, "Ben")
        XCTAssertEqual(state.players.last?.kind, .guest)
    }

    func testRemovingGuestPlayerDropsOnlyThatGuest() {
        let state = RoundSetupState(repository: StubCourseRepository(courses: []))
        state.addGuest(named: "Ben")
        state.addGuest(named: "Mia")
        let benID = try! XCTUnwrap(state.players.first(where: { $0.name == "Ben" })?.id)

        state.removeGuest(id: benID)

        XCTAssertEqual(state.players.map(\.name), ["You", "Mia"])
    }

    func testRemovingSelfPlayerIsIgnored() {
        let state = RoundSetupState(repository: StubCourseRepository(courses: []))
        let selfID = state.players[0].id

        state.removeGuest(id: selfID)

        XCTAssertEqual(state.players.map(\.name), ["You"])
    }

    func testSelectingTeeBuildsPersistentRoundSetupSummary() {
        let state = RoundSetupState(repository: StubCourseRepository(courses: [
            .test(name: "Royal Melbourne", distanceKilometers: 3.2)
        ]))
        let course = state.courses[0]

        state.selectCourse(course)
        state.selectTee(course.tees[1])

        XCTAssertEqual(state.selectedCourse?.name, "Royal Melbourne")
        XCTAssertEqual(state.selectedTeeName, "Member")
        XCTAssertEqual(state.selectedTeeYards, 6420)
        XCTAssertEqual(state.roundSetupSummaryTitle, "Royal Melbourne")
        XCTAssertEqual(state.roundSetupSummaryDetail, "Member tees • 6420 yds • 1 golfer ready")
    }

    func testSelectingCourseExposesAvailableTeesAndSelectedTee() {
        let state = RoundSetupState(repository: StubCourseRepository(courses: [
            .test(name: "Royal Melbourne", distanceKilometers: 3.2)
        ]))
        let course = state.courses[0]

        state.selectCourse(course)
        state.selectTee(course.tees[2])

        XCTAssertEqual(state.availableTees.map(\.name), ["Championship", "Member", "Forward"])
        XCTAssertEqual(state.selectedTee?.name, "Forward")
        XCTAssertEqual(state.selectedTee?.yards, 5790)
    }

    func testCanStartRoundRequiresCourseAndTeeSelection() {
        let state = RoundSetupState(repository: StubCourseRepository(courses: [
            .test(name: "Royal Melbourne", distanceKilometers: 3.2)
        ]))
        let course = state.courses[0]

        XCTAssertFalse(state.canStartRound)

        state.selectCourse(course)
        XCTAssertFalse(state.canStartRound)

        state.selectTee(course.tees[0])
        XCTAssertTrue(state.canStartRound)
    }

    func testResetClearsSelectedCourseAndSelectedTee() {
        let courses: [SwingPalCourse] = [
            .test(name: "Royal Melbourne", distanceKilometers: 3.2)
        ]
        let state = RoundSetupState(repository: StubCourseRepository(courses: courses))

        state.selectCourse(courses[0])
        state.selectTee(courses[0].tees[1])
        state.addGuest(named: "Ben")
        state.reset()

        XCTAssertNil(state.selectedCourse)
        XCTAssertNil(state.selectedTeeName)
        XCTAssertNil(state.selectedTeeYards)
        XCTAssertEqual(state.roundSetupSummaryTitle, "Choose your setup")
        XCTAssertEqual(state.roundSetupSummaryDetail, "Pick a course, lock the tees, then add players.")
    }

    func testSelectingDifferentCourseClearsPriorTeeSelection() {
        let courses: [SwingPalCourse] = [
            .test(name: "Royal Melbourne", distanceKilometers: 3.2),
            .test(name: "Kingston Heath", distanceKilometers: 7.4)
        ]
        let state = RoundSetupState(repository: StubCourseRepository(courses: courses))

        state.selectCourse(courses[0])
        state.selectTee(courses[0].tees[1])
        state.selectCourse(courses[1])

        XCTAssertEqual(state.selectedCourse?.name, "Kingston Heath")
        XCTAssertNil(state.selectedTeeName)
        XCTAssertNil(state.selectedTeeYards)
        XCTAssertNil(state.selectedTee)
        XCTAssertEqual(state.roundSetupSummaryDetail, "Choose tees • Yardage pending • 1 golfer ready")
    }

    // MARK: - Discovery (Phase 1)

    func testLoadNearbyCoursesPopulatesDiscoveriesAndCountry() async {
        let stubLocation = StubDeviceLocationProvider(
            location: CLLocation(latitude: -37.97, longitude: 145.03)
        )
        let stubGeocoder = StubCountryCodeGeocoder(countryCode: "AU")
        let stubDiscovery = StubOSMCourseDiscovery(
            nearby: [
                .stub(id: "way-1", name: "Cranbourne Golf Club", lat: -37.99, lon: 145.21, distance: 18.4),
                .stub(id: "way-2", name: "Yarra Yarra Golf Club", lat: -37.92, lon: 145.10, distance: 6.7)
            ]
        )
        let state = RoundSetupState(
            repository: StubCourseRepository(courses: []),
            discovery: stubDiscovery,
            deviceLocation: stubLocation,
            countryCodeGeocoder: stubGeocoder
        )

        await state.loadNearbyCoursesIfNeeded()

        XCTAssertEqual(state.userCountryCode, "AU")
        XCTAssertEqual(state.nearbyDiscoveries.map(\.name), ["Cranbourne Golf Club", "Yarra Yarra Golf Club"])
        XCTAssertEqual(state.searchFieldPlaceholder, "Search courses in AU")
    }

    func testLoadNearbyCoursesFiltersOutBundledByName() async {
        let stubLocation = StubDeviceLocationProvider(
            location: CLLocation(latitude: -37.97, longitude: 145.03)
        )
        let stubGeocoder = StubCountryCodeGeocoder(countryCode: "AU")
        let stubDiscovery = StubOSMCourseDiscovery(
            nearby: [
                .stub(id: "way-1", name: "Royal Melbourne", lat: -37.97, lon: 145.04, distance: 1.0),
                .stub(id: "way-2", name: "Yarra Yarra Golf Club", lat: -37.95, lon: 145.10, distance: 4.0)
            ]
        )
        let state = RoundSetupState(
            repository: StubCourseRepository(courses: [
                .test(name: "Royal Melbourne", distanceKilometers: 0.5)
            ]),
            discovery: stubDiscovery,
            deviceLocation: stubLocation,
            countryCodeGeocoder: stubGeocoder
        )

        await state.loadNearbyCoursesIfNeeded()

        XCTAssertEqual(state.nearbyDiscoveries.map(\.name), ["Yarra Yarra Golf Club"])
    }

    func testLoadNearbyCoursesSurfacesLocationDeniedMessage() async {
        let stubLocation = StubDeviceLocationProvider(error: DeviceLocationError.unauthorized)
        let stubGeocoder = StubCountryCodeGeocoder(countryCode: nil)
        let state = RoundSetupState(
            repository: StubCourseRepository(courses: []),
            discovery: StubOSMCourseDiscovery(),
            deviceLocation: stubLocation,
            countryCodeGeocoder: stubGeocoder
        )

        await state.loadNearbyCoursesIfNeeded()

        XCTAssertNil(state.userLocation)
        XCTAssertTrue(state.nearbyDiscoveries.isEmpty)
        XCTAssertNotNil(state.discoveryStatusMessage)
    }

    func testUpdateSearchQueryDebouncesAndPopulatesResults() async {
        let stubLocation = StubDeviceLocationProvider(
            location: CLLocation(latitude: -37.97, longitude: 145.03)
        )
        let stubGeocoder = StubCountryCodeGeocoder(countryCode: "AU")
        let stubDiscovery = StubOSMCourseDiscovery(
            search: [
                .stub(id: "rel-1", name: "Sandhurst Club", lat: -38.05, lon: 145.16, distance: nil)
            ]
        )
        let state = RoundSetupState(
            repository: StubCourseRepository(courses: []),
            discovery: stubDiscovery,
            deviceLocation: stubLocation,
            countryCodeGeocoder: stubGeocoder
        )

        await state.loadNearbyCoursesIfNeeded()

        state.updateSearchQuery("Sand")
        XCTAssertEqual(state.searchResults.count, 0, "Debounce hasn't fired yet")
        try? await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertEqual(state.searchResults.map(\.name), ["Sandhurst Club"])
        XCTAssertEqual(stubDiscovery.searchCallCount, 1)
    }

    func testUpdateSearchQueryShorterThanThreeCharsClearsResults() async {
        let stubDiscovery = StubOSMCourseDiscovery(
            search: [.stub(id: "rel-1", name: "Sandhurst", lat: 0, lon: 0, distance: nil)]
        )
        let state = RoundSetupState(
            repository: StubCourseRepository(courses: []),
            discovery: stubDiscovery,
            deviceLocation: StubDeviceLocationProvider(error: DeviceLocationError.unauthorized),
            countryCodeGeocoder: StubCountryCodeGeocoder(countryCode: "AU")
        )

        state.updateSearchQuery("So")
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(state.searchResults.isEmpty)
        XCTAssertEqual(stubDiscovery.searchCallCount, 0)
    }

    func testResetClearsSearchAndDiscoveryState() async {
        let stubLocation = StubDeviceLocationProvider(
            location: CLLocation(latitude: 0, longitude: 0)
        )
        let stubDiscovery = StubOSMCourseDiscovery(
            search: [.stub(id: "rel-1", name: "Foo", lat: 0, lon: 0, distance: nil)]
        )
        let state = RoundSetupState(
            repository: StubCourseRepository(courses: []),
            discovery: stubDiscovery,
            deviceLocation: stubLocation,
            countryCodeGeocoder: StubCountryCodeGeocoder(countryCode: "AU")
        )
        await state.loadNearbyCoursesIfNeeded()
        state.updateSearchQuery("Foo")
        try? await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertFalse(state.searchResults.isEmpty)

        state.reset()

        XCTAssertEqual(state.searchQuery, "")
        XCTAssertTrue(state.searchResults.isEmpty)
    }
}

private struct StubCourseRepository: CourseRepository {
    let courses: [SwingPalCourse]

    func nearbyCourses() -> [SwingPalCourse] {
        courses
    }
}

private struct StubDeviceLocationProvider: DeviceLocationProviding {
    var location: CLLocation?
    var error: Error?

    init(location: CLLocation? = nil, error: Error? = nil) {
        self.location = location
        self.error = error
    }

    func currentLocation() async throws -> CLLocation {
        if let error { throw error }
        if let location { return location }
        throw DeviceLocationError.unavailable
    }
}

private struct StubCountryCodeGeocoder: CountryCodeGeocoding {
    let countryCode: String?

    func countryCode(for location: CLLocation) async throws -> String? {
        countryCode
    }
}

private final class StubOSMCourseDiscovery: OSMCourseDiscovering, @unchecked Sendable {
    var nearby: [DiscoveredCourse]
    var search: [DiscoveredCourse]
    private(set) var nearbyCallCount: Int = 0
    private(set) var searchCallCount: Int = 0

    init(nearby: [DiscoveredCourse] = [], search: [DiscoveredCourse] = []) {
        self.nearby = nearby
        self.search = search
    }

    func nearbyCourses(
        around coordinate: CLLocationCoordinate2D,
        radiusKilometres: Double
    ) async throws -> [DiscoveredCourse] {
        nearbyCallCount += 1
        return nearby
    }

    func searchCourses(
        named query: String,
        countryCode: String
    ) async throws -> [DiscoveredCourse] {
        searchCallCount += 1
        return search
    }
}

private extension DiscoveredCourse {
    static func stub(
        id: String,
        name: String,
        lat: Double,
        lon: Double,
        distance: Double?
    ) -> DiscoveredCourse {
        let parts = id.split(separator: "-")
        let osmType = DiscoveredCourse.OSMElementType(rawValue: String(parts.first ?? "way")) ?? .way
        let osmID = Int64(parts.last ?? "0") ?? 0
        return DiscoveredCourse(
            id: id,
            name: name,
            coordinate: .init(latitude: lat, longitude: lon),
            osmID: osmID,
            osmType: osmType,
            countryCode: nil,
            region: nil,
            distanceKilometers: distance
        )
    }
}
