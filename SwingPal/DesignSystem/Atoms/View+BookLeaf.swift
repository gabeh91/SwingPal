import SwiftUI

extension View {
    /// A leaf of the book: raised paper with a hairline edge.
    func bookLeaf(cornerRadius: CGFloat = 18) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Book.leaf)
                .shadow(color: Book.ink.opacity(0.06), radius: 1, y: 1)
                .shadow(color: Book.ink.opacity(0.05), radius: 14, y: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Book.rule, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}
