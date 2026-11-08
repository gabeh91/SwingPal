import SwiftUI

/// A row that responds like paper under a thumb: a light wash while pressed.
struct BookRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(Book.wash.opacity(configuration.isPressed ? 0.9 : 0))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
