import SwiftUI

/// The mark on its stamp-green tile, as it appears on the Home Screen.
struct SwingPalMarkTile: View {
    var size: CGFloat = 84

    var body: some View {
        SwingPalMark(colorway: .tile)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .stroke(Book.ink.opacity(0.08), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}
