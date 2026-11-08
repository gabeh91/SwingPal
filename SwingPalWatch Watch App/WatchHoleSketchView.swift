import SwiftUI

/// The live hole as a yardage-book page: tee at the bottom, green at the top,
/// drawn to scale from the course geometry the iPhone sends. Nothing here is
/// invented; a hole without geometry draws nothing.
struct WatchHoleSketchView: View {
    let sketch: RoundCompanionHoleSketch
    var insets = EdgeInsets(top: 14, leading: 6, bottom: 8, trailing: 6)

    var body: some View {
        Canvas { context, size in
            guard let frame = WatchSketchFrame(sketch: sketch, size: size, insets: insets) else { return }
            draw(in: &context, frame: frame)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func draw(in context: inout GraphicsContext, frame: WatchSketchFrame) {
        let order: [RoundCompanionHoleSketch.Kind] = [.fairway, .water, .bunker, .green, .tee]
        for kind in order {
            for feature in sketch.features where feature.kind == kind {
                let path = frame.path(feature.points)
                switch kind {
                case .fairway:
                    context.fill(path, with: .color(WatchBook.fairway))
                    var clip = context
                    clip.clip(to: path)
                    stripes(in: path.boundingRect, spacing: 6, width: 2.4, color: WatchBook.fairwayEdge.opacity(0.22), context: &clip)
                    context.stroke(path, with: .color(WatchBook.fairwayEdge), lineWidth: 0.8)
                case .water:
                    context.fill(path, with: .color(WatchBook.water))
                    var clip = context
                    clip.clip(to: path)
                    stripes(in: path.boundingRect, spacing: 3, width: 0.5, color: WatchBook.waterLine.opacity(0.55), context: &clip)
                    context.stroke(path, with: .color(WatchBook.waterLine), lineWidth: 0.7)
                case .bunker:
                    context.fill(path, with: .color(WatchBook.sand))
                    context.stroke(path, with: .color(WatchBook.sandDot), lineWidth: 0.7)
                case .green:
                    context.fill(path, with: .color(WatchBook.green))
                    context.stroke(path, with: .color(WatchBook.greenContour), lineWidth: 0.9)
                case .tee:
                    context.fill(path, with: .color(WatchBook.ink.opacity(0.78)))
                }
            }
        }

        let tee = sketch.tee.map(frame.point)
        let green = sketch.green.map(frame.point)

        if let tee, let green {
            var line = Path()
            line.move(to: tee)
            line.addLine(to: green)
            context.stroke(line, with: .color(WatchBook.ink.opacity(0.3)), style: StrokeStyle(lineWidth: 0.7, dash: [2, 3]))
        }

        if let aim = sketch.aim.map(frame.point) {
            let origin = sketch.player.map(frame.point) ?? tee
            if let origin, let green {
                var plan = Path()
                plan.move(to: origin)
                plan.addLine(to: aim)
                plan.addLine(to: green)
                context.stroke(plan, with: .color(WatchBook.flag), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            }
            context.stroke(Path(ellipseIn: CGRect(x: aim.x - 6, y: aim.y - 6, width: 12, height: 12)), with: .color(WatchBook.flag), lineWidth: 1.4)
        }

        if let green { pin(at: green, context: &context) }

        if let player = sketch.player.map(frame.point) {
            context.fill(Path(ellipseIn: CGRect(x: player.x - 6, y: player.y - 6, width: 12, height: 12)), with: .color(WatchBook.paper))
            context.fill(Path(ellipseIn: CGRect(x: player.x - 4, y: player.y - 4, width: 8, height: 8)), with: .color(WatchBook.flag))
        }
    }

    private func pin(at point: CGPoint, context: inout GraphicsContext) {
        let height: CGFloat = 13
        var pole = Path()
        pole.move(to: point)
        pole.addLine(to: CGPoint(x: point.x, y: point.y - height))
        context.stroke(pole, with: .color(WatchBook.ink), lineWidth: 1)
        var pennant = Path()
        pennant.move(to: CGPoint(x: point.x, y: point.y - height))
        pennant.addLine(to: CGPoint(x: point.x + height * 0.55, y: point.y - height * 0.82))
        pennant.addLine(to: CGPoint(x: point.x, y: point.y - height * 0.64))
        pennant.closeSubpath()
        context.fill(pennant, with: .color(WatchBook.flag))
    }

    private func stripes(in rect: CGRect, spacing: CGFloat, width: CGFloat, color: Color, context: inout GraphicsContext) {
        var stripe = Path()
        var y = rect.minY
        var even = true
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
}

/// Fits the sketch's metres into the view, preserving scale, y up the page.
struct WatchSketchFrame {
    let minX: CGFloat
    let maxY: CGFloat
    let scale: CGFloat
    let offset: CGPoint

    init?(sketch: RoundCompanionHoleSketch, size: CGSize, insets: EdgeInsets) {
        guard let bounds = sketch.bounds else { return nil }
        let width = CGFloat(max(bounds.maxX - bounds.minX, 20))
        let height = CGFloat(max(bounds.maxY - bounds.minY, 20))
        let availableWidth = max(size.width - insets.leading - insets.trailing, 1)
        let availableHeight = max(size.height - insets.top - insets.bottom, 1)
        scale = min(availableWidth / width, availableHeight / height)
        minX = CGFloat(bounds.minX)
        maxY = CGFloat(bounds.maxY)
        offset = CGPoint(
            x: insets.leading + (availableWidth - width * scale) / 2,
            y: insets.top + (availableHeight - height * scale) / 2
        )
    }

    func point(_ point: RoundCompanionHoleSketch.Point) -> CGPoint {
        CGPoint(
            x: offset.x + (CGFloat(point.x) - minX) * scale,
            y: offset.y + (maxY - CGFloat(point.y)) * scale
        )
    }

    func path(_ points: [RoundCompanionHoleSketch.Point]) -> Path {
        var path = Path()
        path.addLines(points.map(point))
        path.closeSubpath()
        return path
    }
}
