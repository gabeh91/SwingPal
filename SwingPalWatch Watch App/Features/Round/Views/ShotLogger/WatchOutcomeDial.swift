import SwiftUI

/// Eight sectors clockwise from long, with an optional centre "Hit". Tapping
/// the selected sector again clears it.
struct WatchOutcomeDial: View {
    @Binding var selection: WatchShotOutcome?
    @Binding var isCentreSelected: Bool
    let showsCentre: Bool

    private let innerRatio: CGFloat = 0.42

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let radius = diameter / 2
            ZStack {
                ForEach(WatchShotOutcome.allCases) { node in
                    let isSelected = selection == node
                    WatchAnnularSector(startDegrees: node.midAngleDegrees - 22.5, endDegrees: node.midAngleDegrees + 22.5, innerRatio: innerRatio)
                        .fill(isSelected ? WatchBook.stamp : WatchBook.leaf)
                    WatchAnnularSector(startDegrees: node.midAngleDegrees - 22.5, endDegrees: node.midAngleDegrees + 22.5, innerRatio: innerRatio)
                        .stroke(WatchBook.rule, lineWidth: 1)
                    Text(node.label)
                        .font(.system(size: 10, weight: .semibold).width(.condensed))
                        .foregroundStyle(isSelected ? WatchBook.onStamp : WatchBook.ink)
                        .position(labelPosition(for: node, radius: radius))
                }
                if showsCentre {
                    Circle()
                        .fill(isCentreSelected ? WatchBook.stamp : WatchBook.wash)
                        .frame(width: diameter * innerRatio - 8, height: diameter * innerRatio - 8)
                    Text("Hit")
                        .font(.system(.headline, weight: .bold).width(.condensed))
                        .foregroundStyle(isCentreSelected ? WatchBook.onStamp : WatchBook.ink)
                } else {
                    Image(systemName: "flag.fill").font(.footnote).foregroundStyle(WatchBook.flag)
                }
            }
            .frame(width: diameter, height: diameter)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .contentShape(Circle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    let origin = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    tap(at: value.location, origin: origin, radius: radius)
                }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Where it finished")
        .accessibilityValue(isCentreSelected ? "Centre" : selection?.spokenLabel ?? "Not chosen")
        .accessibilityAdjustableAction { direction in
            let options: [WatchShotOutcome?] = (showsCentre ? [nil] : []) + WatchShotOutcome.allCases.map { $0 }
            let current = isCentreSelected ? 0 : options.firstIndex(where: { $0 == selection && $0 != nil }) ?? -1
            let next: Int
            switch direction {
            case .increment: next = min(current + 1, options.count - 1)
            case .decrement: next = max(current - 1, 0)
            @unknown default: return
            }
            choose(options[next], centre: showsCentre && next == 0)
        }
    }

    private func tap(at location: CGPoint, origin: CGPoint, radius: CGFloat) {
        let dx = location.x - origin.x
        let dy = location.y - origin.y
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance <= radius else { return }
        if distance < radius * innerRatio {
            guard showsCentre else { return }
            choose(nil, centre: !isCentreSelected)
            return
        }
        // Clockwise from north.
        let degrees = atan2(Double(dx), Double(-dy)) * 180 / .pi
        let node = WatchShotOutcome.sector(atDegrees: degrees)
        choose(selection == node ? nil : node, centre: false)
    }

    private func choose(_ node: WatchShotOutcome?, centre: Bool) {
        selection = node
        isCentreSelected = centre
    }

    private func labelPosition(for node: WatchShotOutcome, radius: CGFloat) -> CGPoint {
        let labelRadius = radius * (innerRatio + (1 - innerRatio) * 0.58)
        let radians = node.midAngleDegrees * .pi / 180
        return CGPoint(x: radius + labelRadius * CGFloat(sin(radians)), y: radius - labelRadius * CGFloat(cos(radians)))
    }
}

struct WatchAnnularSector: Shape {
    let startDegrees: Double
    let endDegrees: Double
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        // SwiftUI angles run clockwise from east; the dial runs clockwise from north.
        let start = Angle.degrees(startDegrees - 90)
        let end = Angle.degrees(endDegrees - 90)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}
