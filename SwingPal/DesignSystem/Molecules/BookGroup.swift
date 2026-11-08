import SwiftUI

/// Rows on a leaf of paper, ruled between them: the book's grouped list.
struct BookGroup<Content: View>: View {
    var title: String?
    /// Where the rule between rows starts, so it can clear a leading icon.
    var ruleInset: CGFloat
    private let content: Content

    init(_ title: String? = nil, ruleInset: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.title = title
        self.ruleInset = ruleInset
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title { BookNote(title) }
            VStack(spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { BookHairline().padding(.leading, ruleInset) }
                        row
                    }
                }
            }
            .background(Book.leaf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Book.rule, lineWidth: 0.5))
        }
    }
}
