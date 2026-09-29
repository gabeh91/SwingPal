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
        /// Hole numbers say the course has `expected` holes but some aren't mapped.
        case incompleteCourse(expected: Int, missing: [Int])

        var errorDescription: String? {
            switch self {
            case .invalidRawData:
                return "OpenStreetMap returned an unreadable response."
            case .noHolesDetected:
                return "OpenStreetMap doesn't have this course's holes mapped yet, so there's nothing to build distances from."
            case .insufficientHoles(let found):
                return "OpenStreetMap only has \(found) of this course's holes mapped; we need at least \(minHolesForCourse)."
            case .incompleteCourse(let expected, let missing):
                let list = missing.map(String.init).joined(separator: ", ")
                return "OpenStreetMap has \(expected - missing.count) of this course's \(expected) holes mapped (missing \(missing.count == 1 ? "hole" : "holes") \(list))."
            }
        }
    }

    /// Radius of a green drawn where OpenStreetMap has none (a typical green is ~25 m across).
    static let estimatedGreenRadiusMeters: Double = 12
    static let estimatedLabelSuffix = "(estimated)"
    /// Label prefix of each half of a double green, followed by the other hole's number and ")".
    static let sharedGreenLabelPrefix = "Green (shared with hole "
    /// A flag this close to a mapped green (or inside it) is on that green.
    static let flagOnGreenToleranceMeters: Double = 3
    /// Two flags on one green must be at least this far apart to split it.
    static let minimumFlagSeparationMeters: Double = 4
    /// A golf=pin node within this distance of a hole line's green end is that hole's flag.
    static let pinSnapMeters: Double = 30

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
        let pins: [SwingPalCourse.Coordinate] = payload.elements.compactMap { element in
            guard element.tags?["golf"] == "pin", let lat = element.lat, let lon = element.lon else { return nil }
            return .init(latitude: lat, longitude: lon)
        }

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
        if let gap = missingHoleNumbers(in: orderedHoles) {
            throw ConversionError.incompleteCourse(expected: gap.expected, missing: gap.missing)
        }

        let slug = stableSlug(for: discovered)
        var assignments = assignFeatures(featureWays, to: orderedHoles)
        shareDoubleGreens(
            holes: orderedHoles,
            assignments: &assignments,
            greens: featureWays.filter { $0.kind == .green },
            pins: pins
        )

        var holesPayload: [SwingPalCourse.Hole] = []
        for (index, hole) in orderedHoles.enumerated() {
            let holeNumber = index + 1
            let records = assignments[hole.id] ?? []
            let features = buildFeatures(
                forHoleNumber: holeNumber,
                hole: hole,
                records: records,
                pins: pins,
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
            distanceKilometers: discovered.distanceKilometers,
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
        let lat: Double?
        let lon: Double?
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
        var isEstimated = false
        /// Set when this green is part of a double green shared with another hole.
        var sharedWithHole: Int?

        init(id: Int64, kind: SwingPalCourse.Hole.FeatureKind, geometry: [SwingPalCourse.Coordinate], sharedWithHole: Int?) {
            self.id = id
            self.kind = kind
            self.geometry = geometry
            self.sharedWithHole = sharedWithHole
        }

        /// A round shape standing in for a polygon OpenStreetMap doesn't have.
        init(estimated kind: SwingPalCourse.Hole.FeatureKind, id: Int64, around centre: SwingPalCourse.Coordinate, radiusMeters: Double) {
            self.id = id
            self.kind = kind
            self.isEstimated = true
            let cosLat = max(cos(centre.latitude * .pi / 180), 0.1)
            let ring = (0..<16).map { step -> SwingPalCourse.Coordinate in
                let angle = Double(step) / 16 * 2 * .pi
                return .init(
                    latitude: centre.latitude + sin(angle) * radiusMeters / 110_540,
                    longitude: centre.longitude + cos(angle) * radiusMeters / (111_320 * cosLat)
                )
            }
            self.geometry = ring + [ring[0]]
        }

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
        case "water_hazard", "lateral_water_hazard":
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

    /// When every hole carries a numeric `ref`, the course size those numbers
    /// imply (9 or 18) and which of them aren't mapped. `nil` when nothing is
    /// missing or the refs can't tell.
    private static func missingHoleNumbers(in holes: [HoleWay]) -> (expected: Int, missing: [Int])? {
        let refs = holes.compactMap { numericPrefix(of: $0.tags["ref"] ?? "") }
        guard refs.count == holes.count, let highest = refs.max(), highest <= maxHolesForCourse else { return nil }
        let expected = highest <= 9 ? 9 : 18
        let missing = (1...expected).filter { !refs.contains($0) }
        return missing.isEmpty ? nil : (expected, missing)
    }

    private static func nearest(
        to point: SwingPalCourse.Coordinate,
        in candidates: [SwingPalCourse.Coordinate],
        within limit: Double
    ) -> SwingPalCourse.Coordinate? {
        let origin = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        return candidates
            .map { ($0, haversineMeters(origin, CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude))) }
            .filter { $0.1 <= limit }
            .min { $0.1 < $1.1 }?
            .0
    }

    /// Plain-language notes on what the converter had to work out for
    /// itself: greens or tees it estimated, and double greens it split
    /// between two holes.
    static func importNotes(for course: SwingPalCourse) -> [String] {
        course.holes.flatMap { hole in
            hole.features.compactMap { feature -> String? in
                if feature.label.hasSuffix(estimatedLabelSuffix) {
                    return "Hole \(hole.number): \(feature.kind == .green ? "green" : "tee") estimated, as OpenStreetMap has none drawn. Distances to it are approximate."
                }
                if let other = sharedGreenPartner(of: feature), other > hole.number {
                    return "Holes \(hole.number) and \(other) share a double green. Each hole measures to its own half, split between the two flags."
                }
                return nil
            }
        }
    }

    /// The other hole's number when `feature` is half of a double green.
    static func sharedGreenPartner(of feature: SwingPalCourse.Hole.Feature) -> Int? {
        guard feature.kind == .green, feature.label.hasPrefix(sharedGreenLabelPrefix) else { return nil }
        return Int(feature.label.dropFirst(sharedGreenLabelPrefix.count).prefix { $0.isNumber })
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
        pins: [SwingPalCourse.Coordinate] = [],
        slug: String
    ) -> [SwingPalCourse.Hole.Feature] {
        var teeRecords = records.filter { $0.kind == .tee }
        var greenRecords = records.filter { $0.kind == .green }
        let fairwayRecords = records.filter { $0.kind == .fairway }
        let bunkerRecords = records.filter { $0.kind == .bunker }
        let waterRecords = records.filter { $0.kind == .water }

        let (teeEnd, greenEnd) = ends(of: hole, records: records)

        // Fill a missing green or tee from what the hole does have, so one
        // unmapped polygon doesn't sink the whole course. Estimated shapes are
        // labelled, and the import reports them.
        if greenRecords.isEmpty {
            let pin = nearest(to: greenEnd, in: pins, within: pinSnapMeters) ?? greenEnd
            greenRecords = [FeatureWay(estimated: .green, id: -hole.id, around: pin, radiusMeters: estimatedGreenRadiusMeters)]
        }
        if teeRecords.isEmpty {
            teeRecords = [FeatureWay(estimated: .tee, id: -hole.id - 1, around: teeEnd, radiusMeters: 5)]
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
                label = record.isEstimated ? "Tee \(estimatedLabelSuffix)" : "Tee box \(teeIndex)"
            case .fairway:
                label = "Fairway corridor"
            case .green:
                if record.isEstimated {
                    label = "Green \(estimatedLabelSuffix)"
                } else if let other = record.sharedWithHole {
                    label = "\(sharedGreenLabelPrefix)\(other))"
                } else {
                    label = "Green"
                }
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

    /// The tee and green ends of a hole line: the tee end is the one nearest
    /// a tee polygon; failing that, the one farthest from a green; failing
    /// that, the way's first point (OpenStreetMap draws golf=hole from tee to
    /// green).
    private static func ends(
        of hole: HoleWay,
        records: [FeatureWay]
    ) -> (tee: SwingPalCourse.Coordinate, green: SwingPalCourse.Coordinate) {
        let endA = hole.geometry.first ?? .init(latitude: 0, longitude: 0)
        let endB = hole.geometry.last ?? endA
        let tees = records.filter { $0.kind == .tee }
        let greens = records.filter { $0.kind == .green }
        let aIsTee: Bool
        if !tees.isEmpty {
            aIsTee = minDistanceMeters(from: endA, to: tees) <= minDistanceMeters(from: endB, to: tees)
        } else if !greens.isEmpty {
            aIsTee = minDistanceMeters(from: endA, to: greens) >= minDistanceMeters(from: endB, to: greens)
        } else {
            aIsTee = true
        }
        return aIsTee ? (endA, endB) : (endB, endA)
    }

    /// Where a hole's flag is: the mapped pin nearest the green end of its
    /// line, or the green end itself.
    private static func flag(
        of hole: HoleWay,
        records: [FeatureWay],
        pins: [SwingPalCourse.Coordinate]
    ) -> SwingPalCourse.Coordinate {
        let greenEnd = ends(of: hole, records: records).green
        return nearest(to: greenEnd, in: pins, within: pinSnapMeters) ?? greenEnd
    }

    // MARK: - Double greens

    /// A double green (one putting surface serving two holes) is drawn once
    /// in OpenStreetMap, so it's assigned to whichever hole line is nearest
    /// and the other hole looks green-less. For each hole without a green
    /// whose flag is on a mapped green, split that green between the two
    /// flags, so each hole gets its own half and measures to it. A green no
    /// hole claimed is simply given to the hole.
    private static func shareDoubleGreens(
        holes: [HoleWay],
        assignments: inout [Int64: [FeatureWay]],
        greens: [FeatureWay],
        pins: [SwingPalCourse.Coordinate]
    ) {
        for (index, hole) in holes.enumerated() {
            let records = assignments[hole.id] ?? []
            guard !records.contains(where: { $0.kind == .green }) else { continue }
            let holeFlag = flag(of: hole, records: records, pins: pins)
            guard let green = greens.first(where: {
                ringContains($0.geometry, holeFlag)
                    || distanceToRingMeters(holeFlag, ring: $0.geometry) <= flagOnGreenToleranceMeters
            }) else { continue }

            let owner = holes.enumerated().first { other in
                other.element.id != hole.id
                    && (assignments[other.element.id] ?? []).contains { $0.kind == .green && $0.id == green.id }
            }
            guard let owner,
                  let ownerRecords = assignments[owner.element.id],
                  let ownerGreenIndex = ownerRecords.firstIndex(where: { $0.kind == .green && $0.id == green.id })
            else {
                assignments[hole.id, default: []].append(green)
                continue
            }

            let (ownerIndex, ownerHole) = (owner.offset, owner.element)
            let ownerGreen = ownerRecords[ownerGreenIndex]
            let ownerFlag = flag(of: ownerHole, records: ownerRecords, pins: pins)
            // Both holes found the same flag: this hole's own green is just
            // unmapped, not shared. Leave it to be estimated.
            guard haversineMeters(
                CLLocationCoordinate2D(latitude: ownerFlag.latitude, longitude: ownerFlag.longitude),
                CLLocationCoordinate2D(latitude: holeFlag.latitude, longitude: holeFlag.longitude)
            ) >= minimumFlagSeparationMeters else { continue }
            let halves = split(ownerGreen.geometry, between: ownerFlag, and: holeFlag)
            assignments[ownerHole.id]?[ownerGreenIndex] = FeatureWay(
                id: green.id, kind: .green,
                geometry: halves?.nearA ?? ownerGreen.geometry,
                sharedWithHole: index + 1
            )
            assignments[hole.id, default: []].append(FeatureWay(
                id: green.id, kind: .green,
                geometry: halves?.nearB ?? ownerGreen.geometry,
                sharedWithHole: ownerIndex + 1
            ))
        }
    }

    /// Cuts a polygon along the perpendicular bisector of `a` and `b`,
    /// returning the part on each point's side as closed rings. `nil` when
    /// the points are too close to tell apart or either part is degenerate.
    static func split(
        _ ring: [SwingPalCourse.Coordinate],
        between a: SwingPalCourse.Coordinate,
        and b: SwingPalCourse.Coordinate
    ) -> (nearA: [SwingPalCourse.Coordinate], nearB: [SwingPalCourse.Coordinate])? {
        let plane = LocalPlane(origin: a)
        let pb = plane.point(b)
        let length = hypot(pb.x, pb.y)
        guard length >= minimumFlagSeparationMeters else { return nil }
        // Signed distance past the bisector, towards b.
        func side(_ p: (x: Double, y: Double)) -> Double {
            ((p.x - pb.x / 2) * pb.x + (p.y - pb.y / 2) * pb.y) / length
        }
        var points = ring.map(plane.point)
        if points.count > 1, let first = points.first, let last = points.last, first == last {
            points.removeLast()
        }
        guard points.count >= 3 else { return nil }

        func clip(keepingSign sign: Double) -> [SwingPalCourse.Coordinate]? {
            var kept: [(x: Double, y: Double)] = []
            for i in points.indices {
                let current = points[i]
                let next = points[(i + 1) % points.count]
                let fc = side(current) * sign
                let fn = side(next) * sign
                if fc <= 0 { kept.append(current) }
                if (fc < 0 && fn > 0) || (fc > 0 && fn < 0) {
                    let t = fc / (fc - fn)
                    kept.append((current.x + (next.x - current.x) * t, current.y + (next.y - current.y) * t))
                }
            }
            guard kept.count >= 3 else { return nil }
            let coordinates = kept.map(plane.coordinate)
            return coordinates + [coordinates[0]]
        }

        guard let nearA = clip(keepingSign: 1), let nearB = clip(keepingSign: -1) else { return nil }
        return (nearA, nearB)
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

    /// An east/north plane in metres around `origin`; exact enough over a
    /// golf hole.
    struct LocalPlane {
        let origin: SwingPalCourse.Coordinate
        private var cosLat: Double { max(cos(origin.latitude * .pi / 180), 0.1) }

        func point(_ coordinate: SwingPalCourse.Coordinate) -> (x: Double, y: Double) {
            ((coordinate.longitude - origin.longitude) * 111_320 * cosLat,
             (coordinate.latitude - origin.latitude) * 110_540)
        }

        func coordinate(_ point: (x: Double, y: Double)) -> SwingPalCourse.Coordinate {
            .init(latitude: origin.latitude + point.y / 110_540,
                  longitude: origin.longitude + point.x / (111_320 * cosLat))
        }
    }

    /// Whether `point` lies inside the polygon `ring` (even-odd rule).
    static func ringContains(_ ring: [SwingPalCourse.Coordinate], _ point: SwingPalCourse.Coordinate) -> Bool {
        guard ring.count >= 3 else { return false }
        var inside = false
        var previous = ring[ring.count - 1]
        for current in ring {
            if (current.latitude > point.latitude) != (previous.latitude > point.latitude) {
                let crossing = (previous.longitude - current.longitude)
                    * (point.latitude - current.latitude) / (previous.latitude - current.latitude)
                    + current.longitude
                if point.longitude < crossing { inside.toggle() }
            }
            previous = current
        }
        return inside
    }

    /// Distance in metres from `point` to the outline of `ring`.
    static func distanceToRingMeters(_ point: SwingPalCourse.Coordinate, ring: [SwingPalCourse.Coordinate]) -> Double {
        guard let first = ring.first else { return .infinity }
        let closed = ring.last == first ? ring : ring + [first]
        return closestSegmentDistanceMeters(point, polyline: closed)
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
