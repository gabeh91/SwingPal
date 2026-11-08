import Foundation
import OSLog

/// Manifest entry recorded for every successfully imported course, so we
/// can re-hydrate the cached course list on cold launch without parsing
/// every per-course JSON eagerly.
struct ImportedCourseManifestEntry: Codable, Equatable {
    let osmID: String
    let slug: String
    let name: String
    let importedAt: Date
    let outcome: CourseValidationResult.Outcome
    let concerns: [String]
    let aiSummary: String?
}

/// Persists imported `SwingPalCourse` payloads + a lightweight manifest
/// under `~/Library/Caches/SwingPal/`. Re-imports of the same course are
/// idempotent (the per-osmID file overwrites in place).
struct ImportedCourseStore {
    private static let logger = Logger(subsystem: "com.swingpal.app", category: "ImportedCourseStore")

    private let baseDirectory: URL?
    private let fileManager: FileManager

    init(
        baseDirectory: URL? = ImportedCourseStore.defaultBaseDirectory(),
        fileManager: FileManager = .default
    ) {
        self.baseDirectory = baseDirectory
        self.fileManager = fileManager
    }

    /// Cache root for imported assets. Returns `nil` when caches are
    /// inaccessible (extremely rare on iOS).
    static func defaultBaseDirectory() -> URL? {
        guard let caches = try? FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return caches.appendingPathComponent("SwingPal", isDirectory: true)
    }

    private var coursesDirectory: URL? {
        baseDirectory?.appendingPathComponent("Courses", isDirectory: true)
    }

    private var manifestURL: URL? {
        baseDirectory?.appendingPathComponent("imported-manifest.json", isDirectory: false)
    }

    @discardableResult
    func save(
        course: SwingPalCourse,
        discovered: DiscoveredCourse,
        validation: CourseValidationResult
    ) -> Bool {
        guard let coursesDirectory, let manifestURL else { return false }
        do {
            try fileManager.createDirectory(
                at: coursesDirectory,
                withIntermediateDirectories: true
            )

            let courseURL = coursesDirectory.appendingPathComponent(
                fileSafeName(for: discovered.id) + ".json",
                isDirectory: false
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(course)
            try data.write(to: courseURL, options: .atomic)

            var manifest = loadManifest()
            manifest.removeAll { $0.osmID == discovered.id }
            manifest.append(
                ImportedCourseManifestEntry(
                    osmID: discovered.id,
                    slug: courseSlug(for: discovered),
                    name: course.name,
                    importedAt: Date(),
                    outcome: validation.outcome,
                    concerns: validation.aiConcerns,
                    aiSummary: validation.aiSummary
                )
            )
            let manifestData = try encoder.encode(manifest)
            try manifestData.write(to: manifestURL, options: .atomic)
            return true
        } catch {
            Self.logger.warning("Failed to save imported course: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    func loadAll() -> [SwingPalCourse] {
        guard let coursesDirectory, let _ = manifestURL else { return [] }
        let manifest = loadManifest()
        guard !manifest.isEmpty else { return [] }

        let decoder = JSONDecoder()
        var loaded: [SwingPalCourse] = []
        for entry in manifest {
            let url = coursesDirectory.appendingPathComponent(
                fileSafeName(for: entry.osmID) + ".json",
                isDirectory: false
            )
            guard let data = try? Data(contentsOf: url) else { continue }
            if let course = try? decoder.decode(SwingPalCourse.self, from: data) {
                loaded.append(course)
            }
        }
        return loaded
    }

    func remove(osmID: String) {
        guard let coursesDirectory, let manifestURL else { return }
        let url = coursesDirectory.appendingPathComponent(
            fileSafeName(for: osmID) + ".json",
            isDirectory: false
        )
        try? fileManager.removeItem(at: url)

        var manifest = loadManifest()
        manifest.removeAll { $0.osmID == osmID }
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: manifestURL, options: .atomic)
        }
    }

    /// Returns the manifest sorted by most-recently-imported first.
    func loadManifest() -> [ImportedCourseManifestEntry] {
        guard let manifestURL,
              let data = try? Data(contentsOf: manifestURL),
              let entries = try? JSONDecoder().decode([ImportedCourseManifestEntry].self, from: data)
        else { return [] }
        return entries.sorted { $0.importedAt > $1.importedAt }
    }

    private func fileSafeName(for osmID: String) -> String {
        // osmID is normally `way-12345` / `relation-456` so already safe,
        // but we sanitise anyway against future schemes.
        osmID.replacingOccurrences(
            of: "[^A-Za-z0-9._-]",
            with: "_",
            options: .regularExpression
        )
    }

    private func courseSlug(for discovered: DiscoveredCourse) -> String {
        let lowered = discovered.name.lowercased()
        var slug = ""
        var lastWasHyphen = false
        for character in lowered {
            if character.isLetter || character.isNumber {
                slug.append(character)
                lastWasHyphen = false
            } else if !lastWasHyphen {
                slug.append("-")
                lastWasHyphen = true
            }
        }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? discovered.id : slug
    }
}
