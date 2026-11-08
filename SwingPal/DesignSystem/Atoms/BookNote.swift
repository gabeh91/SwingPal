import SwiftUI

/// A pencil annotation: small, spaced capitals in the secondary ink.
struct BookNote: View {
    let text: String
    var color: Color = Book.pencil
    init(_ text: String, color: Color = Book.pencil) {
        self.text = text
        self.color = color
    }
    var body: some View {
        Text(text.uppercased())
            .font(Book.Typeface.note)
            .tracking(0.6)
            .foregroundStyle(color)
    }
}
