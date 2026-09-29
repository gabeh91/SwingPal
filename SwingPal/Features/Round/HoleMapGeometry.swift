import CoreLocation

/// Plane geometry for one golf hole, the way a yardage book measures it.
///
/// Holes are a few hundred metres long, so everything works on a local
/// east/north plane around the points involved (equirectangular), which is
/// indistinguishable from great-circle maths at that scale and keeps the
/// arithmetic cheap enough to run inside a view body.
enum HoleMapGeometry {
    static let metresPerDegreeLatitude = 110_540.0
    static let metresPerDegreeLongitudeAtEquator = 111_320.0

    // MARK: Basics

    /// Offset of `point` from `origin`, in metres east and north.
    static func offset(from origin: CLLocationCoordinate2D, to point: CLLocationCoordinate2D) -> (east: Double, north: Double) {
        let cosLat = cos(origin.latitude * .pi / 180)
        return (
            east: (point.longitude - origin.longitude) * metresPerDegreeLongitudeAtEquator * cosLat,
            north: (point.latitude - origin.latitude) * metresPerDegreeLatitude
        )
    }

    static func coordinate(from origin: CLLocationCoordinate2D, east: Double, north: Double) -> CLLocationCoordinate2D {
        let cosLat = max(cos(origin.latitude * .pi / 180), 0.0001)
        return CLLocationCoordinate2D(
            latitude: origin.latitude + north / metresPerDegreeLatitude,
            longitude: origin.longitude + east / (metresPerDegreeLongitudeAtEquator * cosLat)
        )
    }

    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let o = offset(from: a, to: b)
        return (o.east * o.east + o.north * o.north).squareRoot()
    }

    /// Bearing in degrees clockwise from north, 0 ..< 360.
    static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let o = offset(from: a, to: b)
        let degrees = atan2(o.east, o.north) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    static func coordinate(from origin: CLLocationCoordinate2D, bearing degrees: Double, distance metres: Double) -> CLLocationCoordinate2D {
        let radians = degrees * .pi / 180
        return coordinate(from: origin, east: sin(radians) * metres, north: cos(radians) * metres)
    }

    /// Points along a circle of `radius` around `centre`, spanning
    /// `centreBearing ± halfSpread` degrees.
    static func arc(
        centre: CLLocationCoordinate2D,
        radius: Double,
        centreBearing: Double,
        halfSpread: Double,
        steps: Int = 24
    ) -> [CLLocationCoordinate2D] {
        guard radius > 0, steps > 0 else { return [] }
        return (0...steps).map { index in
            let t = Double(index) / Double(steps)
            return coordinate(from: centre, bearing: centreBearing - halfSpread + 2 * halfSpread * t, distance: radius)
        }
    }

    /// Half the angle an arc of `radius` needs to span `lateralMetres` either
    /// side of its centre line, kept within a readable range.
    static func arcHalfSpread(radius: Double, lateralMetres: Double = 40) -> Double {
        guard radius > 1 else { return 35 }
        let degrees = atan(lateralMetres / radius) * 180 / .pi
        return min(max(degrees, 7), 35)
    }

    static func centroid(of coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !coordinates.isEmpty else { return nil }
        let count = Double(coordinates.count)
        return CLLocationCoordinate2D(
            latitude: coordinates.map(\.latitude).reduce(0, +) / count,
            longitude: coordinates.map(\.longitude).reduce(0, +) / count
        )
    }

    // MARK: Hazard yardages

    /// Distances to a hazard from where the ball lies: `reach` is its near
    /// edge (lay up short of this) and `carry` its far edge (fly this to
    /// clear it), as a yardage book writes them.
    struct HazardYardage: Identifiable, Equatable {
        enum Kind: String, Equatable {
            case bunker
            case water
        }

        let id: String
        let kind: Kind
        let reachMetres: Int
        let carryMetres: Int
        /// Where the figures are written: just outside the hazard, away from the line of play.
        let labelCoordinate: CLLocationCoordinate2D
        /// Whether the label sits right of the line of play (as seen from the ball).
        let isRightOfLine: Bool

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id && lhs.kind == rhs.kind && lhs.reachMetres == rhs.reachMetres
                && lhs.carryMetres == rhs.carryMetres && lhs.isRightOfLine == rhs.isRightOfLine
                && lhs.labelCoordinate.latitude == rhs.labelCoordinate.latitude
                && lhs.labelCoordinate.longitude == rhs.labelCoordinate.longitude
        }
    }

    /// Bunkers and water that are in play between the ball and the green:
    /// ahead of the ball, no further than just past the green, and within
    /// `corridorMetres` of the line to the pin. Nearest first.
    static func hazardYardages(
        features: [SwingPalCourse.Hole.Feature],
        origin: CLLocationCoordinate2D,
        pin: CLLocationCoordinate2D,
        corridorMetres: Double = 70,
        labelGapMetres: Double = 12,
        mergeMetres: Double = 32,
        limit: Int = 5
    ) -> [HazardYardage] {
        let axis = offset(from: origin, to: pin)
        let length = (axis.east * axis.east + axis.north * axis.north).squareRoot()
        guard length > 5 else { return [] }
        let unit = (east: axis.east / length, north: axis.north / length)

        func project(_ point: CLLocationCoordinate2D) -> (along: Double, across: Double) {
            let o = offset(from: origin, to: point)
            // `across` is positive to the right of the line of play.
            return (o.east * unit.east + o.north * unit.north, o.east * unit.north - o.north * unit.east)
        }

        let yardages: [HazardYardage] = features.compactMap { feature in
            let kind: HazardYardage.Kind
            switch feature.kind {
            case .bunker: kind = .bunker
            case .water: kind = .water
            default: return nil
            }
            let points = feature.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            guard points.count >= 3, let centre = centroid(of: points) else { return nil }

            let projected = points.map(project)
            let centreProjection = project(centre)
            let distances = points.map { distance(origin, $0) }
            guard let reach = distances.min(), let carry = distances.max() else { return nil }

            // Ignore the hazard the ball is in or beside, anything behind the
            // ball, anything well past the green and anything out of play.
            guard reach >= 10,
                  centreProjection.along > 10,
                  centreProjection.along < length + 25,
                  abs(centreProjection.across) <= corridorMetres
            else { return nil }

            let right = centreProjection.across >= 0
            let outer = right ? (projected.map(\.across).max() ?? 0) : (projected.map(\.across).min() ?? 0)
            let labelAcross = outer + (right ? labelGapMetres : -labelGapMetres)
            let labelEast = unit.east * centreProjection.along + unit.north * labelAcross
            let labelNorth = unit.north * centreProjection.along - unit.east * labelAcross

            return HazardYardage(
                id: feature.id.uuidString,
                kind: kind,
                reachMetres: Int(reach.rounded()),
                carryMetres: Int(carry.rounded()),
                labelCoordinate: coordinate(from: origin, east: labelEast, north: labelNorth),
                isRightOfLine: right
            )
        }

        return Array(mergeNeighbours(yardages.sorted { $0.reachMetres < $1.reachMetres }, withinMetres: mergeMetres).prefix(limit))
    }

    /// Hazards whose figures would be written on top of one another (same
    /// side of the line, labels close together) read as one complex: the
    /// nearest reach and the farthest carry. Water wins the kind.
    static func mergeNeighbours(_ yardages: [HazardYardage], withinMetres: Double) -> [HazardYardage] {
        var merged: [HazardYardage] = []
        for yardage in yardages {
            if let index = merged.firstIndex(where: {
                $0.isRightOfLine == yardage.isRightOfLine
                    && distance($0.labelCoordinate, yardage.labelCoordinate) < withinMetres
            }) {
                let existing = merged[index]
                merged[index] = HazardYardage(
                    id: existing.id,
                    kind: existing.kind == .water || yardage.kind == .water ? .water : .bunker,
                    reachMetres: min(existing.reachMetres, yardage.reachMetres),
                    carryMetres: max(existing.carryMetres, yardage.carryMetres),
                    labelCoordinate: existing.labelCoordinate,
                    isRightOfLine: existing.isRightOfLine
                )
            } else {
                merged.append(yardage)
            }
        }
        return merged
    }

    // MARK: The page

    /// A convex outline around everything drawn for the hole, grown by
    /// `bufferMetres`: the edge of the yardage-book page. Returns `nil` when
    /// the hole has too little geometry to outline.
    static func pageOutline(
        around coordinates: [CLLocationCoordinate2D],
        bufferMetres: Double
    ) -> [CLLocationCoordinate2D]? {
        guard coordinates.count >= 2, let reference = centroid(of: coordinates) else { return nil }
        var points: [(x: Double, y: Double)] = []
        let corners = 12
        for coordinate in coordinates {
            let o = offset(from: reference, to: coordinate)
            for k in 0..<corners {
                let angle = Double(k) / Double(corners) * 2 * .pi
                points.append((o.east + cos(angle) * bufferMetres, o.north + sin(angle) * bufferMetres))
            }
        }
        let hull = convexHull(points)
        guard hull.count >= 3 else { return nil }
        return hull.map { coordinate(from: reference, east: $0.x, north: $0.y) }
    }

    /// A square of paper `halfSizeMetres` either side of `centre`.
    static func sheet(around centre: CLLocationCoordinate2D, halfSizeMetres: Double) -> [CLLocationCoordinate2D] {
        [(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)].map {
            coordinate(from: centre, east: $0.0 * halfSizeMetres, north: $0.1 * halfSizeMetres)
        }
    }

    /// Andrew's monotone chain; counter-clockwise, no repeated end point.
    static func convexHull(_ points: [(x: Double, y: Double)]) -> [(x: Double, y: Double)] {
        let sorted = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        guard sorted.count >= 3 else { return sorted }
        func cross(_ o: (x: Double, y: Double), _ a: (x: Double, y: Double), _ b: (x: Double, y: Double)) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        var lower: [(x: Double, y: Double)] = []
        for p in sorted {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        var upper: [(x: Double, y: Double)] = []
        for p in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        return Array(lower.dropLast() + upper.dropLast())
    }
}
