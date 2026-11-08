import Foundation
import CoreLocation
import OSLog

/// A golf course matched from OpenStreetMap that the app does not yet have
/// bundled or cached. Round setup uses these to populate the "Discover nearby"
/// section and search results; the import coordinator (Phase 2+) consumes
/// them to drive an on-device OSM download.
struct DiscoveredCourse: Identifiable, Equatable {
    enum OSMElementType: String, Equatable, Codable {
        case relation
        case way
        case node
    }

    /// Stable identity used to dedupe search/nearby results and to key
    /// imported-course caches: `"<osmType>-<osmID>"`.
    let id: String
    let name: String
    let coordinate: SwingPalCourse.Coordinate
    let osmID: Int64
    let osmType: OSMElementType
    let countryCode: String?
    let region: String?
    /// Distance from the user's location at discovery time. `nil` when the
    /// result came from a name search rather than a bbox query.
    let distanceKilometers: Double?
}

protocol OSMCourseDiscovering {
    /// Golf courses with `leisure=golf_course` tagged geometry within
    /// `radiusKilometres` of `coordinate`. Sorted ascending by distance.
    /// Returns an empty array when nothing matches; throws on transport
    /// or decoding failures.
    func nearbyCourses(
        around coordinate: CLLocationCoordinate2D,
        radiusKilometres: Double
    ) async throws -> [DiscoveredCourse]

    /// Free-text Nominatim search scoped to a single ISO 3166-1 alpha-2
    /// country code (`"AU"`, `"US"`, etc.). Returns at most ~20 results,
    /// ordered by Nominatim's own relevance ranking.
    func searchCourses(
        named query: String,
        countryCode: String
    ) async throws -> [DiscoveredCourse]
}

enum OSMCourseDiscoveryError: LocalizedError, Equatable {
    case networkUnavailable
    case rateLimited
    case invalidResponse
    case emptyQuery

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Couldn't reach OpenStreetMap. Check your connection and try again."
        case .rateLimited:
            return "OpenStreetMap is rate-limiting requests. Try again in a few seconds."
        case .invalidResponse:
            return "OpenStreetMap returned an unexpected response."
        case .emptyQuery:
            return "Type at least three characters to search."
        }
    }
}

/// Live discovery service that hits Overpass for nearby bbox lookups and
/// Nominatim for name-based searches. Both endpoints require a real
/// `User-Agent` header per OpenStreetMap usage policy.
struct LiveOSMCourseDiscovery: OSMCourseDiscovering {
    static let overpassEndpoint = URL(string: "https://overpass-api.de/api/interpreter")!
    static let nominatimEndpoint = URL(string: "https://nominatim.openstreetmap.org/search")!
    static let userAgent = "SwingPal/1.0 (https://swingpal.app)"

    private static let logger = Logger(subsystem: "com.swingpal.app", category: "OSMCourseDiscovery")

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func nearbyCourses(
        around coordinate: CLLocationCoordinate2D,
        radiusKilometres: Double
    ) async throws -> [DiscoveredCourse] {
        let bbox = OSMBoundingBox(centre: coordinate, radiusKilometres: radiusKilometres)
        let query = """
        [out:json][timeout:25];
        (
          way["leisure"="golf_course"](\(bbox.south),\(bbox.west),\(bbox.north),\(bbox.east));
          relation["leisure"="golf_course"](\(bbox.south),\(bbox.west),\(bbox.north),\(bbox.east));
        );
        out tags center;
        """

        let data = try await OverpassClient(session: session).run(query)
        let discoveries = try OverpassDiscoveryParser.parse(data: data, anchor: coordinate)
        return discoveries.sorted { lhs, rhs in
            (lhs.distanceKilometers ?? .infinity) < (rhs.distanceKilometers ?? .infinity)
        }
    }

    func searchCourses(
        named query: String,
        countryCode: String
    ) async throws -> [DiscoveredCourse] {
        let variants = CourseSearchQuery.variants(for: query)
        guard !variants.isEmpty else {
            throw OSMCourseDiscoveryError.emptyQuery
        }

        // Nominatim matches every word, so "Westgate golf club golf course"
        // or "Westgate Spotswood" find nothing when OpenStreetMap calls it
        // "Westgate Golf Course". Try the cleaned-up phrasings in turn, one
        // request a second (Nominatim's usage policy), until one hits.
        for (index, variant) in variants.enumerated() {
            if index > 0 {
                try await Task.sleep(for: .seconds(1.1))
            }
            let hits = try await nominatimSearch(variant, countryCode: countryCode)
            if !hits.isEmpty { return hits }
        }
        return []
    }

    private func nominatimSearch(_ text: String, countryCode: String) async throws -> [DiscoveredCourse] {
        var components = URLComponents(url: Self.nominatimEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "countrycodes", value: countryCode.lowercased()),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "addressdetails", value: "1"),
            URLQueryItem(name: "extratags", value: "1")
        ]
        guard let url = components?.url else {
            throw OSMCourseDiscoveryError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await Self.send(request: request, on: session)
        try Self.validate(response: response)
        return try NominatimSearchParser.parse(data: data)
    }

    private static func send(
        request: URLRequest,
        on session: URLSession
    ) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where error.code == .notConnectedToInternet
            || error.code == .timedOut
            || error.code == .cannotConnectToHost {
            throw OSMCourseDiscoveryError.networkUnavailable
        } catch {
            logger.warning("Discovery transport error: \(String(describing: error), privacy: .public)")
            throw OSMCourseDiscoveryError.networkUnavailable
        }
    }

    private static func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw OSMCourseDiscoveryError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300:
            return
        case 429, 503:
            throw OSMCourseDiscoveryError.rateLimited
        default:
            logger.warning("Discovery HTTP error: \(http.statusCode, privacy: .public)")
            throw OSMCourseDiscoveryError.invalidResponse
        }
    }
}

/// Turns what someone types into the phrasings Nominatim can match.
enum CourseSearchQuery {
    /// Words people add that OpenStreetMap names often don't carry.
    private static let venueWords: Set<String> = [
        "golf", "club", "course", "links", "country", "cc", "gc", "gcc", "the", "and", "&", "resort", "public"
    ]

    /// Ordered, de-duplicated search strings for `input`:
    /// 1. the distinctive words + "golf course"
    /// 2. the distinctive words + "golf"
    /// 3. each distinctive word + "golf course", in the order typed
    ///    (so "Westgate Spotswood" still finds Westgate).
    /// Empty when the input has nothing searchable.
    static func variants(for input: String) -> [String] {
        let words = input
            .lowercased()
            .replacingOccurrences(of: "[^\\p{L}\\p{N}&' ]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
        let core = words.filter { !venueWords.contains($0) }
        guard !core.isEmpty else {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            // Only venue words ("The Golf Club"): search it as typed.
            return trimmed.count >= 3 ? [trimmed] : []
        }
        let joined = core.joined(separator: " ")
        var result = ["\(joined) golf course", "\(joined) golf"]
        if core.count > 1 {
            result += core.filter { $0.count >= 4 }.map { "\($0) golf course" }
        }
        var seen = Set<String>()
        return Array(result.filter { seen.insert($0).inserted }.prefix(4))
    }
}

/// Lat/lon bounding box derived from a centre point and a radius. Uses a
/// flat-earth approximation that's accurate to well within a kilometre at
/// the radii we care about (~10 km), which is fine for an Overpass bbox.
struct OSMBoundingBox: Equatable {
    let south: Double
    let west: Double
    let north: Double
    let east: Double

    init(centre: CLLocationCoordinate2D, radiusKilometres: Double) {
        let latitudeDelta = radiusKilometres / 111.0
        let longitudeScale = max(cos(centre.latitude * .pi / 180), 0.1)
        let longitudeDelta = radiusKilometres / (111.0 * longitudeScale)
        south = centre.latitude - latitudeDelta
        north = centre.latitude + latitudeDelta
        west = centre.longitude - longitudeDelta
        east = centre.longitude + longitudeDelta
    }
}

/// Parses Overpass API JSON (`out tags center;`) into `DiscoveredCourse`
/// values. Pure function, no I/O — exposed as `enum` so tests can hit it
/// with bundled fixtures without touching the network.
enum OverpassDiscoveryParser {
    private struct Response: Decodable {
        let elements: [Element]
    }

    private struct Element: Decodable {
        let type: String
        let id: Int64
        let tags: [String: String]?
        let center: Centre?
        let lat: Double?
        let lon: Double?
    }

    private struct Centre: Decodable {
        let lat: Double
        let lon: Double
    }

    static func parse(data: Data, anchor: CLLocationCoordinate2D) throws -> [DiscoveredCourse] {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw OSMCourseDiscoveryError.invalidResponse
        }

        var seenIDs: Set<String> = []
        var discoveries: [DiscoveredCourse] = []
        for element in response.elements {
            guard let tags = element.tags,
                  let rawName = tags["name"] ?? tags["golf:course:name"],
                  !rawName.isEmpty,
                  let lat = element.center?.lat ?? element.lat,
                  let lon = element.center?.lon ?? element.lon,
                  let osmType = DiscoveredCourse.OSMElementType(rawValue: element.type)
            else { continue }

            let id = "\(element.type)-\(element.id)"
            guard seenIDs.insert(id).inserted else { continue }

            let distance = greatCircleKilometres(
                from: anchor,
                to: CLLocationCoordinate2D(latitude: lat, longitude: lon)
            )
            discoveries.append(
                DiscoveredCourse(
                    id: id,
                    name: rawName,
                    coordinate: .init(latitude: lat, longitude: lon),
                    osmID: element.id,
                    osmType: osmType,
                    countryCode: tags["addr:country"]?.uppercased(),
                    region: tags["addr:state"] ?? tags["addr:province"],
                    distanceKilometers: distance
                )
            )
        }
        return discoveries
    }
}

/// Parses Nominatim `/search` JSON arrays into `DiscoveredCourse` values.
enum NominatimSearchParser {
    private struct Hit: Decodable {
        let osm_type: String
        let osm_id: Int64
        let lat: String
        let lon: String
        let display_name: String
        let name: String?
        let address: Address?
        let kind: String?
        let type: String?

        private enum CodingKeys: String, CodingKey {
            case osm_type
            case osm_id
            case lat
            case lon
            case display_name
            case name
            case address
            case kind = "class"
            case type
        }
    }

    private struct Address: Decodable {
        let country_code: String?
        let state: String?
    }

    static func parse(data: Data) throws -> [DiscoveredCourse] {
        let hits: [Hit]
        do {
            hits = try JSONDecoder().decode([Hit].self, from: data)
        } catch {
            throw OSMCourseDiscoveryError.invalidResponse
        }

        var seenIDs: Set<String> = []
        var discoveries: [DiscoveredCourse] = []
        for hit in hits {
            // Nominatim happily returns prefix matches across many feature
            // types (e.g. "Royal Melbourne" matches the suburb too). We only
            // keep golf-tagged hits to avoid suggesting roads/towns.
            let isGolf = (hit.kind == "leisure" && hit.type == "golf_course")
                || hit.display_name.localizedCaseInsensitiveContains("golf")
            guard isGolf,
                  let lat = Double(hit.lat),
                  let lon = Double(hit.lon),
                  let osmType = DiscoveredCourse.OSMElementType(rawValue: hit.osm_type)
            else { continue }

            let id = "\(hit.osm_type)-\(hit.osm_id)"
            guard seenIDs.insert(id).inserted else { continue }

            let resolvedName: String
            if let trimmed = hit.name?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty {
                resolvedName = trimmed
            } else if let leading = hit.display_name.split(separator: ",").first {
                resolvedName = String(leading).trimmingCharacters(in: .whitespaces)
            } else {
                resolvedName = hit.display_name
            }

            discoveries.append(
                DiscoveredCourse(
                    id: id,
                    name: resolvedName,
                    coordinate: .init(latitude: lat, longitude: lon),
                    osmID: hit.osm_id,
                    osmType: osmType,
                    countryCode: hit.address?.country_code?.uppercased(),
                    region: hit.address?.state,
                    distanceKilometers: nil
                )
            )
        }
        return discoveries
    }
}

private func greatCircleKilometres(
    from a: CLLocationCoordinate2D,
    to b: CLLocationCoordinate2D
) -> Double {
    let earthRadiusKm = 6371.0
    let lat1 = a.latitude * .pi / 180
    let lat2 = b.latitude * .pi / 180
    let dLat = (b.latitude - a.latitude) * .pi / 180
    let dLon = (b.longitude - a.longitude) * .pi / 180
    let h = sin(dLat / 2) * sin(dLat / 2)
        + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
    return 2 * earthRadiusKm * asin(min(1.0, sqrt(h)))
}
