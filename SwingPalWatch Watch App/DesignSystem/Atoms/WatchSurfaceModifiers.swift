import SwiftUI

/// A tick-box choice: stamped when chosen, a ruled leaf otherwise.
struct WatchChoiceStyle: ViewModifier {
    let isSelected: Bool
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .foregroundStyle(isSelected ? WatchBook.onStamp : WatchBook.ink)
            .background(isSelected ? WatchBook.stamp : WatchBook.leaf, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : WatchBook.rule, lineWidth: 1)
            )
    }
}

extension View {
    func watchChoice(isSelected: Bool, cornerRadius: CGFloat = 12) -> some View {
        modifier(WatchChoiceStyle(isSelected: isSelected, cornerRadius: cornerRadius))
    }

    /// Rows grouped on a leaf of paper with a hairline edge.
    func watchLeaf(cornerRadius: CGFloat = 14) -> some View {
        background(WatchBook.leaf, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(WatchBook.rule, lineWidth: 0.5)
            )
    }

    /// Paper behind a pushed screen, written in ink.
    func watchPaper() -> some View {
        foregroundStyle(WatchBook.ink)
            .tint(WatchBook.stamp)
            .containerBackground(WatchBook.paper.gradient, for: .navigation)
    }
}
