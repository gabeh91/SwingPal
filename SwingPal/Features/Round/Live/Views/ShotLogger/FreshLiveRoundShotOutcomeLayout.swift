import SwiftUI

struct FreshLiveRoundShotOutcomeLayout {
    let canvasSize: CGSize
    let ringDiameter: CGFloat
    let ringInnerRadiusRatio: CGFloat
    let centerButtonSize: CGSize
    /// 0 = label sits on inner edge, 1 = on outer edge. 0.62 keeps it visually centered in the band.
    let labelRadialBias: CGFloat

    static let standard = FreshLiveRoundShotOutcomeLayout(
        canvasSize: CGSize(width: 280, height: 280),
        ringDiameter: 240,
        ringInnerRadiusRatio: 0.42,
        centerButtonSize: CGSize(width: 96, height: 96),
        labelRadialBias: 0.6
    )

    /// Compact variant used by the putt-miss outcome dial. There's no
    /// interactive centre button (the player has already declared the
    /// putt missed), so we let the inner cut-out be slightly larger to
    /// keep the eight sector labels comfortable.
    static let puttMiss = FreshLiveRoundShotOutcomeLayout(
        canvasSize: CGSize(width: 240, height: 240),
        ringDiameter: 220,
        ringInnerRadiusRatio: 0.46,
        centerButtonSize: CGSize(width: 80, height: 80),
        labelRadialBias: 0.62
    )

    var center: CGPoint {
        CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
    }

    var sectorAngleSpanDegrees: Double { 360.0 / 8.0 }

    func startAngleDegrees(for node: FreshLiveRoundShotOutcomeNode) -> Double {
        node.midAngleDegrees - sectorAngleSpanDegrees / 2
    }

    func endAngleDegrees(for node: FreshLiveRoundShotOutcomeNode) -> Double {
        node.midAngleDegrees + sectorAngleSpanDegrees / 2
    }

    /// Label position in the segment view's local coordinate space (origin at top-left of `ringDiameter` square).
    func labelPosition(for node: FreshLiveRoundShotOutcomeNode) -> CGPoint {
        let outerRadius = ringDiameter / 2
        let innerRadius = outerRadius * ringInnerRadiusRatio
        let labelRadius = innerRadius + ((outerRadius - innerRadius) * labelRadialBias)
        let radians = node.midAngleDegrees * .pi / 180
        return CGPoint(
            x: outerRadius + labelRadius * CGFloat(sin(radians)),
            y: outerRadius - labelRadius * CGFloat(cos(radians))
        )
    }
}
