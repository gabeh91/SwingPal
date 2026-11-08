import SwiftUI

/// A course's first hole, drawn small: its spine in the book.
struct CourseThumbnail: View {
    let course: SwingPalCourse

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Book.leaf)
            RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Book.rule)
            if let hole = course.holes.first(where: { HoleProjection(hole: $0) != nil }) {
                HolePageDrawing(hole: hole, showsArcs: false, showsCentreLine: false, showsScale: false,
                                insets: EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
            } else {
                Image(systemName: "flag").foregroundStyle(Book.pencil)
            }
        }
        .accessibilityHidden(true)
    }
}
