import SwiftUI

/// Strokes per card, oldest to newest, pencilled on ruled paper. The latest
/// card is ringed; the best is marked in flag ink.
struct StrokeLineChart: View {
    let rounds: [RoundHistorySummary]

    var body: some View {
        Canvas { context, size in
            let values = rounds.map { Double($0.totalStrokes) }
            guard let lo = values.min(), let hi = values.max() else { return }
            let pad = max((hi - lo) * 0.25, 2)
            let minV = lo - pad, maxV = hi + pad
            let left: CGFloat = 30, right: CGFloat = 14, top: CGFloat = 10, bottom: CGFloat = 18
            let w = size.width - left - right, h = size.height - top - bottom
            func y(_ v: Double) -> CGFloat { top + h * CGFloat(1 - (v - minV) / (maxV - minV)) }
            func x(_ i: Int) -> CGFloat { left + (values.count == 1 ? w / 2 : w * CGFloat(i) / CGFloat(values.count - 1)) }

            // Rules at whole strokes, labelled sparsely.
            let step = max(1.0, ((maxV - minV) / 4).rounded())
            var v = (minV / step).rounded(.up) * step
            while v <= maxV {
                var rule = Path()
                rule.move(to: CGPoint(x: left, y: y(v)))
                rule.addLine(to: CGPoint(x: size.width - right, y: y(v)))
                context.stroke(rule, with: .color(Book.rule), lineWidth: 1)
                context.draw(Text("\(Int(v))").font(.system(size: 10, weight: .semibold).width(.condensed)).foregroundColor(Book.pencil),
                             at: CGPoint(x: left - 6, y: y(v)), anchor: .trailing)
                v += step
            }

            var line = Path()
            for (i, value) in values.enumerated() {
                let p = CGPoint(x: x(i), y: y(value))
                if i == 0 { line.move(to: p) } else { line.addLine(to: p) }
            }
            context.stroke(line, with: .color(Book.ink.opacity(0.7)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

            let best = values.min()
            for (i, value) in values.enumerated() {
                let p = CGPoint(x: x(i), y: y(value))
                let isBest = value == best
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)),
                             with: .color(isBest ? Book.flag : Book.ink))
                if i == values.count - 1 {
                    context.stroke(Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)),
                                   with: .color(Book.ink), lineWidth: 1.2)
                }
            }
            if let first = rounds.first, let last = rounds.last {
                context.draw(Text(first.updatedAt.formatted(.dateTime.day().month(.abbreviated))).font(.system(size: 10, weight: .medium)).foregroundColor(Book.pencil),
                             at: CGPoint(x: left, y: size.height - 4), anchor: .leading)
                context.draw(Text(last.updatedAt.formatted(.dateTime.day().month(.abbreviated))).font(.system(size: 10, weight: .medium)).foregroundColor(Book.pencil),
                             at: CGPoint(x: size.width - right, y: size.height - 4), anchor: .trailing)
            }
        }
    }
}
