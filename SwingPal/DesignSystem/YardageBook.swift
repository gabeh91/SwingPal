import SwiftUI
import UIKit

// MARK: - The yardage book
//
// SwingPal's visual world is a caddie's yardage book: every hole drawn to scale
// from supplied geometry, turned tee-to-green, with measurements written beside
// the thing they measure. Paper and ink carry the interface; a single flag colour
// marks the target, the player and scores under par.

enum Book {
    // Paper and ink (asset colours, light + night book).
    static let paper = CourseStyle.ground
    static let leaf = CourseStyle.surface
    static let ink = CourseStyle.ink
    static let pencil = CourseStyle.muted
    static let rule = CourseStyle.line
    static let wash = CourseStyle.wash
    static let stamp = CourseStyle.action
    static let onStamp = CourseStyle.onAction
    static let warning = CourseStyle.warning
    static let flag = Color("BookFlag")

    // Terrain inks. Used only inside hole drawings.
    /// The ground a drawn hole sits on: rough, left plain so the hole reads first.
    static let rough = dynamic(0xE4E6D4, 0x18221D)
    static let fairway = dynamic(0xC9D8AA, 0x2C4531)
    static let fairwayEdge = dynamic(0x8BAA73, 0x4F7550)
    static let green = dynamic(0x9DC486, 0x3F6A3C)
    static let greenContour = dynamic(0x5F9150, 0x7DAA6E)
    static let sand = dynamic(0xEDE0BA, 0x6E6243)
    static let sandDot = dynamic(0xB89C5C, 0xB7A06A)
    static let water = dynamic(0xB3D2DA, 0x274B56)
    static let waterLine = dynamic(0x6798AA, 0x5F90A0)

    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(bookHex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    // MARK: Type
    //
    // Condensed SF for page furniture and figures (the voice of the book),
    // regular SF for reading. Everything scales with Dynamic Type.
    enum Typeface {
        static let folio = Font.system(size: 64, weight: .bold).width(.condensed)
        static let display = Font.system(.largeTitle, weight: .bold).width(.condensed)
        static let title = Font.system(.title, weight: .bold).width(.condensed)
        static let heading = Font.system(.title2, weight: .semibold).width(.condensed)
        static let subheading = Font.system(.title3, weight: .semibold).width(.condensed)
        static let figure = Font.system(.title, weight: .semibold).width(.condensed).monospacedDigit()
        static let smallFigure = Font.system(.headline, weight: .semibold).width(.condensed).monospacedDigit()
        /// Small-capital annotations: the pencil notes of the book.
        static let note = Font.system(.caption, weight: .semibold).width(.expanded)
        static let noteSmall = Font.system(.caption2, weight: .semibold).width(.expanded)
    }
}

extension UIColor {
    convenience init(bookHex hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Annotation label

/// A pencil annotation: small, spaced capitals in the secondary ink.
struct BookNote: View {
    let text: String
    var color: Color = Book.pencil
    init(_ text: String, color: Color = Book.pencil) {
        self.text = text
        self.color = color
    }
    var body: some View {
        Text(text.uppercased())
            .font(Book.Typeface.note)
            .tracking(0.6)
            .foregroundStyle(color)
    }
}

/// A section marker: title, then a hairline running to the margin.
struct BookSectionRule: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title).font(Book.Typeface.heading).foregroundStyle(Book.ink)
                .accessibilityAddTraits(.isHeader)
            Rectangle().fill(Book.rule).frame(height: 1)
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] + 5 }
                .accessibilityHidden(true)
            if let trailing {
                Text(trailing).font(Book.Typeface.note).foregroundStyle(Book.pencil)
            }
        }
    }
}

struct BookHairline: View {
    var color: Color = Book.rule
    var body: some View {
        Rectangle().fill(color).frame(height: 1).accessibilityHidden(true)
    }
}

// MARK: - Buttons

/// The ink stamp: the one committed action on a page.
struct BookStampButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 30)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .foregroundStyle(prominent ? (isEnabled ? Book.onStamp : Book.pencil) : Book.ink)
            .background {
                let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                if prominent {
                    shape.fill(isEnabled ? Book.stamp : Book.wash)
                } else {
                    shape.strokeBorder(Book.ink.opacity(isEnabled ? 0.85 : 0.3), lineWidth: 1.25)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.12), value: configuration.isPressed)
    }
}

/// A row that responds like paper under a thumb: a light wash while pressed.
struct BookRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(Book.wash.opacity(configuration.isPressed ? 0.9 : 0))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Score notation

/// Scorecard notation: circle for birdie, double circle for eagle or better,
/// square for bogey, double square for double bogey or worse.
struct ScoreMark: View {
    let score: Int?
    let par: Int
    var size: CGFloat = 30
    var font: Font? = nil
    var showsNumber = true

    private var diff: Int? { score.map { $0 - par } }

    var body: some View {
        ZStack {
            if let diff {
                if diff <= -1 {
                    Circle().stroke(Book.flag, lineWidth: 1.4).frame(width: size, height: size)
                    if diff <= -2 {
                        Circle().stroke(Book.flag, lineWidth: 1.2).frame(width: size - 6, height: size - 6)
                    }
                } else if diff >= 1 {
                    Rectangle().stroke(Book.ink.opacity(0.8), lineWidth: 1.2).frame(width: size - 2, height: size - 2)
                    if diff >= 2 {
                        Rectangle().stroke(Book.ink.opacity(0.8), lineWidth: 1.1).frame(width: size - 8, height: size - 8)
                    }
                }
            }
            if showsNumber {
            Text(score.map(String.init) ?? "–")
                .font(font ?? .system(size: size * 0.52, weight: .semibold).width(.condensed))
                .monospacedDigit()
                .foregroundStyle(score == nil ? Book.pencil : (diff ?? 0) < 0 ? Book.flag : Book.ink)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(score: score, par: par))
    }

    static func spoken(score: Int?, par: Int) -> String {
        guard let score else { return "No score" }
        let name: String
        switch score - par {
        case ...(-3): name = "albatross or better"
        case -2: name = "eagle"
        case -1: name = "birdie"
        case 0: name = "par"
        case 1: name = "bogey"
        case 2: name = "double bogey"
        default: name = "\(score - par) over par"
        }
        return "\(score), \(name)"
    }

    static func toParText(_ value: Int) -> String {
        value == 0 ? "E" : value > 0 ? "+\(value)" : "\(value)"
    }
}

// MARK: - Hole projection

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

/// Maps rotated metres into a view rectangle, preserving scale.
struct HolePageFrame {
    let projection: HoleProjection
    let scale: CGFloat
    let offset: CGPoint
    let size: CGSize

    init(projection: HoleProjection, size: CGSize, insets: EdgeInsets) {
        self.projection = projection
        self.size = size
        let w = max(size.width - insets.leading - insets.trailing, 1)
        let h = max(size.height - insets.top - insets.bottom, 1)
        let b = projection.bounds
        scale = min(w / b.width, h / b.height)
        let drawnW = b.width * scale, drawnH = b.height * scale
        offset = CGPoint(x: insets.leading + (w - drawnW) / 2, y: insets.top + (h - drawnH) / 2)
    }

    func point(_ m: CGPoint) -> CGPoint {
        CGPoint(x: offset.x + (m.x - projection.bounds.minX) * scale,
                y: offset.y + (projection.bounds.maxY - m.y) * scale)
    }

    func point(_ c: SwingPalCourse.Coordinate) -> CGPoint { point(projection.metres(c)) }
}

// MARK: - Hole page drawing

/// The hole, drawn as a yardage-book page. Every mark comes from supplied geometry;
/// arcs are true radii from the green centre, not an estimate of the pin.
struct HolePageDrawing: View {
    let hole: SwingPalCourse.Hole
    var neighbours: [SwingPalCourse.Hole] = []
    var distanceUnit: DistanceUnit = .meters
    var showsArcs = true
    var showsCentreLine = true
    var showsScale = true
    var player: SwingPalCourse.Coordinate? = nil
    var target: SwingPalCourse.Coordinate? = nil
    var insets = EdgeInsets(top: 28, leading: 24, bottom: 22, trailing: 24)

    var body: some View {
        Canvas { context, size in
            guard let projection = HoleProjection(hole: hole) else { return }
            let frame = HolePageFrame(projection: projection, size: size, insets: insets)
            HolePageRenderer(frame: frame, hole: hole, neighbours: neighbours, unit: distanceUnit,
                             showsArcs: showsArcs, showsCentreLine: showsCentreLine, showsScale: showsScale,
                             player: player, target: target)
                .draw(in: &context)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

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

// MARK: - Thumb index

/// The book's thumb index: a strip of hole numbers at the page edge. Dragging
/// along it pages through holes with a tick at each stop; tapping jumps.
/// VoiceOver adjusts it like a stepper.
struct ThumbIndex: View {
    let numbers: [Int]
    @Binding var selection: Int
    var marked: Int? = nil
    @GestureState private var isScrubbing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let count = max(numbers.count, 1)
            let rowHeight = proxy.size.height / CGFloat(count)
            VStack(spacing: 0) {
                ForEach(Array(numbers.enumerated()), id: \.offset) { index, number in
                    let selected = index == selection
                    ZStack(alignment: .trailing) {
                        if selected {
                            UnevenRoundedRectangle(topLeadingRadius: 7, bottomLeadingRadius: 7, bottomTrailingRadius: 0, topTrailingRadius: 0, style: .continuous)
                                .fill(Book.ink)
                                .frame(width: isScrubbing && !reduceMotion ? 46 : 38)
                        }
                        HStack(spacing: 2) {
                            if marked == number {
                                Circle().fill(Book.flag).frame(width: 4, height: 4)
                            }
                            Text("\(number)")
                                .font(.system(size: min(13, rowHeight * 0.62), weight: selected ? .bold : .medium).width(.condensed))
                                .monospacedDigit()
                                .foregroundStyle(selected ? Book.paper : Book.pencil)
                        }
                        .padding(.trailing, 8)
                    }
                    .frame(width: 46, height: rowHeight, alignment: .trailing)
                }
            }
            .frame(width: 46)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isScrubbing) { _, s, _ in s = true }
                    .onChanged { value in
                        let index = min(max(Int(value.location.y / rowHeight), 0), count - 1)
                        if index != selection {
                            if reduceMotion { selection = index }
                            else { withAnimation(.snappy(duration: 0.16)) { selection = index } }
                        }
                    }
            )
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: isScrubbing)
        }
        .frame(width: 46)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hole index")
        .accessibilityValue(numbers.indices.contains(selection) ? "Hole \(numbers[selection]) of \(numbers.count)" : "")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: selection = min(selection + 1, numbers.count - 1)
            case .decrement: selection = max(selection - 1, 0)
            @unknown default: break
            }
        }
    }
}

// MARK: - Counter

/// A tally line: label on the left, the count as a figure between minus and
/// plus. VoiceOver adjusts it like a stepper.
struct BookCounter: View {
    let title: String
    var detail: String? = nil
    let value: Int
    let range: ClosedRange<Int>
    var prominent = false
    /// Unit written after the figure, e.g. "m".
    var suffix: String = ""
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(prominent ? .headline : .body)
                if let detail { Text(detail).font(.caption).foregroundStyle(Book.pencil) }
            }
            Spacer(minLength: 8)
            stepButton("minus", enabled: value > range.lowerBound) { onChange(value - 1) }
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: prominent ? 34 : 24, weight: .bold).width(.condensed))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
                if !suffix.isEmpty {
                    Text(suffix).font(.subheadline.weight(.semibold)).foregroundStyle(Book.pencil)
                }
            }
            .frame(minWidth: 40)
            .animation(.snappy(duration: 0.18), value: value)
            stepButton("plus", enabled: value < range.upperBound) { onChange(value + 1) }
        }
        .padding(.vertical, prominent ? 12 : 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(suffix.isEmpty ? "\(value)" : "\(value) \(suffix)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if value < range.upperBound { onChange(value + 1) }
            case .decrement: if value > range.lowerBound { onChange(value - 1) }
            @unknown default: break
            }
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Circle().strokeBorder(Book.ink.opacity(enabled ? 0.6 : 0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

// MARK: - Page surface

extension View {
    /// A leaf of the book: raised paper with a hairline edge.
    func bookLeaf(cornerRadius: CGFloat = 18) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Book.leaf)
                .shadow(color: Book.ink.opacity(0.06), radius: 1, y: 1)
                .shadow(color: Book.ink.opacity(0.05), radius: 14, y: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Book.rule, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Sheets

/// Rows on a leaf of paper, ruled between them: the book's grouped list.
struct BookGroup<Content: View>: View {
    var title: String?
    /// Where the rule between rows starts, so it can clear a leading icon.
    var ruleInset: CGFloat
    private let content: Content

    init(_ title: String? = nil, ruleInset: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.title = title
        self.ruleInset = ruleInset
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title { BookNote(title) }
            VStack(spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { BookHairline().padding(.leading, ruleInset) }
                        row
                    }
                }
            }
            .background(Book.leaf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Book.rule, lineWidth: 0.5))
        }
    }
}

extension View {
    /// Paper under a sheet, written in ink, with the stamp for controls.
    func bookSheetChrome() -> some View {
        background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .tint(Book.stamp)
    }

    /// A line to write on: text sits on a ruled underline.
    func bookRuledField() -> some View {
        padding(.vertical, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Book.ink.opacity(0.6)).frame(height: 1) }
    }

    /// A tick-box choice: stamped when chosen, a ruled leaf otherwise.
    func bookChoice(isSelected: Bool, cornerRadius: CGFloat = 12) -> some View {
        foregroundStyle(isSelected ? Book.onStamp : Book.ink)
            .background(isSelected ? Book.stamp : Book.leaf, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(isSelected ? Color.clear : Book.rule, lineWidth: 1))
    }
}

