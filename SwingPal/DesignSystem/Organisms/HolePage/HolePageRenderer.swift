import SwiftUI
import UIKit

struct HolePageRenderer {
    let frame: HolePageFrame
    let hole: SwingPalCourse.Hole
    let neighbours: [SwingPalCourse.Hole]
    let unit: DistanceUnit
    let showsArcs: Bool
    let showsCentreLine: Bool
    let showsScale: Bool
    let player: SwingPalCourse.Coordinate?
    let target: SwingPalCourse.Coordinate?

    private func path(_ feature: SwingPalCourse.Hole.Feature) -> Path? {
        guard feature.coordinates.count > 2 else { return nil }
        var p = Path()
        p.addLines(feature.coordinates.map { frame.point($0) })
        p.closeSubpath()
        return p
    }

    func draw(in context: inout GraphicsContext) {
        let bounds = CGRect(origin: .zero, size: frame.size)

        // Neighbouring holes: faint context, never competing with the page's hole.
        for other in neighbours where other.number != hole.number {
            for feature in other.features where feature.kind == .fairway || feature.kind == .green {
                guard let p = path(feature), p.boundingRect.intersects(bounds) else { continue }
                context.fill(p, with: .color((feature.kind == .green ? Book.green : Book.fairway).opacity(0.3)))
            }
        }

        let order: [SwingPalCourse.Hole.FeatureKind] = [.fairway, .water, .bunker, .green, .tee, .layup]
        for kind in order {
            for feature in hole.features where feature.kind == kind {
                guard let p = path(feature) else { continue }
                switch kind {
                case .fairway:
                    context.fill(p, with: .color(Book.fairway))
                    var clip = context
                    clip.clip(to: p)
                    stripes(in: p.boundingRect, spacing: 9, context: &clip, color: Book.fairwayEdge.opacity(0.22), width: 3.5)
                    context.stroke(p, with: .color(Book.fairwayEdge), lineWidth: 1)
                case .water:
                    context.fill(p, with: .color(Book.water))
                    var clip = context
                    clip.clip(to: p)
                    stripes(in: p.boundingRect, spacing: 4, context: &clip, color: Book.waterLine.opacity(0.55), width: 0.6)
                    context.stroke(p, with: .color(Book.waterLine), lineWidth: 0.9)
                case .bunker:
                    context.fill(p, with: .color(Book.sand))
                    var clip = context
                    clip.clip(to: p)
                    stipple(in: p.boundingRect, context: &clip)
                    context.stroke(p, with: .color(Book.sandDot), lineWidth: 0.8)
                case .green:
                    context.fill(p, with: .color(Book.green))
                    contours(for: feature, context: &context)
                    context.stroke(p, with: .color(Book.greenContour), lineWidth: 1.1)
                case .tee:
                    context.fill(p, with: .color(Book.ink.opacity(0.78)))
                case .layup:
                    context.stroke(p, with: .color(Book.pencil), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                }
            }
        }

        let tee = frame.projection.tee.map(frame.point)
        let green = frame.projection.green.map(frame.point)

        if showsCentreLine, let tee, let green {
            var line = Path()
            line.move(to: tee)
            line.addLine(to: green)
            context.stroke(line, with: .color(Book.ink.opacity(0.35)), style: StrokeStyle(lineWidth: 0.8, dash: [2, 4]))
        }

        if showsArcs, let green, let tee {
            arcs(green: green, tee: tee, context: &context)
        }

        if let green { pin(at: green, context: &context) }

        if let target {
            let t = frame.point(target)
            let origin = player.map { frame.point($0) } ?? tee
            if let origin, let green {
                var plan = Path()
                plan.move(to: origin)
                plan.addLine(to: t)
                plan.addLine(to: green)
                context.stroke(plan, with: .color(Book.flag), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            }
            let ring = Path(ellipseIn: CGRect(x: t.x - 9, y: t.y - 9, width: 18, height: 18))
            context.stroke(ring, with: .color(Book.flag), lineWidth: 1.6)
            context.fill(Path(ellipseIn: CGRect(x: t.x - 2, y: t.y - 2, width: 4, height: 4)), with: .color(Book.flag))
        }

        if let player {
            let p = frame.point(player)
            if bounds.insetBy(dx: -4, dy: -4).contains(p) {
                context.fill(Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)), with: .color(Book.leaf))
                context.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(Book.flag))
            }
        }

        if showsScale { scaleBar(context: &context) }
    }

    private func stripes(in rect: CGRect, spacing: CGFloat, context: inout GraphicsContext, color: Color, width: CGFloat) {
        var y = rect.minY
        var even = true
        var stripe = Path()
        while y < rect.maxY {
            if even || width < 1 {
                stripe.move(to: CGPoint(x: rect.minX, y: y))
                stripe.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
            even.toggle()
            y += spacing
        }
        context.stroke(stripe, with: .color(color), lineWidth: width)
    }

    private func stipple(in rect: CGRect, context: inout GraphicsContext) {
        var dots = Path()
        var seed: UInt64 = UInt64(abs(Int(rect.minX * 31 + rect.minY * 17))) &+ 7
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((seed >> 33) % 1000) / 1000
        }
        let step: CGFloat = 3.6
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                let jx = x + next() * step, jy = y + next() * step
                dots.addEllipse(in: CGRect(x: jx, y: jy, width: 0.9, height: 0.9))
                x += step
            }
            y += step
        }
        context.fill(dots, with: .color(Book.sandDot.opacity(0.8)))
    }

    private func contours(for feature: SwingPalCourse.Hole.Feature, context: inout GraphicsContext) {
        let pts = feature.coordinates.map { frame.point($0) }
        guard pts.count > 2 else { return }
        let c = CGPoint(x: pts.map(\.x).reduce(0, +) / CGFloat(pts.count),
                        y: pts.map(\.y).reduce(0, +) / CGFloat(pts.count))
        for (i, s) in [0.74, 0.5, 0.26].enumerated() {
            var ring = Path()
            ring.addLines(pts.map { CGPoint(x: c.x + ($0.x - c.x) * s, y: c.y + ($0.y - c.y) * s + CGFloat(i) * 0.6) })
            ring.closeSubpath()
            context.stroke(ring, with: .color(Book.greenContour.opacity(0.55)), lineWidth: 0.6)
        }
    }

    private func pin(at point: CGPoint, context: inout GraphicsContext) {
        let h = min(22, max(frame.size.height * 0.14, 7))
        var pole = Path()
        pole.move(to: point)
        pole.addLine(to: CGPoint(x: point.x, y: point.y - h))
        context.stroke(pole, with: .color(Book.ink), lineWidth: h > 12 ? 1.2 : 0.8)
        var pennant = Path()
        pennant.move(to: CGPoint(x: point.x, y: point.y - h))
        pennant.addLine(to: CGPoint(x: point.x + h * 0.55, y: point.y - h * 0.82))
        pennant.addLine(to: CGPoint(x: point.x, y: point.y - h * 0.64))
        pennant.closeSubpath()
        context.fill(pennant, with: .color(Book.flag))
        if h > 12 {
            context.fill(Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)), with: .color(Book.ink))
        }
    }

    /// True-radius arcs from the green centre, opening toward the tee.
    private func arcs(green: CGPoint, tee: CGPoint, context: inout GraphicsContext) {
        let unitMetres = unit == .yards ? 0.9144 : 1.0
        let lengthPts = hypot(tee.x - green.x, tee.y - green.y)
        let pointsPerMetre = frame.scale
        let axis = Double(atan2(tee.y - green.y, tee.x - green.x))
        let spread = 0.42
        for step in stride(from: 50, through: 300, by: 50) {
            let r = CGFloat(Double(step) * unitMetres) * pointsPerMetre
            guard r < lengthPts - 14 else { break }
            var arc = Path()
            arc.addArc(center: green, radius: r, startAngle: .radians(axis - spread), endAngle: .radians(axis + spread), clockwise: false)
            context.stroke(arc, with: .color(Book.ink.opacity(0.4)), style: StrokeStyle(lineWidth: 0.7, dash: [1.5, 3]))
            let labelAngle: Double = axis - spread - 0.02
            let lp = CGPoint(x: green.x + CGFloat(Foundation.cos(labelAngle)) * r,
                             y: green.y + CGFloat(Foundation.sin(labelAngle)) * r)
            context.draw(
                Text("\(step)").font(.system(size: 9, weight: .semibold).width(.condensed)).foregroundColor(Book.pencil),
                at: lp, anchor: .trailing
            )
        }
    }

    private func scaleBar(context: inout GraphicsContext) {
        let metres: Double = unit == .yards ? 45.72 : 50
        let length = CGFloat(metres) * frame.scale
        guard length > 12, length < frame.size.width * 0.6 else { return }
        let origin = CGPoint(x: 14, y: frame.size.height - 12)
        var bar = Path()
        bar.move(to: CGPoint(x: origin.x, y: origin.y - 3))
        bar.addLine(to: origin)
        bar.addLine(to: CGPoint(x: origin.x + length, y: origin.y))
        bar.addLine(to: CGPoint(x: origin.x + length, y: origin.y - 3))
        context.stroke(bar, with: .color(Book.pencil), lineWidth: 0.9)
        context.draw(
            Text(unit == .yards ? "50 yd" : "50 m").font(.system(size: 9, weight: .semibold).width(.condensed)).foregroundColor(Book.pencil),
            at: CGPoint(x: origin.x + length + 4, y: origin.y - 1), anchor: .leading
        )
    }
}
