import SwiftUI

// MARK: - The mark
//
// SwingPal's mark is a golf hole drawn as the letter S: a tee block at the
// tail, a fairway that swells through the landing zones and pinches at the
// approach (the same thick–thin rhythm as a typeset S), and a green with the
// flag at the head. Yardage rings radiate from the pin, as in the book.
//
// The geometry is shared with the icon and launch-screen artwork (rendered
// from the same numbers by `Tools/brand/render_brand.py`), so the mark in the
// app, on the launch screen and on the Home Screen is one drawing.

enum HoleMark {
    /// Centreline of the S, tee end to green end, in a 1024-unit box.
    static let segments: [[CGPoint]] = [
        [CGPoint(x: 292, y: 792), CGPoint(x: 470, y: 872), CGPoint(x: 716, y: 812), CGPoint(x: 700, y: 664)],
        [CGPoint(x: 700, y: 664), CGPoint(x: 686, y: 540), CGPoint(x: 360, y: 528), CGPoint(x: 344, y: 392)],
        [CGPoint(x: 344, y: 392), CGPoint(x: 330, y: 262), CGPoint(x: 520, y: 214), CGPoint(x: 640, y: 262)]
    ]
    /// Fairway half-width along the hole (0 = tee end, 1 = green end).
    static let widthKeys: [(t: Double, halfWidth: Double)] = [
        (0, 40), (0.2, 62), (0.5, 80), (0.78, 58), (0.93, 44), (1, 52)
    ]
    static let greenCentre = CGPoint(x: 686, y: 282)
    static let teeCentre = CGPoint(x: 208, y: 754)
    static let ringRadii: [CGFloat] = [250, 420, 590]
    static let edgeGrowth: Double = 7
    /// Seats the drawing on the icon grid.
    static let placement = CGAffineTransform(translationX: 512, y: 512)
        .scaledBy(x: 0.94, y: 0.94)
        .translatedBy(x: -500, y: -488)

    struct Sample {
        let point: CGPoint
        let t: Double
    }

    static let centreline: [Sample] = {
        var points: [CGPoint] = []
        let perSegment = 240
        for (index, segment) in segments.enumerated() {
            for step in 0..<perSegment {
                if index > 0 && step == 0 { continue }
                points.append(bezier(segment, Double(step) / Double(perSegment - 1)))
            }
        }
        var lengths: [Double] = [0]
        for (a, b) in zip(points, points.dropFirst()) {
            lengths.append(lengths[lengths.count - 1] + hypot(b.x - a.x, b.y - a.y))
        }
        let total = lengths.last ?? 1
        return zip(points, lengths).map { Sample(point: $0, t: $1 / total) }
    }()

    static func halfWidth(at t: Double) -> Double {
        for (lower, upper) in zip(widthKeys, widthKeys.dropFirst()) where t <= upper.t {
            let f = (t - lower.t) / (upper.t - lower.t)
            let eased = (1 - Foundation.cos(Double.pi * f)) / 2
            return lower.halfWidth + (upper.halfWidth - lower.halfWidth) * eased
        }
        return widthKeys[widthKeys.count - 1].halfWidth
    }

    /// The fairway outline (without the rounded tee-end cap), in box units.
    static func fairway(grow: Double = 0) -> Path {
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for index in centreline.indices {
            let a = centreline[max(index - 1, 0)].point
            let b = centreline[min(index + 1, centreline.count - 1)].point
            let dx = b.x - a.x
            let dy = b.y - a.y
            let length = max(hypot(dx, dy), 0.0001)
            let normal = CGPoint(x: -dy / length, y: dx / length)
            let width = halfWidth(at: centreline[index].t) + grow
            let p = centreline[index].point
            left.append(CGPoint(x: p.x + normal.x * width, y: p.y + normal.y * width))
            right.append(CGPoint(x: p.x - normal.x * width, y: p.y - normal.y * width))
        }
        var path = Path()
        path.addLines(left + right.reversed())
        path.closeSubpath()
        return path
    }

    /// The rounded end of the fairway at the tee.
    static func teeCap(grow: Double = 0) -> Path {
        let r = halfWidth(at: 0) + grow
        let c = centreline[0].point
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    static var teeBlock: Path {
        Path(roundedRect: CGRect(x: -38, y: -22, width: 76, height: 44), cornerRadius: 9)
            .applying(CGAffineTransform(translationX: teeCentre.x, y: teeCentre.y).rotated(by: .pi * 24 / 180))
    }

    /// The route a ball takes playing the hole: tee block, down the fairway, into the cup.
    static let ballRoute: [CGPoint] = [teeCentre] + centreline.map(\.point) + [greenCentre]

    static let ballRouteLengths: [Double] = {
        var lengths: [Double] = [0]
        for (a, b) in zip(ballRoute, ballRoute.dropFirst()) {
            lengths.append(lengths[lengths.count - 1] + hypot(b.x - a.x, b.y - a.y))
        }
        let total = lengths.last ?? 1
        return lengths.map { $0 / total }
    }()

    static func ballPoint(at progress: Double) -> CGPoint {
        let p = min(max(progress, 0), 1)
        guard let upper = ballRouteLengths.firstIndex(where: { $0 >= p }), upper > 0 else { return ballRoute[0] }
        let a = ballRouteLengths[upper - 1]
        let b = ballRouteLengths[upper]
        let f = b > a ? (p - a) / (b - a) : 0
        let from = ballRoute[upper - 1]
        let to = ballRoute[upper]
        return CGPoint(x: from.x + (to.x - from.x) * f, y: from.y + (to.y - from.y) * f)
    }

    static func ballTrail(to progress: Double) -> Path {
        var path = Path()
        let p = min(max(progress, 0), 1)
        path.move(to: ballRoute[0])
        for (point, length) in zip(ballRoute, ballRouteLengths).dropFirst() where length < p {
            path.addLine(to: point)
        }
        path.addLine(to: ballPoint(at: p))
        return path
    }

    private static func bezier(_ s: [CGPoint], _ t: Double) -> CGPoint {
        let u = 1 - t
        let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
        return CGPoint(x: a * s[0].x + b * s[1].x + c * s[2].x + d * s[3].x,
                       y: a * s[0].y + b * s[1].y + c * s[2].y + d * s[3].y)
    }
}
