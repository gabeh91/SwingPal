import SwiftUI

/// The book's table of contents: every hole in miniature, tee to green, numbered.
struct CourseContentsStrip: View {
    let holes: [SwingPalCourse.Hole]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(holes) { hole in
                    VStack(spacing: 4) {
                        HolePageDrawing(hole: hole, showsArcs: false, showsCentreLine: false, showsScale: false,
                                        insets: EdgeInsets(top: 4, leading: 3, bottom: 3, trailing: 3))
                            .frame(width: 30, height: 64)
                        Text("\(hole.number)")
                            .font(.system(size: 11, weight: .semibold).width(.condensed))
                            .foregroundStyle(Book.pencil)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityHidden(true)
    }
}
