import Foundation
import CoreLocation
import CryptoKit

/// On-device port of `tmp/convert_osm_to_course.py`. Takes the raw Overpass
/// JSON returned by `OSMCourseGeometryFetching` and produces a
/// `SwingPalCourse` ready for the live round.
///
/// The algorithm mirrors the Python ingestion script:
/// 1. Collect every `golf=hole` way as the tee→green centerline.
/// 2. Assign each `golf=tee/fairway/green/bunker/water_hazard` polygon to
///    the nearest hole's centerline (capped at `maxAssignmentMeters` so we
///    don't pull stray features from neighbouring courses).
/// 3. Orient each hole so the runtime picks the correct primary tee and
///    primary green (tee end = whichever endpoint has the closest tee
///    polygon; greens sort from the green end).
/// 4. Emit a `SwingPalCourse` with deterministic UUID v5s seeded by the
///    course's slug + element label.
///
/// Differences from the Python build-time pipeline:
/// - No per-course `course_filter` predicate. Multi-course bboxes are
///   handled with a best-effort `golf:course:name` filter when the
///   discovered course name carries a course-specific qualifier.
/// - No `par_overrides`. Defaults to OSM-tagged `par`, falling back to 4.
/// - No manual `tees` list. We emit synthetic Championship/Member/Forward
///   yardages estimated from the tee→green geometry (×1.05 for tee depth).
enum RuntimeOSMCourseConverter {
    static let maxAssignmentMeters: Double = 80
    static let minHolesForCourse: Int = 9
    static let maxHolesForCourse: Int = 18

    enum ConversionError: LocalizedError, Equatable {
        case invalidRawData
        case noHolesDetected
        case insufficientHoles(found: Int)

        var errorDescription: String? {
            switch self {
            case .invalidRawData:
                return "OpenStreetMap returned an unreadable response."
            case .noHolesDetected:
                return "OpenStreetMap doesn't have any tagged holes for this course yet."
            case .insufficientHoles(let found):
                return "Only \(found) holes detected; we need at least \(minHolesForCourse)."
            }
        }
    }

    static func convert(
        rawOSM data: Data,
        for discovered: DiscoveredCourse
    ) throws -> SwingPalCourse {
        let payload: OverpassGeometryPayload
        do {
            payload = try JSONDecoder().decode(OverpassGeometryPayload.self, from: data)
        } catch {
            throw ConversionError.invalidRawData
        }

        // Collect holes + features.
        let holeWays = payload.elements.compactMap(HoleWay.init(element:))
        let featureWays = payload.elements.compactMap(FeatureWay.init(element:))

        guard !holeWays.isEmpty else {
            throw ConversionError.noHolesDetected
        }

        // Multi-course properties (e.g. Royal Melbourne West/East): if every
        // hole carries a `golf:course:name` and the discovered name is more
        // specific than the bare club, prefer holes whose course-name tag
        // matches. Falls back to the full set if the filter is empty.
        let scopedHoles = filterHolesByCourseName(holeWays, discoveredName: discovered.name)

        let orderedHoles = orderHoles(scopedHoles, around: discovered.coordinate)
        guard orderedHoles.count >= minHolesForCourse else {
            throw ConversionError.insufficientHoles(found: orderedHoles.count)
        }

        let slug = stableSlug(for: discovered)
        let assignments = assignFeatures(featureWays, to: orderedHoles)

        var holesPayload: [SwingPalCourse.Hole] = []
        for (index, hole) in orderedHoles.enumerated() {
            let holeNumber = index + 1
            let records = assignments[hole.id] ?? []
            let features = buildFeatures(
                forHoleNumber: holeNumber,
                hole: hole,
                records: records,
                slug: slug
            )
            let par = parseHolePar(from: hole.tags) ?? 4
            holesPayload.append(
                SwingPalCourse.Hole(
                    id: deterministicUUID(slug: slug, label: "hole/\(holeNumber)"),
                    number: holeNumber,
                    par: par,
                    features: features
                )
            )
        }

        let totalPar = holesPayload.reduce(0) { $0 + $1.par }
        let allCoordinates = holesPayload
            .flatMap(\.features)
            .flatMap(\.coordinates)
        let courseCentroid = centroid(of: allCoordinates) ?? discovered.coordinate

        let tees = synthesisedTees(slug: slug, holes: holesPayload)

        return SwingPalCourse(
            id: deterministicUUID(slug: slug, label: "course"),
            name: discovered.name,
            distanceKilometers: discovered.distanceKilometers ?? 0,
            coordinate: courseCentroid,
            holeCount: holesPayload.count,
            par: totalPar,
            sourceReferences: [
                SwingPalCourse.SourceReference(
                    id: deterministicUUID(slug: slug, label: "source/osm"),
                    kind: .openStreetMap,
                    externalID: "osm-\(discovered.osmType.rawValue)-\(discovered.osmID)",
                    note: "Imported on device from OpenStreetMap via Overpass API."
                )
            ],
            quality: SwingPalCourse.QualitySnapshot(
                overallConfidence: .provisional,
                geometryConfidence: .provisional,
                metadataConfidence: .provisional
            ),
            community: SwingPalCourse.CommunityState(access: .open, correctionCount: 0),
            tees: tees,
            holes: holesPayload
        )
    }

    // MARK: - Decoding

    private struct OverpassGeometryPayload: Decodable {
        let elements: [Element]
    }

    private struct Element: Decodable {
        let type: String
        let id: Int64
        let tags: [String: String]?
        let geometry: [GeometryPoint]?
        let center: GeometryPoint?
    }

    private struct GeometryPoint: Decodable {
        let lat: Double
        let lon: Double
    }

    private struct HoleWay {
        let id: Int64
        let tags: [String: String]
        let geometry: [SwingPalCourse.Coordinate]

        init?(element: Element) {
            guard element.tags?["golf"] == "hole" else { return nil }
            guard let geometry = element.geometry, geometry.count >= 2 else { return nil }
            self.id = element.id
            self.tags = element.tags ?? [:]
            self.geometry = geometry.map { .init(latitude: $0.lat, longitude: $0.lon) }
        }
    }

    private struct FeatureWay {
        let id: Int64
        let kind: SwingPalCourse.Hole.FeatureKind
        let geometry: [SwingPalCourse.Coordinate]

        init?(element: Element) {
            guard let golf = element.tags?["golf"] else { return nil }
            guard let kind = featureKind(forOSMTag: golf) else { return nil }
            guard let geometry = element.geometry, !geometry.isEmpty else { return nil }
            self.id = element.id
            self.kind = kind
            self.geometry = geometry.map { .init(latitude: $0.lat, longitude: $0.lon) }
        }
    }

    private static func featureKind(forOSMTag tag: String) -> SwingPalCourse.Hole.FeatureKind? {
        switch tag {
        case "tee":
            return .tee
        case "fairway":
            return .fairway
        case "green":
            return .green
        case "bunker":
            return .bunker
        case "water_hazard":
            return .water
        default:
            return nil
        }
    }

    // MARK: - Hole filtering / ordering

    private static func filterHolesByCourseName(
        _ holes: [HoleWay],
        discoveredName: String
    ) -> [HoleWay] {
        // If no holes carry course-name tags, nothing to filter on.
        let withCourseName = holes.filter { $0.tags["golf:course:name"] != nil }
        guard !withCourseName.isEmpty else { return holes }

        let qualifier = courseQualifier(in: discoveredName)
        guard let qualifier else { return holes }

        let matched = holes.filter { hole in
            guard let courseName = hole.tags["golf:course:name"] else { return false }
            return courseName.lowercased().contains(qualifier.lowercased())
        }
        return matched.isEmpty ? holes : matched
    }

    /// Pulls a course-specific qualifier out of a discovered course name -
    /// e.g. "Royal Melbourne (West Course)" → "West Course". Returns `nil`
    /// when the name carries no qualifier, in which case we don't try to
    /// scope the hole set.
    private static func courseQualifier(in name: String) -> String? {
        if let openParen = name.firstIndex(of: "("),
           let closeParen = name[openParen...].firstIndex(of: ")") {
            let inside = name[name.index(after: openParen)..<closeParen]
            let trimmed = inside.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    /// Order holes 1..N. We sort by the OSM `ref` tag interpreted as an
    /// integer (`"1"`, `"10W"` etc); ties / non-numeric refs fall back to
    /// distance from the discovered course centre, then by OSM id.
    private static func orderHoles(
        _ holes: [HoleWay],
        around centre: SwingPalCourse.Coordinate
    ) -> [HoleWay] {
        let centreCL = CLLocationCoordinate2D(
            latitude: centre.latitude,
            longitude: centre.longitude
        )

        func sortKey(_ hole: HoleWay) -> (Int, Double, Int64) {
            let refNumber = numericPrefix(of: hole.tags["ref"] ?? "") ?? Int.max
            let centreOfHole = CLLocationCoordinate2D(
                latitude: hole.geometry.first?.latitude ?? centre.latitude,
                longitude: hole.geometry.first?.longitude ?? centre.longitude
            )
            let distance = haversineMeters(centreCL, centreOfHole)
            return (refNumber, distance, hole.id)
        }

        let sorted = holes.sorted { lhs, rhs in
            let (lhsKey0, lhsKey1, lhsKey2) = sortKey(lhs)
            let (rhsKey0, rhsKey1, rhsKey2) = sortKey(rhs)
            if lhsKey0 != rhsKey0 { return lhsKey0 < rhsKey0 }
            if lhsKey1 != rhsKey1 { return lhsKey1 < rhsKey1 }
            return lhsKey2 < rhsKey2
        }

        // Cap at 18: if a bbox snags a neighbouring 9-hole loop, we want
        // the 18 closest-to-centre holes, not 27 muddled together.
        return Array(sorted.prefix(maxHolesForCourse))
    }

    private static func numericPrefix(of ref: String) -> Int? {
        var digits = ""
        for character in ref {
            if character.isNumber {
                digits.append(character)
            } else if !digits.isEmpty {
                break
            }
        }
        return Int(digits)
    }

    private static func parseHolePar(from tags: [String: String]) -> Int? {
        guard let raw = tags["par"], let value = Int(raw), (3...5).contains(value) else {
            return nil
        }
        return value
    }

    // MARK: - Feature → hole assignment

    private static func assignFeatures(
        _ features: [FeatureWay],
        to holes: [HoleWay]
    ) -> [Int64: [FeatureWay]] {
        guard !holes.isEmpty else { return [:] }

        var assignments: [Int64: [FeatureWay]] = [:]
        for feature in features {
            guard let centroid = centroid(of: feature.geometry) else { continue }

            var bestID: Int64?
            var bestDistance = Double.infinity
            for hole in holes {
                let distance = closestSegmentDistanceMeters(centroid, polyline: hole.geometry)
                if distance < bestDistance {
                    bestDistance = distance
                    bestID = hole.id
                }
            }

            guard let resolved = bestID, bestDistance <= maxAssignmentMeters else { continue }
            assignments[resolved, default: []].append(feature)
        }
        return assignments
    }

    // MARK: - Per-hole feature ordering + UUIDs

    private static func buildFeatures(
        forHoleNumber holeNumber: Int,
        hole: HoleWay,
        records: [FeatureWay],
        slug: String
    ) -> [SwingPalCourse.Hole.Feature] {
        let endA = hole.geometry.first ?? .init(latitude: 0, longitude: 0)
        let endB = hole.geometry.last ?? endA

        let teeRecords = records.filter { $0.kind == .tee }
        let greenRecords = records.filter { $0.kind == .green }
        let fairwayRecords = records.filter { $0.kind == .fairway }
        let bunkerRecords = records.filter { $0.kind == .bunker }
        let waterRecords = records.filter { $0.kind == .water }

        let endATees = minDistanceMeters(from: endA, to: teeRecords)
        let endBTees = minDistanceMeters(from: endB, to: teeRecords)
        let teeEnd: SwingPalCourse.Coordinate
        let greenEnd: SwingPalCourse.Coordinate
        if endATees <= endBTees {
            teeEnd = endA
            greenEnd = endB
        } else {
            teeEnd = endB
            greenEnd = endA
        }

        let sortedTees = teeRecords.sorted {
            distanceFromTee(record: $0, end: teeEnd) < distanceFromTee(record: $1, end: teeEnd)
        }
        let sortedGreens = greenRecords.sorted {
            distanceFromTee(record: $0, end: greenEnd) < distanceFromTee(record: $1, end: greenEnd)
        }
        let sortedBunkers = bunkerRecords.sorted { $0.geometry.count > $1.geometry.count }

        let ordered: [FeatureWay] = sortedTees + fairwayRecords + sortedGreens + sortedBunkers + waterRecords

        var features: [SwingPalCourse.Hole.Feature] = []
        var teeIndex = 0
        var bunkerIndex = 0
        for record in ordered {
            let label: String
            switch record.kind {
            case .tee:
                teeIndex += 1
                label = "Tee box \(teeIndex)"
            case .fairway:
                label = "Fairway corridor"
            case .green:
                label = "Green"
            case .bunker:
                bunkerIndex += 1
                label = "Bunker \(bunkerIndex)"
            case .water:
                label = "Water hazard"
            case .layup:
                label = "Layup"
            }
            features.append(
                SwingPalCourse.Hole.Feature(
                    id: deterministicUUID(
                        slug: slug,
                        label: "hole/\(holeNumber)/\(record.kind.rawValue)/\(features.count)"
                    ),
                    kind: record.kind,
                    label: label,
                    coordinates: record.geometry
                )
            )
        }
        return features
    }

    private static func distanceFromTee(
        record: FeatureWay,
        end: SwingPalCourse.Coordinate
    ) -> Double {
        guard let centroid = centroid(of: record.geometry) else { return .infinity }
        return haversineMeters(
            CLLocationCoordinate2D(latitude: end.latitude, longitude: end.longitude),
            CLLocationCoordinate2D(latitude: centroid.latitude, longitude: centroid.longitude)
        )
    }

    private static func minDistanceMeters(
        from end: SwingPalCourse.Coordinate,
        to records: [FeatureWay]
    ) -> Double {
        guard !records.isEmpty else { return .infinity }
        return records
            .compactMap { centroid(of: $0.geometry) }
            .map { centroid in
                haversineMeters(
                    CLLocationCoordinate2D(latitude: end.latitude, longitude: end.longitude),
                    CLLocationCoordinate2D(latitude: centroid.latitude, longitude: centroid.longitude)
                )
            }
            .min() ?? .infinity
    }

    // MARK: - Synthesised tee yardages

    private static func synthesisedTees(
        slug: String,
        holes: [SwingPalCourse.Hole]
    ) -> [SwingPalCourse.Tee] {
        let teeToGreen = holes.compactMap { hole -> Double? in
            let tees = hole.features.filter { $0.kind == .tee }.flatMap(\.coordinates)
            let greens = hole.features.filter { $0.kind == .green }.flatMap(\.coordinates)
            guard let teeCentroid = centroid(of: tees),
                  let greenCentroid = centroid(of: greens) else {
                return nil
            }
            return haversineMeters(
                CLLocationCoordinate2D(latitude: teeCentroid.latitude, longitude: teeCentroid.longitude),
                CLLocationCoordinate2D(latitude: greenCentroid.latitude, longitude: greenCentroid.longitude)
            )
        }
        let totalMeters = teeToGreen.reduce(0, +)
        let memberMeters = totalMeters * 1.05
        let memberYards = max(0, Int((memberMeters * 1.0936).rounded()))

        // Spread Championship/Forward around Member by ±5%.
        let championshipYards = Int(Double(memberYards) * 1.05)
        let forwardYards = Int(Double(memberYards) * 0.92)

        return [
            .init(
                id: deterministicUUID(slug: slug, label: "tee/championship"),
                name: "Championship",
                yards: max(championshipYards, 4500)
            ),
            .init(
                id: deterministicUUID(slug: slug, label: "tee/member"),
                name: "Member",
                yards: max(memberYards, 4200)
            ),
            .init(
                id: deterministicUUID(slug: slug, label: "tee/forward"),
                name: "Forward",
                yards: max(forwardYards, 3800)
            )
        ]
    }

    // MARK: - Helpers

    private static func stableSlug(for discovered: DiscoveredCourse) -> String {
        // Mirrors the Python script's slug naming so deterministic UUIDs
        // line up across the build-time and runtime pipelines wherever
        // possible.
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
        return slug.isEmpty ? "osm-\(discovered.osmType.rawValue)-\(discovered.osmID)" : slug
    }

    static func deterministicUUID(slug: String, label: String) -> UUID {
        DeterministicUUID.v5(
            namespace: DeterministicUUID.urlNamespace,
            name: "swingpal/courses/\(slug)/\(label)"
        )
    }
}

// MARK: - Geometry helpers

extension RuntimeOSMCourseConverter {
    static func centroid(of coordinates: [SwingPalCourse.Coordinate]) -> SwingPalCourse.Coordinate? {
        guard !coordinates.isEmpty else { return nil }
        let lat = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
        let lon = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
        return .init(latitude: lat, longitude: lon)
    }

    static func haversineMeters(
        _ a: CLLocationCoordinate2D,
        _ b: CLLocationCoordinate2D
    ) -> Double {
        let earthRadiusMeters = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusMeters * asin(min(1.0, sqrt(h)))
    }

    /// Closest distance in metres from `point` to a polyline. Uses a flat-
    /// earth projection scaled to the segment's reference latitude — fine
    /// for sub-kilometre golf-hole distances at any latitude we care about.
    static func closestSegmentDistanceMeters(
        _ point: SwingPalCourse.Coordinate,
        polyline: [SwingPalCourse.Coordinate]
    ) -> Double {
        guard polyline.count >= 2 else {
            guard let only = polyline.first else { return .infinity }
            return haversineMeters(
                CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                CLLocationCoordinate2D(latitude: only.latitude, longitude: only.longitude)
            )
        }

        var best = Double.infinity
        for index in 0..<(polyline.count - 1) {
            let a = polyline[index]
            let b = polyline[index + 1]
            let distance = pointToSegmentMeters(point, a: a, b: b)
            if distance < best { best = distance }
        }
        return best
    }

    private static func pointToSegmentMeters(
        _ p: SwingPalCourse.Coordinate,
        a: SwingPalCourse.Coordinate,
        b: SwingPalCourse.Coordinate
    ) -> Double {
        let refLat = (a.latitude + b.latitude) / 2
        let cosLat = max(cos(refLat * .pi / 180), 0.1)

        func toLocal(_ coordinate: SwingPalCourse.Coordinate) -> (x: Double, y: Double) {
            let x = (coordinate.longitude - a.longitude) * 111_111 * cosLat
            let y = (coordinate.latitude - a.latitude) * 111_111
            return (x, y)
        }

        let pa = (x: 0.0, y: 0.0)
        let pb = toLocal(b)
        let pp = toLocal(p)

        let dx = pb.x - pa.x
        let dy = pb.y - pa.y
        if dx == 0 && dy == 0 {
            return hypot(pp.x - pa.x, pp.y - pa.y)
        }

        let t = max(0.0, min(1.0, ((pp.x - pa.x) * dx + (pp.y - pa.y) * dy) / (dx * dx + dy * dy)))
        let cx = pa.x + t * dx
        let cy = pa.y + t * dy
        return hypot(pp.x - cx, pp.y - cy)
    }
}

// MARK: - UUID v5

/// Deterministic UUID v5 generation, matching Python's
/// `uuid.uuid5(NAMESPACE_URL, name)` so the runtime converter produces
/// identical IDs to the build-time ingestion script for the same input.
enum DeterministicUUID {
    static let urlNamespace: UUID = UUID(uuidString: "6BA7B811-9DAD-11D1-80B4-00C04FD430C8")!

    static func v5(namespace: UUID, name: String) -> UUID {
        let namespaceBytes = withUnsafeBytes(of: namespace.uuid) { Array($0) }
        var hasher = Insecure.SHA1()
        hasher.update(data: Data(namespaceBytes))
        hasher.update(data: Data(name.utf8))
        var digest = Array(hasher.finalize())

        // Set version (v5) and variant bits per RFC 4122.
        digest[6] = (digest[6] & 0x0F) | 0x50
        digest[8] = (digest[8] & 0x3F) | 0x80

        let uuidBytes: uuid_t = (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        )
        return UUID(uuid: uuidBytes)
    }
}
