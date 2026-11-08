import SwiftUI

struct BookHairline: View {
    var color: Color = Book.rule
    var body: some View {
        Rectangle().fill(color).frame(height: 1).accessibilityHidden(true)
    }
}
