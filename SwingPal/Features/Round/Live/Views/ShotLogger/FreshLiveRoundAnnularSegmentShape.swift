import SwiftUI

struct FreshLiveRoundAnnularSegmentShape: Shape {
    let startAngleDegrees: Double
    let endAngleDegrees: Double
    let innerRadiusRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRadiusRatio
        let outerPoints = sampledPoints(
            center: center,
            radius: outerRadius,
            startAngleDegrees: startAngleDegrees,
            endAngleDegrees: endAngleDegrees
        )
        let innerPoints = sampledPoints(
            center: center,
            radius: innerRadius,
            startAngleDegrees: endAngleDegrees,
            endAngleDegrees: startAngleDegrees
        )

        var path = Path()
        guard let firstOuterPoint = outerPoints.first else { return path }
        path.move(to: firstOuterPoint)
        outerPoints.dropFirst().forEach { path.addLine(to: $0) }
        innerPoints.forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }

    private func sampledPoints(
        center: CGPoint,
        radius: CGFloat,
        startAngleDegrees: Double,
        endAngleDegrees: Double
    ) -> [CGPoint] {
        let angleSpan = endAngleDegrees - startAngleDegrees
        let segments = max(Int(abs(angleSpan) / 8), 6)

        return (0...segments).map { index in
            let progress = Double(index) / Double(segments)
            let angle = startAngleDegrees + (angleSpan * progress)
            let radians = angle * .pi / 180
            return CGPoint(
                x: center.x + (radius * CGFloat(sin(radians))),
                y: center.y - (radius * CGFloat(cos(radians)))
            )
        }
    }
}
