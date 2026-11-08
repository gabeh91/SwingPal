import SwiftUI

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
