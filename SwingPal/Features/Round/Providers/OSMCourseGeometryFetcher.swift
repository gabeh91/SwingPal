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

    /// The `golf=*` way values the converter understands.
    static let golfWayPattern = "^(hole|tee|fairway|green|bunker|water_hazard|lateral_water_hazard)$"
    /// Cached payloads are refreshed after this long, so fixes made in
    /// OpenStreetMap (a green drawn in, a hole renumbered) reach the app.
    static let cacheLifetime: TimeInterval = 30 * 24 * 60 * 60
    /// Bumped whenever the query changes, so old payloads aren't reused.
    static let cacheVersion = "v2"

    private let client: OverpassClient
    private let cacheDirectory: URL?
    private let radiusKilometres: Double

    init(
        session: URLSession = .shared,
        cacheDirectory: URL? = LiveOSMCourseGeometryFetcher.defaultCacheDirectory(),
        radiusKilometres: Double = 1.5
    ) {
        self.client = OverpassClient(session: session)
        self.cacheDirectory = cacheDirectory
        self.radiusKilometres = radiusKilometres
    }

    func fetchGeometry(for course: DiscoveredCourse) async throws -> Data {
        if let cached = cachedPayload(for: course) {
            Self.logger.debug("Using cached OSM payload for \(course.id, privacy: .public)")
            return cached
        }

        // 1. Everything inside the course's own boundary, plus a margin for
        //    tees and greens drawn just outside it. Scales to any course size
        //    and never picks up the course next door.
        var payload: Data?
        if let scoped = Self.boundaryQuery(for: course) {
            do {
                let data = try await client.run(scoped)
                if Self.holeCount(in: data) > 0 { payload = data }
            } catch OSMCourseDiscoveryError.networkUnavailable {
                throw OSMCourseDiscoveryError.networkUnavailable
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                Self.logger.info("Boundary query failed for \(course.id, privacy: .public); trying the area around it")
            }
        }

        // 2. A box around the course's centre, for courses mapped as a single
        //    point or whose boundary doesn't enclose the holes.
        let data: Data
        if let payload {
            data = payload
        } else {
            data = try await client.run(Self.boundingBoxQuery(for: course, radiusKilometres: radiusKilometres))
        }

        if Self.holeCount(in: data) > 0 {
            storeInCache(data, for: course)
        }
        return data
    }

    // MARK: Queries

    /// Holes, playing areas and pin positions inside the course boundary or
    /// within 150 m of it. `nil` for courses mapped as a single node.
    static func boundaryQuery(for course: DiscoveredCourse) -> String? {
        let select: String
        switch course.osmType {
        case .way:
            select = "way(\(course.osmID))->.course;\n.course->.edges;"
        case .relation:
            select = "relation(\(course.osmID))->.course;\nway(r.course)->.edges;"
        case .node:
            return nil
        }
        return """
        [out:json][timeout:60];
        \(select)
        .course map_to_area->.inside;
        (
          way["golf"~"\(golfWayPattern)"](area.inside);
          way["golf"~"\(golfWayPattern)"](around.edges:150);
          node["golf"="pin"](area.inside);
          node["golf"="pin"](around.edges:150);
        );
        out geom;
        """
    }

    static func boundingBoxQuery(for course: DiscoveredCourse, radiusKilometres: Double) -> String {
        let bbox = OSMBoundingBox(
            centre: CLLocationCoordinate2D(latitude: course.coordinate.latitude, longitude: course.coordinate.longitude),
            radiusKilometres: radiusKilometres
        )
        let box = "\(bbox.south),\(bbox.west),\(bbox.north),\(bbox.east)"
        return """
        [out:json][timeout:60];
        (
          way["golf"~"\(golfWayPattern)"](\(box));
          node["golf"="pin"](\(box));
        );
        out geom;
        """
    }

    /// Number of `golf=hole` ways in a payload; 0 for anything unreadable.
    static func holeCount(in data: Data) -> Int {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = object["elements"] as? [[String: Any]]
        else { return 0 }
        return elements.filter { ($0["tags"] as? [String: String])?["golf"] == "hole" }.count
    }

    // MARK: Cache

    private func cacheURL(for course: DiscoveredCourse) -> URL? {
        cacheDirectory?.appendingPathComponent("\(Self.cacheVersion)-\(course.id).json", isDirectory: false)
    }

    /// A cached payload that is fresh and still has holes in it.
    private func cachedPayload(for course: DiscoveredCourse) -> Data? {
        guard let url = cacheURL(for: course),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < Self.cacheLifetime,
              let data = try? Data(contentsOf: url),
              Self.holeCount(in: data) > 0
        else { return nil }
        return data
    }

    private func storeInCache(_ data: Data, for course: DiscoveredCourse) {
        guard let url = cacheURL(for: course) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
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
