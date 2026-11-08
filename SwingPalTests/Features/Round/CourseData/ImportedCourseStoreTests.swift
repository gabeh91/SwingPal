import XCTest
@testable import SwingPal

final class ImportedCourseStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImportedCourseStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        try super.tearDownWithError()
    }

    func testSavingThenLoadingRoundTripsTheCourse() {
        let store = ImportedCourseStore(baseDirectory: temporaryDirectory)
        let course = SwingPalCourse.test(name: "Sandhurst", distanceKilometers: 7.4)
        let discovered = stubDiscovered(name: "Sandhurst")
        let validation = CourseValidationResult(
            outcome: .provisional,
            aiConcerns: ["Greens are unusually small."],
            aiSummary: "Looks playable but small greens.",
            aiAvailable: true
        )

        XCTAssertTrue(store.save(course: course, discovered: discovered, validation: validation))

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Sandhurst")

        let manifest = store.loadManifest()
        XCTAssertEqual(manifest.count, 1)
        XCTAssertEqual(manifest.first?.outcome, .provisional)
        XCTAssertEqual(manifest.first?.aiSummary, "Looks playable but small greens.")
    }

    func testSavingTheSameOSMIDTwiceOverwrites() {
        let store = ImportedCourseStore(baseDirectory: temporaryDirectory)
        let initial = SwingPalCourse.test(name: "Sandhurst", distanceKilometers: 7.4)
        let updated = SwingPalCourse.test(name: "Sandhurst Updated", distanceKilometers: 7.4)
        let discovered = stubDiscovered(name: "Sandhurst")
        let validation = CourseValidationResult(outcome: .approved)

        XCTAssertTrue(store.save(course: initial, discovered: discovered, validation: validation))
        XCTAssertTrue(store.save(course: updated, discovered: discovered, validation: validation))

        XCTAssertEqual(store.loadAll().count, 1)
        XCTAssertEqual(store.loadAll().first?.name, "Sandhurst Updated")
    }

    func testRemoveDeletesEntry() {
        let store = ImportedCourseStore(baseDirectory: temporaryDirectory)
        let course = SwingPalCourse.test(name: "Sandhurst", distanceKilometers: 7.4)
        let discovered = stubDiscovered(name: "Sandhurst")
        store.save(course: course, discovered: discovered, validation: CourseValidationResult(outcome: .approved))

        store.remove(osmID: discovered.id)

        XCTAssertTrue(store.loadAll().isEmpty)
        XCTAssertTrue(store.loadManifest().isEmpty)
    }

    func testManifestSortedByMostRecentFirst() {
        let store = ImportedCourseStore(baseDirectory: temporaryDirectory)
        let courseA = SwingPalCourse.test(name: "Course A", distanceKilometers: 1)
        let courseB = SwingPalCourse.test(name: "Course B", distanceKilometers: 2)

        store.save(course: courseA, discovered: stubDiscovered(name: "Course A", id: "way-1"),
                   validation: CourseValidationResult(outcome: .approved))
        store.save(course: courseB, discovered: stubDiscovered(name: "Course B", id: "way-2"),
                   validation: CourseValidationResult(outcome: .approved))

        let manifest = store.loadManifest()
        XCTAssertEqual(manifest.first?.osmID, "way-2")
    }

    private func stubDiscovered(name: String, id: String = "way-99") -> DiscoveredCourse {
        let parts = id.split(separator: "-")
        let osmType = DiscoveredCourse.OSMElementType(rawValue: String(parts.first ?? "way")) ?? .way
        let osmID = Int64(parts.last ?? "0") ?? 0
        return DiscoveredCourse(
            id: id,
            name: name,
            coordinate: .init(latitude: -37.97, longitude: 145.03),
            osmID: osmID,
            osmType: osmType,
            countryCode: "AU",
            region: "Victoria",
            distanceKilometers: 5.0
        )
    }
}
