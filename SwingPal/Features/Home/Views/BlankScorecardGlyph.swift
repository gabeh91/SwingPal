import SwiftUI

/// A blank card: two rows of nine cells, drawn in hairline.
struct BlankScorecardGlyph: View {
    var body: some View {
        Canvas { context, size in
            let cols = 9, rows = 2
            let w = size.width / CGFloat(cols), h = size.height / CGFloat(rows + 1)
            var grid = Path()
            grid.addRect(CGRect(x: 0.5, y: 0.5, width: size.width - 1, height: size.height - 1))
            for c in 1..<cols { grid.move(to: CGPoint(x: CGFloat(c) * w, y: 0)); grid.addLine(to: CGPoint(x: CGFloat(c) * w, y: size.height)) }
            for r in 1...rows { grid.move(to: CGPoint(x: 0, y: CGFloat(r) * h)); grid.addLine(to: CGPoint(x: size.width, y: CGFloat(r) * h)) }
            context.stroke(grid, with: .color(Book.pencil.opacity(0.6)), lineWidth: 0.8)
            for c in 0..<cols {
                context.draw(Text("\(c + 1)").font(.system(size: 8, weight: .semibold).width(.condensed)).foregroundColor(Book.pencil),
                             at: CGPoint(x: CGFloat(c) * w + w / 2, y: h / 2))
            }
            let mark = Path(ellipseIn: CGRect(x: 2 * w + w / 2 - 5, y: h * 1.5 - 5, width: 10, height: 10))
            context.stroke(mark, with: .color(Book.flag), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
