import SwiftUI

/// Draws the mark at any size. Pass `ballProgress` to show a ball playing the hole.
struct SwingPalMark: View {
    var colorway: HoleMarkColorway = .page
    var showsRings = true
    var ballProgress: Double? = nil
    var ballScale: Double = 1

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            context.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
            context.scaleBy(x: side / 1024, y: side / 1024)
            draw(in: &context)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func draw(in box: inout GraphicsContext) {
        let c = colorway
        if let ground = c.ground {
            box.fill(Path(CGRect(x: -64, y: -64, width: 1152, height: 1152)), with: .color(ground))
        }

        var ctx = box
        ctx.concatenate(HoleMark.placement)
        let g = HoleMark.greenCentre

        if showsRings {
            let ring = c.rings.opacity(c.ringOpacity)
            let shading: GraphicsContext.Shading = c.fadesRings
                ? .radialGradient(
                    Gradient(stops: [
                        .init(color: ring, location: 0),
                        .init(color: ring, location: 0.55),
                        .init(color: ring.opacity(0), location: 1)
                    ]),
                    // The fade is centred on the box, not the pin, so rings dissolve before the edge.
                    center: CGPoint(x: 500, y: 488), startRadius: 0, endRadius: 512 / 0.94)
                : .color(ring)
            for r in HoleMark.ringRadii {
                ctx.stroke(Path(ellipseIn: CGRect(x: g.x - r, y: g.y - r, width: r * 2, height: r * 2)),
                           with: shading, lineWidth: c.fadesRings ? 5 : 6)
            }
        }

        // Fairway: edge, body, mown stripes.
        ctx.fill(HoleMark.fairway(grow: HoleMark.edgeGrowth), with: .color(c.fairwayEdge))
        ctx.fill(HoleMark.teeCap(grow: HoleMark.edgeGrowth), with: .color(c.fairwayEdge))
        let fairway = HoleMark.fairway()
        ctx.fill(fairway, with: .color(c.fairway))
        ctx.fill(HoleMark.teeCap(), with: .color(c.fairway))
        var mown = ctx
        mown.clip(to: fairway)
        mown.concatenate(CGAffineTransform(translationX: 512, y: 512).rotated(by: -.pi * 40 / 180).translatedBy(x: -512, y: -512))
        var stripes = Path()
        for index in 0..<46 {
            stripes.addRect(CGRect(x: -700 + CGFloat(index) * 60, y: -300, width: 30, height: 1700))
        }
        mown.fill(stripes, with: .color(c.stripe))

        // Green, contours, tee.
        ctx.fill(Path(ellipseIn: CGRect(x: g.x - 112, y: g.y - 96, width: 224, height: 192)), with: .color(c.fairwayEdge))
        ctx.fill(Path(ellipseIn: CGRect(x: g.x - 104, y: g.y - 88, width: 208, height: 176)), with: .color(c.green))
        for rx in [70.0, 46, 22] {
            let ry = (rx * 0.84).rounded()
            ctx.stroke(Path(ellipseIn: CGRect(x: g.x + 6 - rx, y: g.y + 6 - ry, width: rx * 2, height: ry * 2)),
                       with: .color(c.contour.opacity(0.5)), lineWidth: 5)
        }
        ctx.fill(HoleMark.teeBlock, with: .color(c.tee))

        // Ball playing the hole, with its line drawn in pencil behind it.
        if let progress = ballProgress {
            ctx.stroke(HoleMark.ballTrail(to: progress),
                       with: .color(Book.pencil.opacity(0.55)),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [2, 14]))
        }

        // Pin and flag.
        var pole = Path()
        pole.move(to: g)
        pole.addLine(to: CGPoint(x: g.x, y: g.y - 162))
        ctx.stroke(pole, with: .color(c.pole), style: StrokeStyle(lineWidth: 13, lineCap: .round))
        var pennant = Path()
        pennant.addLines([CGPoint(x: g.x + 5, y: g.y - 166), CGPoint(x: g.x + 128, y: g.y - 128), CGPoint(x: g.x + 5, y: g.y - 90)])
        pennant.closeSubpath()
        ctx.fill(pennant, with: .color(c.flag))
        ctx.fill(Path(ellipseIn: CGRect(x: g.x - 12, y: g.y - 12, width: 24, height: 24)), with: .color(c.pin))

        if let progress = ballProgress, ballScale > 0.01 {
            let p = HoleMark.ballPoint(at: progress)
            let r = 17 * ballScale
            let ball = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            ctx.fill(ball, with: .color(Book.leaf))
            ctx.stroke(ball, with: .color(Book.ink), lineWidth: 3.5)
        }
    }
}

#if DEBUG
#Preview("Mark") {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            SwingPalMarkTile(size: 120)
            SwingPalMarkTile(size: 60)
            SwingPalMarkTile(size: 40)
        }
        SwingPalMark(colorway: .page).frame(width: 220)
    }
    .padding()
    .background(Book.paper)
}
#endif
