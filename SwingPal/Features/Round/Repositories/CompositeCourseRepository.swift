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
    private let communityCourses: () -> [SwingPalCourse]

    init(
        bundled: any CourseRepository = SeededCourseRepository(),
        importedStore: ImportedCourseStore = ImportedCourseStore(),
        communityCourses: @escaping () -> [SwingPalCourse] = { CommunityCourseCache.shared.courses }
    ) {
        self.bundled = bundled
        self.importedStore = importedStore
        self.communityCourses = communityCourses
    }

    func nearbyCourses() -> [SwingPalCourse] {
        let bundledCourses = bundled.nearbyCourses()
        let importedCourses = importedStore.loadAll()
        let remoteCommunity = communityCourses()

        let bundledKeys = Set(bundledCourses.map(courseDedupeKey))

        var seenImportedKeys: Set<String> = []
        var importedDeduped: [SwingPalCourse] = []
        for course in importedCourses {
            let key = courseDedupeKey(course)
            if bundledKeys.contains(key) { continue }
            if !seenImportedKeys.insert(key).inserted { continue }
            importedDeduped.append(course)
        }

        let supersededKeys = bundledKeys.union(seenImportedKeys)
        var seenCommunityKeys: Set<String> = []
        let communityDeduped = remoteCommunity.filter { course in
            let key = courseDedupeKey(course)
            guard !supersededKeys.contains(key) else { return false }
            return seenCommunityKeys.insert(key).inserted
        }

        return (bundledCourses + importedDeduped + communityDeduped)
            .map { course in
                // A persisted distance belongs to an earlier location, or even
                // another user who uploaded the course. It is not proximity.
                var course = course
                course.distanceKilometers = nil
                return course
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func courseDedupeKey(_ course: SwingPalCourse) -> String {
        let lat = (course.coordinate.latitude * 1000).rounded() / 1000
        let lon = (course.coordinate.longitude * 1000).rounded() / 1000
        return "\(course.name.lowercased())@\(lat),\(lon)"
    }
}
