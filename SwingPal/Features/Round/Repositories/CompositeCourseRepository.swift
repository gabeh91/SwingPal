import Foundation

/// Replacement for `SeededCourseRepository` that surfaces every bundled
/// course AND every previously-imported course so a re-round can pick a
/// course the user already downloaded without re-running the OSM pipeline.
///
/// Dedupe rules:
/// - Bundled courses always win — if a user previously imported "Royal
///   Melbourne (West)" and we later ship a hand-traced bundled version,
///   the bundled course replaces the cached import.
/// - Within imported courses we de-dupe by `(name, coordinate)` so the
///   same OSM relation imported twice (eg. user re-runs the import to
///   pick up new tags) doesn't double up.
struct CompositeCourseRepository: CourseRepository {
    private let bundled: any CourseRepository
    private let importedStore: ImportedCourseStore

    init(
        bundled: any CourseRepository = SeededCourseRepository(),
        importedStore: ImportedCourseStore = ImportedCourseStore()
    ) {
        self.bundled = bundled
        self.importedStore = importedStore
    }

    func nearbyCourses() -> [SwingPalCourse] {
        let bundledCourses = bundled.nearbyCourses()
        let importedCourses = importedStore.loadAll()

        let bundledKeys = Set(bundledCourses.map(courseDedupeKey))

        var seenImportedKeys: Set<String> = []
        var importedDeduped: [SwingPalCourse] = []
        for course in importedCourses {
            let key = courseDedupeKey(course)
            if bundledKeys.contains(key) { continue }
            if !seenImportedKeys.insert(key).inserted { continue }
            importedDeduped.append(course)
        }

        return (bundledCourses + importedDeduped)
            .sorted { $0.distanceKilometers < $1.distanceKilometers }
    }

    private func courseDedupeKey(_ course: SwingPalCourse) -> String {
        let lat = (course.coordinate.latitude * 1000).rounded() / 1000
        let lon = (course.coordinate.longitude * 1000).rounded() / 1000
        return "\(course.name.lowercased())@\(lat),\(lon)"
    }
}
