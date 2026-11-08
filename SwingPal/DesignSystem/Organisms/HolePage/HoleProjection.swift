import SwiftUI

/// Projects a hole's supplied geometry into local metres, rotated so the line from
/// tee to green points up the page. Nothing is invented: holes without a tee or
/// green keep their compass orientation.
struct HoleProjection {
    let originLatitude: Double
    let originLongitude: Double
    let cosLat: Double
    let sinA: Double
    let cosA: Double
    let bounds: CGRect   // rotated metres (y increases up the page, i.e. toward the green)
    let tee: CGPoint?
    let green: CGPoint?

    static let metresPerDegreeLat = 110_540.0
    static let metresPerDegreeLon = 111_320.0

    init?(hole: SwingPalCourse.Hole, including extra: [SwingPalCourse.Coordinate] = []) {
        let all = hole.features.flatMap(\.coordinates)
        guard let first = all.first else { return nil }
        let lat0 = first.latitude, lon0 = first.longitude
        let cl = cos(lat0 * .pi / 180)
        let raw: (SwingPalCourse.Coordinate) -> CGPoint = { c in
            CGPoint(x: (c.longitude - lon0) * cl * HoleProjection.metresPerDegreeLon,
                    y: (c.latitude - lat0) * HoleProjection.metresPerDegreeLat)
        }
        let centroid: (SwingPalCourse.Hole.FeatureKind) -> CGPoint? = { kind in
            let pts = hole.features.filter { $0.kind == kind }.flatMap(\.coordinates).map(raw)
            guard !pts.isEmpty else { return nil }
            return CGPoint(x: pts.map(\.x).reduce(0, +) / CGFloat(pts.count),
                           y: pts.map(\.y).reduce(0, +) / CGFloat(pts.count))
        }
        let teeRaw = centroid(.tee)
        let greenRaw = centroid(.green)
        var angle = 0.0
        if let t = teeRaw, let g = greenRaw, hypot(g.x - t.x, g.y - t.y) > 1 {
            angle = atan2(Double(g.x - t.x), Double(g.y - t.y))
        }
        let s = sin(angle), c = cos(angle)
        let rotate: (CGPoint) -> CGPoint = { p in
            CGPoint(x: p.x * c - p.y * s, y: p.x * s + p.y * c)
        }
        let rotated = (all + extra).map(raw).map(rotate)
        let minX = rotated.map(\.x).min() ?? 0, maxX = rotated.map(\.x).max() ?? 1
        let minY = rotated.map(\.y).min() ?? 0, maxY = rotated.map(\.y).max() ?? 1

        originLatitude = lat0
        originLongitude = lon0
        cosLat = cl
        sinA = s
        cosA = c
        bounds = CGRect(x: minX, y: minY, width: max(maxX - minX, 20), height: max(maxY - minY, 20))
        tee = teeRaw.map(rotate)
        green = greenRaw.map(rotate)
    }

    func metres(_ c: SwingPalCourse.Coordinate) -> CGPoint {
        let x = (c.longitude - originLongitude) * cosLat * Self.metresPerDegreeLon
        let y = (c.latitude - originLatitude) * Self.metresPerDegreeLat
        return CGPoint(x: x * cosA - y * sinA, y: x * sinA + y * cosA)
    }

    /// Straight-line length from tee centroid to green centroid.
    var teeToGreenMetres: Int? {
        guard let tee, let green else { return nil }
        return Int(hypot(green.x - tee.x, green.y - tee.y).rounded())
    }
}
