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

/// Inks for the mark. `.tile` is the Home Screen icon (stamp-green ground);
/// `.page` sits on paper and follows the day/night book.
struct HoleMarkColorway {
    var ground: Color?
    var rings: Color
    var ringOpacity: Double
    var fadesRings: Bool
    var fairway: Color
    var fairwayEdge: Color
    var stripe: Color
    var green: Color
    var contour: Color
    var tee: Color
    var pole: Color
    var pin: Color
    var flag: Color

    static let tile = HoleMarkColorway(
        ground: Color(uiColor: UIColor(bookHex: 0x1E3B2F)),
        rings: Color(uiColor: UIColor(bookHex: 0xF2EFE6)),
        ringOpacity: 0.16,
        fadesRings: false,
        fairway: Color(uiColor: UIColor(bookHex: 0xC9D8AA)),
        fairwayEdge: Color(uiColor: UIColor(bookHex: 0x8BAA73)),
        stripe: Color.white.opacity(0.18),
        green: Color(uiColor: UIColor(bookHex: 0xA3CA8B)),
        contour: Color(uiColor: UIColor(bookHex: 0x5F9150)),
        tee: Color(uiColor: UIColor(bookHex: 0xF2EFE6)),
        pole: Color(uiColor: UIColor(bookHex: 0xF2EFE6)),
        pin: Color(uiColor: UIColor(bookHex: 0x17261F)),
        flag: Color(uiColor: UIColor(bookHex: 0xD4462A))
    )

    static let page = HoleMarkColorway(
        ground: nil,
        rings: Book.pencil,
        ringOpacity: 0.28,
        fadesRings: true,
        fairway: Book.dynamic(0xB9CE92, 0x3F6243),
        fairwayEdge: Book.dynamic(0x6F9160, 0x6C9867),
        stripe: Color(uiColor: UIColor { traits in
            UIColor(white: 1, alpha: traits.userInterfaceStyle == .dark ? 0.07 : 0.22)
        }),
        green: Book.dynamic(0x8FBF74, 0x5A8C52),
        contour: Book.dynamic(0x4F7F44, 0x9CC98C),
        tee: Book.stamp,
        pole: Book.ink,
        pin: Book.dynamic(0x17261F, 0x101714),
        flag: Book.flag
    )
}

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

/// The mark on its stamp-green tile, as it appears on the Home Screen.
struct SwingPalMarkTile: View {
    var size: CGFloat = 84

    var body: some View {
        SwingPalMark(colorway: .tile)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .stroke(Book.ink.opacity(0.08), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Launch splash
//
// Picks up exactly where LaunchScreen.storyboard leaves off (paper, the mark
// centred at 200 pt) and plays the hole once: a ball leaves the tee, runs the
// S with its line pencilled in behind it and drops at the pin while the
// wordmark is set beneath. Then the page lifts away. About 1.3 s, never loops,
// never blocks touches, and Reduce Motion skips the ball.

struct LaunchSplashView: View {
    /// Stretches every duration; the design-review fixture slows it down to inspect frames.
    var pace: Double = 1
    var onFinished: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = false

    static let markSide: CGFloat = 200

    init(pace: Double = 1, onFinished: @escaping () -> Void = {}) {
        self.pace = pace
        self.onFinished = onFinished
    }

    struct Frame {
        var ball = 0.0
        var ballScale = 0.0
        var word = 0.0
        var veil = 1.0
    }

    var body: some View {
        KeyframeAnimator(initialValue: Frame(), trigger: started) { frame in
            ZStack {
                Book.paper
                SwingPalMark(colorway: .page,
                             ballProgress: reduceMotion ? nil : frame.ball,
                             ballScale: frame.ballScale)
                    .frame(width: Self.markSide, height: Self.markSide)
                    .scaleEffect(1 + (1 - frame.veil) * 0.04)
                wordmark
                    .opacity(frame.word)
                    .offset(y: Self.markSide / 2 + 46 + (1 - frame.word) * 8)
            }
            .opacity(frame.veil)
            .ignoresSafeArea()
        } keyframes: { _ in
            let d = pace
            KeyframeTrack(\.ballScale) {
                LinearKeyframe(0, duration: 0.1 * d)
                CubicKeyframe(1, duration: 0.12 * d)
                LinearKeyframe(1, duration: 0.58 * d)
                CubicKeyframe(0, duration: 0.12 * d)
            }
            KeyframeTrack(\.ball) {
                LinearKeyframe(0, duration: 0.18 * d)
                CubicKeyframe(1, duration: 0.64 * d)
            }
            KeyframeTrack(\.word) {
                LinearKeyframe(0, duration: (reduceMotion ? 0.05 : 0.3) * d)
                CubicKeyframe(1, duration: 0.35 * d)
            }
            KeyframeTrack(\.veil) {
                LinearKeyframe(1, duration: (reduceMotion ? 0.7 : 1.02) * d)
                CubicKeyframe(0, duration: 0.28 * d)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            started = true
            try? await Task.sleep(for: .seconds(((reduceMotion ? 0.7 : 1.02) + 0.3) * pace))
            onFinished()
        }
    }

    private var wordmark: some View {
        VStack(spacing: 6) {
            Text("SwingPal")
                .font(Book.Typeface.display)
                .foregroundStyle(Book.ink)
            BookNote("Your yardage book")
        }
        .dynamicTypeSize(.large ... .xxLarge)
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

#Preview("Splash") {
    LaunchSplashView(pace: 3)
}
#endif
