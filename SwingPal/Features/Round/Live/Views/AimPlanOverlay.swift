import CoreLocation
import MapKit
import SwiftUI

/// Bumped on every camera frame. The live screen owns one but never reads it
/// in its own body, so camera movement only redraws `AimPlanOverlay`.
@MainActor
final class AimCameraTicker: ObservableObject {
    @Published private(set) var tick = 0
    func advance() { tick &+= 1 }
}

/// Everything that moves with the aim: the target ring, the shot line through
/// it to the pin, the club's carry arc and the two distance pills.
///
/// It is drawn in one SwiftUI layer above the map and reprojected from map
/// coordinates on every camera frame. So the plan never swaps between MapKit
/// annotations and a SwiftUI copy (which flickered on pick-up and release), and
/// a drag moves only local state here, committing to the round once on release
/// (republishing the round on every finger movement redrew the whole screen
/// and made the drag lag).
struct AimPlanOverlay: View {
    let proxy: MapProxy
    @ObservedObject var ticker: AimCameraTicker

    let origin: CLLocationCoordinate2D
    let pin: CLLocationCoordinate2D
    let committedAim: CLLocationCoordinate2D
    /// Carry of the club in hand (or being previewed), in metres; 0 hides the arc.
    let carryMetres: Double
    let isDrawnMap: Bool

    let distanceLabel: (Int) -> String
    let clubForDistance: (Int) -> String?
    let clampToHole: (CLLocationCoordinate2D) -> CLLocationCoordinate2D
    let onDraggingChange: (Bool) -> Void
    let onCommit: (CLLocationCoordinate2D) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// The aim while a finger holds it; `nil` at rest.
    @State private var dragAim: CLLocationCoordinate2D?
    /// Finger-to-ring offset captured on pick-up, so the ring never jumps under the finger.
    @State private var grabOffset: CGSize = .zero
    @GestureState private var isHolding = false

    private var isDragging: Bool { dragAim != nil || isHolding }
    private var aim: CLLocationCoordinate2D { dragAim ?? committedAim }
    private var ink: Color { isDrawnMap ? Book.flag : .white }
    private var ringInk: Color { isDragging || isDrawnMap ? Book.flag : .white }

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .global)
            let _ = ticker.tick
            let aimPoint = project(aim, in: frame)
            let originPoint = project(origin, in: frame)
            let pinPoint = project(pin, in: frame)
            let carry = Self.metres(origin, aim)
            let remaining = Self.metres(aim, pin)

            ZStack(alignment: .topLeading) {
                if let originPoint, let aimPoint, let pinPoint {
                    if carryMetres > 0, let arc = arcPath(in: frame) {
                        arc.stroke(ink.opacity(isDrawnMap ? 0.55 : 0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }

                    Path { path in
                        path.move(to: originPoint)
                        path.addLine(to: aimPoint)
                        path.addLine(to: pinPoint)
                    }
                    .stroke(ink.opacity(0.95), style: StrokeStyle(lineWidth: isDragging ? 2.4 : 1.8, lineCap: .round, lineJoin: .round))
                    .shadow(color: .black.opacity(isDrawnMap ? 0 : 0.35), radius: 1)

                    pill(value: carry, label: "To aim")
                        .position(x: (originPoint.x + aimPoint.x) / 2, y: (originPoint.y + aimPoint.y) / 2)

                    if remaining >= 30 {
                        pill(value: remaining, label: "To green", nextClub: clubForDistance(remaining))
                            .position(x: aimPoint.x, y: aimPoint.y - 50)
                    }

                    ring
                        .position(aimPoint)
                }
            }
            .allowsHitTesting(false)
            .overlay(alignment: .topLeading) {
                // The grab target stays where the ring was picked up for the
                // whole drag: moving a view under an active gesture can cancel it.
                if let restPoint = project(committedAim, in: frame) {
                    Color.clear
                        .frame(width: 88, height: 88)
                        .contentShape(Circle())
                        .position(restPoint)
                        .highPriorityGesture(dragGesture(frame: frame, restPoint: restPoint))
                        .accessibilityHidden(true)
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isHolding) { _, holding in holding }
            .sensoryFeedback(.selection, trigger: isDragging ? clubForDistance(remaining) : nil)
        }
        .onChange(of: isHolding) { _, holding in
            if holding {
                onDraggingChange(true)
            } else if let released = dragAim {
                // Commit once, then drop the local copy in the same update so the
                // ring is drawn from the round's value without a frame in between.
                onCommit(released)
                dragAim = nil
                onDraggingChange(false)
            } else {
                onDraggingChange(false)
            }
        }
    }

    // MARK: Gesture

    /// Hold briefly to pick the ring up (so a pan that starts on it still pans
    /// the map), then drag. The ring keeps its offset from the finger.
    private func dragGesture(frame: CGRect, restPoint: CGPoint) -> some Gesture {
        LongPressGesture(minimumDuration: 0.15, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($isHolding) { value, holding, _ in
                if case .second(true, _) = value { holding = true }
            }
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                if dragAim == nil {
                    let ringOnScreen = CGPoint(x: restPoint.x + frame.minX, y: restPoint.y + frame.minY)
                    grabOffset = CGSize(width: ringOnScreen.x - drag.startLocation.x, height: ringOnScreen.y - drag.startLocation.y)
                }
                let target = CGPoint(x: drag.location.x + grabOffset.width, y: drag.location.y + grabOffset.height)
                guard let coordinate = proxy.convert(target, from: .global) else { return }
                dragAim = clampToHole(coordinate)
            }
    }

    // MARK: Drawing

    private var ring: some View {
        ZStack {
            if !isDrawnMap {
                Circle().stroke(.black.opacity(0.35), lineWidth: 4).frame(width: 40, height: 40).blur(radius: 1.5)
            }
            Circle().stroke(ringInk, lineWidth: 2.5).frame(width: 40, height: 40)
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(ringInk)
                    .frame(width: 2.5, height: 8)
                    .offset(y: -26)
                    .rotationEffect(.degrees(Double(index) * 90))
            }
            Circle().fill(ringInk).frame(width: 5, height: 5)
        }
        .frame(width: 60, height: 60)
        .scaleEffect(isDragging && !reduceMotion ? 1.12 : 1)
        .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: isDragging)
    }

    private func pill(value: Int, label: String, nextClub: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(label.uppercased()).font(Book.Typeface.noteSmall).opacity(0.75)
            Text(distanceLabel(value)).font(.system(.subheadline, weight: .bold).width(.condensed))
            if let nextClub {
                Rectangle().fill(Book.paper.opacity(0.35)).frame(width: 1, height: 12)
                Text(nextClub).font(.system(.subheadline, weight: .semibold).width(.condensed)).opacity(0.85)
            }
        }
        .monospacedDigit()
        .foregroundStyle(Book.paper)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Book.ink.opacity(reduceTransparency ? 1 : 0.84), in: Capsule())
        .fixedSize()
    }

    private func arcPath(in frame: CGRect) -> Path? {
        let direction = Self.metres(origin, aim) > 20 ? aim : pin
        let coordinates = HoleMapGeometry.arc(
            centre: origin,
            radius: carryMetres,
            centreBearing: HoleMapGeometry.bearing(from: origin, to: direction),
            halfSpread: HoleMapGeometry.arcHalfSpread(radius: carryMetres, lateralMetres: 55),
            steps: 16
        )
        let points = coordinates.compactMap { project($0, in: frame) }
        guard points.count == coordinates.count, let first = points.first else { return nil }
        var path = Path()
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        return path
    }

    // MARK: Projection

    /// `MapProxy` converts reliably only through global coordinates here.
    private func project(_ coordinate: CLLocationCoordinate2D, in frame: CGRect) -> CGPoint? {
        guard let global = proxy.convert(coordinate, to: .global) else { return nil }
        return CGPoint(x: global.x - frame.minX, y: global.y - frame.minY)
    }

    /// The same great-circle distance the round state reports, so figures
    /// don't shift by a metre on release.
    static func metres(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Int {
        Int(CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            .rounded())
    }
}
