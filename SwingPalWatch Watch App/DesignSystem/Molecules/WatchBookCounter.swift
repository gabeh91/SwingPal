import SwiftUI

/// A count between minus and plus, adjustable like a stepper.
struct WatchBookCounter: View {
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(WatchBook.pencil)
                .lineLimit(1)
            Spacer(minLength: 2)
            step("minus", enabled: value > range.lowerBound) { onChange(value - 1) }
            Text("\(value)")
                .font(WatchBook.Typeface.smallFigure)
                .frame(minWidth: 22)
                .contentTransition(.numericText(value: Double(value)))
            step("plus", enabled: value < range.upperBound) { onChange(value + 1) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if value < range.upperBound { onChange(value + 1) }
            case .decrement: if value > range.lowerBound { onChange(value - 1) }
            @unknown default: break
            }
        }
    }

    private func step(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .frame(width: 32, height: 32)
                .background(Circle().strokeBorder(WatchBook.ink.opacity(enabled ? 0.6 : 0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}
