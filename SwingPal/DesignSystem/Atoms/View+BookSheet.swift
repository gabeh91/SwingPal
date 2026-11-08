import SwiftUI

extension View {
    /// Paper under a sheet, written in ink, with the stamp for controls.
    func bookSheetChrome() -> some View {
        background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .tint(Book.stamp)
    }

    /// A line to write on: text sits on a ruled underline.
    func bookRuledField() -> some View {
        padding(.vertical, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Book.ink.opacity(0.6)).frame(height: 1) }
    }

    /// A tick-box choice: stamped when chosen, a ruled leaf otherwise.
    func bookChoice(isSelected: Bool, cornerRadius: CGFloat = 12) -> some View {
        foregroundStyle(isSelected ? Book.onStamp : Book.ink)
            .background(isSelected ? Book.stamp : Book.leaf, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(isSelected ? Color.clear : Book.rule, lineWidth: 1))
    }
}
