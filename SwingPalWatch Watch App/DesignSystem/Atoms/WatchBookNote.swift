import SwiftUI

/// A pencil annotation: small, spaced capitals.
struct WatchBookNote: View {
    let text: String
    var color: Color = WatchBook.pencil

    init(_ text: String, color: Color = WatchBook.pencil) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(WatchBook.Typeface.note)
            .tracking(0.4)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
