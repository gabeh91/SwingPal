import Foundation
import OSLog
import Supabase

/// Thread-safe in-memory list of community bucket courses for synchronous ``CompositeCourseRepository`` reads.
final class CommunityCourseCache {
    static let shared = CommunityCourseCache()

    private let lock = NSLock()
    private var _courses: [SwingPalCourse] = []

    var courses: [SwingPalCourse] {
        lock.lock()
        defer { lock.unlock() }
        return _courses
    }

    func replace(with courses: [SwingPalCourse]) {
        lock.lock()
        defer { lock.unlock() }
        _courses = courses
    }

    func clear() {
        replace(with: [])
    }

    private init() {}
}

/// Loads and uploads `SwingPalCourse` JSON in the Supabase Storage bucket `courses`
/// (paths `<uuid>.json`). Requires an authenticated session (`authenticated` role).
enum CommunityCourseStorageService {
    private static let logger = Logger(subsystem: "com.ghtech.swingpal", category: "CommunityCourseStorage")
    private static let bucketId = "courses"
    private static let jsonSuffix = ".json"
    private static let pageSize = 500

    private static var uploadOptions: FileOptions {
        FileOptions(
            cacheControl: "86400",
            contentType: "application/json",
            upsert: true
        )
    }

    /// Lists JSON objects in the bucket, downloads each, decodes ``SwingPalCourse``, updates ``CommunityCourseCache``.
    static func refreshFromRemoteIfPossible() async {
        do {
            let decoded = try await fetchFromRemote()
            CommunityCourseCache.shared.replace(with: decoded.sorted { $0.distanceKilometers < $1.distanceKilometers })
            Self.logger.debug("Community courses loaded: \(decoded.count)")
        } catch {
            Self.logger.warning("Community course refresh failed: \(String(describing: error))")
        }
    }

    /// Lists JSON objects in the bucket, downloads each, decodes ``SwingPalCourse``. Does not touch local cache.
    static func fetchFromRemote() async throws -> [SwingPalCourse] {
        guard let client = SupabaseShared.client() else {
            throw SocialGraphError.notConfigured
        }

        var decoded: [SwingPalCourse] = []
        var offset = 0

        while true {
            let batch = try await client.storage.from(bucketId).list(
                path: "",
                options: SearchOptions(limit: pageSize, offset: offset, sortBy: SortBy(column: "name", order: "asc"))
            )
            if batch.isEmpty { break }

            for file in batch where file.name.lowercased().hasSuffix(jsonSuffix) {
                guard !file.name.contains("/") else { continue }
                do {
                    let data = try await client.storage.from(bucketId).download(path: file.name)
                    let course = try JSONDecoder().decode(SwingPalCourse.self, from: data)
                    decoded.append(course)
                } catch {
                    Self.logger.warning("Skipping \(file.name): \(String(describing: error))")
                }
            }

            if batch.count < pageSize { break }
            offset += pageSize
        }

        return decoded
    }

    /// Uploads a course JSON at `<course.id>.json`. Safe to call when signed out (no-op).
    static func uploadCourse(_ course: SwingPalCourse) async {
        guard let client = SupabaseShared.client() else { return }

        let path = "\(course.id.uuidString)\(jsonSuffix)"
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(course)
            _ = try await client.storage.from(bucketId).upload(path, data: data, options: Self.uploadOptions)
            Self.logger.debug("Uploaded community course \(path)")
            await refreshFromRemoteIfPossible()
        } catch {
            Self.logger.warning("Community course upload failed: \(String(describing: error))")
        }
    }
}
