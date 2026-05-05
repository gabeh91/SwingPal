import Foundation
import CoreLocation
import OSLog

/// Fetches the raw Overpass JSON payload for a single discovered course
/// and caches it on disk so that retries / re-validation skip the network.
protocol OSMCourseGeometryFetching {
    /// Returns the raw `{"elements": [...]}` JSON the runtime converter
    /// expects, with each `golf=hole/tee/fairway/green/bunker/water_hazard`
    /// element decorated with full `geometry` (lat/lon polylines).
    func fetchGeometry(for course: DiscoveredCourse) async throws -> Data
}

struct LiveOSMCourseGeometryFetcher: OSMCourseGeometryFetching {
    private static let logger = Logger(subsystem: "com.swingpal.app", category: "OSMCourseGeometryFetcher")

    private let session: URLSession
    private let cacheDirectory: URL?
    private let radiusKilometres: Double

    init(
        session: URLSession = .shared,
        cacheDirectory: URL? = LiveOSMCourseGeometryFetcher.defaultCacheDirectory(),
        radiusKilometres: Double = 1.5
    ) {
        self.session = session
        self.cacheDirectory = cacheDirectory
        self.radiusKilometres = radiusKilometres
    }

    func fetchGeometry(for course: DiscoveredCourse) async throws -> Data {
        if let cacheURL = cacheURL(for: course),
           let cached = try? Data(contentsOf: cacheURL),
           !cached.isEmpty {
            Self.logger.debug("Using cached OSM payload for \(course.id, privacy: .public)")
            return cached
        }

        let bbox = OSMBoundingBox(
            centre: CLLocationCoordinate2D(
                latitude: course.coordinate.latitude,
                longitude: course.coordinate.longitude
            ),
            radiusKilometres: radiusKilometres
        )

        let query = """
        [out:json][timeout:60];
        (
          way["golf"~"^(hole|tee|fairway|green|bunker|water_hazard)$"](\(bbox.south),\(bbox.west),\(bbox.north),\(bbox.east));
        );
        out geom;
        """

        var request = URLRequest(url: LiveOSMCourseDiscovery.overpassEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(LiveOSMCourseDiscovery.userAgent, forHTTPHeaderField: "User-Agent")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        request.httpBody = "data=\(encoded)".data(using: .utf8)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .notConnectedToInternet
            || error.code == .timedOut
            || error.code == .cannotConnectToHost {
            throw OSMCourseDiscoveryError.networkUnavailable
        }

        guard let http = response as? HTTPURLResponse else {
            throw OSMCourseDiscoveryError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300:
            break
        case 429, 503:
            throw OSMCourseDiscoveryError.rateLimited
        default:
            Self.logger.warning("Geometry HTTP error: \(http.statusCode, privacy: .public)")
            throw OSMCourseDiscoveryError.invalidResponse
        }

        if let cacheURL = cacheURL(for: course) {
            try? FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: cacheURL)
        }
        return data
    }

    private func cacheURL(for course: DiscoveredCourse) -> URL? {
        cacheDirectory?.appendingPathComponent("\(course.id).json", isDirectory: false)
    }

    static func defaultCacheDirectory() -> URL? {
        guard let caches = try? FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return caches
            .appendingPathComponent("SwingPal", isDirectory: true)
            .appendingPathComponent("OSMRawJSON", isDirectory: true)
    }
}
