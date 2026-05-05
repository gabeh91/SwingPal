import Foundation

protocol CourseRepository {
    func nearbyCourses() -> [SwingPalCourse]
}

/// Default repository used by the app shell. Returns only real, bundled courses
/// with traced polygon geometry (`Resources/Courses/<bundle-id>.json`).
struct SeededCourseRepository: CourseRepository {
    private struct CourseSeed {
        let displayName: String
        /// Filename (without extension) of the bundled JSON, or `nil` if this
        /// course doesn't have a hand-traced/OSM-derived asset yet.
        let bundledFilename: String?
        let distanceKilometers: Double
        let quality: SwingPalCourse.QualitySnapshot
        let community: SwingPalCourse.CommunityState
    }

    private let bundledLoader: BundledCourseLoader

    init(
        bundledLoader: BundledCourseLoader = BundledCourseLoader()
    ) {
        self.bundledLoader = bundledLoader
    }

    func nearbyCourses() -> [SwingPalCourse] {
        let seeds: [CourseSeed] = [
            CourseSeed(
                displayName: "Royal Melbourne",
                bundledFilename: "royal-melbourne-west",
                distanceKilometers: 3.2,
                quality: .init(
                    overallConfidence: .reviewed,
                    geometryConfidence: .reviewed,
                    metadataConfidence: .verified
                ),
                community: .init(access: .open, correctionCount: 6)
            ),
            CourseSeed(
                displayName: "Medway Golf Club",
                bundledFilename: "medway",
                distanceKilometers: 2.6,
                quality: .init(
                    overallConfidence: .reviewed,
                    geometryConfidence: .reviewed,
                    metadataConfidence: .reviewed
                ),
                community: .init(access: .open, correctionCount: 0)
            )
        ]

        return seeds
            .compactMap(makeBundledCourse(seed:))
            .sorted { $0.distanceKilometers < $1.distanceKilometers }
    }

    private func makeBundledCourse(seed: CourseSeed) -> SwingPalCourse? {
        guard let filename = seed.bundledFilename,
              let bundled = bundledLoader.loadCourse(named: filename) else {
            return nil
        }

        // Honour curated metadata flags from the seed (editorial control) while
        // keeping the real geometry/holes/par/coordinate decoded from the JSON.
        return SwingPalCourse(
            id: bundled.id,
            name: bundled.name,
            distanceKilometers: seed.distanceKilometers,
            coordinate: bundled.coordinate,
            holeCount: bundled.holeCount,
            par: bundled.par,
            sourceReferences: bundled.sourceReferences,
            quality: bundled.quality,
            community: seed.community,
            tees: bundled.tees,
            holes: bundled.holes
        )
    }
}
