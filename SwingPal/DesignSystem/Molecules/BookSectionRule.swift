import SwiftUI

/// A section marker: title, then a hairline running to the margin.
struct BookSectionRule: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title).font(Book.Typeface.heading).foregroundStyle(Book.ink)
                .accessibilityAddTraits(.isHeader)
            Rectangle().fill(Book.rule).frame(height: 1)
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] + 5 }
                .accessibilityHidden(true)
            if let trailing {
                Text(trailing).font(Book.Typeface.note).foregroundStyle(Book.pencil)
            }
        }
    }
}
