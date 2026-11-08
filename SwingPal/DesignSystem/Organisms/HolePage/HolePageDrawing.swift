import SwiftUI

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
