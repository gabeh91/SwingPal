import SwiftUI

/// Blank ruled paper for a stroke line not yet drawn.
struct GraphPaper: View {
    var body: some View {
        Canvas { context, size in
            var grid = Path()
            var y: CGFloat = 0
            while y <= size.height { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y)); y += 22 }
            context.stroke(grid, with: .color(Book.rule), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
