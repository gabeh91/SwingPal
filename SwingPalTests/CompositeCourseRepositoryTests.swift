import XCTest
@testable import SwingPal

final class CompositeCourseRepositoryTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CompositeRepoTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        try super.tearDownWithError()
    }

    func testCompositeReturnsBundledOnlyWhenNoImportsCached() {
        let repo = CompositeCourseRepository(
            bundled: StubBundled(courses: [
                .test(name: "Royal Melbourne", distanceKilometers: 1.0),
                .test(name: "Medway Golf Club", distanceKilometers: 2.0)
            ]),
            importedStore: ImportedCourseStore(baseDirectory: temporaryDirectory)
        )

        XCTAssertEqual(repo.nearbyCourses().map(\.name), ["Royal Melbourne", "Medway Golf Club"])
    }

    func testCompositeMergesBundledWithImportedSortedByDistance() {
        let store = ImportedCourseStore(baseDirectory: temporaryDirectory)
        let imported = SwingPalCourse.test(name: "Sandhurst", distanceKilometers: 4.0)
        store.save(
            course: imported,
            discovered: discovered(named: "Sandhurst"),
            validation: CourseValidationResult(outcome: .provisional)
        )

        let repo = CompositeCourseRepository(
            bundled: StubBundled(courses: [
                .test(name: "Royal Melbourne", distanceKilometers: 1.0),
                .test(name: "Medway Golf Club", distanceKilometers: 6.0)
            ]),
            importedStore: store
        )

        let names = repo.nearbyCourses().map(\.name)
        XCTAssertEqual(names, ["Royal Melbourne", "Sandhurst", "Medway Golf Club"])
    }

    func testCompositeLetsBundledWinOverDuplicateImported() {
        let store = ImportedCourseStore(baseDirectory: temporaryDirectory)
        let imported = SwingPalCourse.test(name: "Royal Melbourne", distanceKilometers: 1.0)
        store.save(
            course: imported,
            discovered: discovered(named: "Royal Melbourne"),
            validation: CourseValidationResult(outcome: .provisional)
        )

        let repo = CompositeCourseRepository(
            bundled: StubBundled(courses: [
                .test(name: "Royal Melbourne", distanceKilometers: 1.0)
            ]),
            importedStore: store
        )

        XCTAssertEqual(repo.nearbyCourses().count, 1)
        XCTAssertEqual(
            repo.nearbyCourses().first?.quality.overallConfidence,
            .reviewed,
            "Bundled (reviewed) version should win over imported (provisional)."
        )
    }

    private func discovered(named name: String) -> DiscoveredCourse {
        DiscoveredCourse(
            id: "way-\(name.hashValue)",
            name: name,
            coordinate: .init(latitude: -37.97, longitude: 145.03),
            osmID: Int64(abs(name.hashValue % 10_000)),
            osmType: .way,
            countryCode: "AU",
            region: "Victoria",
            distanceKilometers: 1.0
        )
    }
}

private struct StubBundled: CourseRepository {
    let courses: [SwingPalCourse]
    func nearbyCourses() -> [SwingPalCourse] { courses }
}
