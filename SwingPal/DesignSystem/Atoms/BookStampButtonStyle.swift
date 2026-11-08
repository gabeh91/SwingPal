import SwiftUI

/// The ink stamp: the one committed action on a page.
struct BookStampButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 30)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .foregroundStyle(prominent ? (isEnabled ? Book.onStamp : Book.pencil) : Book.ink)
            .background {
                let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                if prominent {
                    shape.fill(isEnabled ? Book.stamp : Book.wash)
                } else {
                    shape.strokeBorder(Book.ink.opacity(isEnabled ? 0.85 : 0.3), lineWidth: 1.25)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.12), value: configuration.isPressed)
    }
}
