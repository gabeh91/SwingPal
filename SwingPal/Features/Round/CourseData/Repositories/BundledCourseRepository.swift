import Foundation
import OSLog

/// Loads `SwingPalCourse` instances from JSON files bundled inside the app.
/// Each file is the JSON-encoded representation of a `SwingPalCourse` (the
/// model is `Codable` end to end), produced by an offline ingestion pipeline -
/// today that's `tmp/convert_osm_to_course.py` running over OpenStreetMap data.
///
/// `BundledCourseLoader` is intentionally narrow: it just resolves a
/// `(folder, filename)` pair to a decoded `SwingPalCourse`. Repositories layer
/// curated metadata (display distance, quality flags, community state) on top
/// without forcing the JSON files to carry app-state concerns.
struct BundledCourseLoader {
    private static let logger = Logger(
        subsystem: "com.swingpal.app",
        category: "BundledCourseLoader"
    )

    private let bundle: Bundle
    private let subdirectory: String

    init(bundle: Bundle = .main, subdirectory: String = "Courses") {
        self.bundle = bundle
        self.subdirectory = subdirectory
    }

    /// Loads a course JSON from the bundle, returning `nil` if the file is
    /// missing or unparseable. We never throw to the caller because a missing
    /// curated course should gracefully fall back to synthetic geometry rather
    /// than crash the round flow.
    func loadCourse(named filename: String) -> SwingPalCourse? {
        guard let url = bundle.url(forResource: filename, withExtension: "json", subdirectory: subdirectory)
            ?? bundle.url(forResource: filename, withExtension: "json")
        else {
            Self.logger.warning("Bundled course JSON not found: \(filename, privacy: .public).json")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SwingPalCourse.self, from: data)
        } catch {
            Self.logger.error(
                "Failed to decode bundled course \(filename, privacy: .public).json: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}
