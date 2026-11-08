import SwiftUI

/// A tally line: label on the left, the count as a figure between minus and
/// plus. VoiceOver adjusts it like a stepper.
struct BookCounter: View {
    let title: String
    var detail: String? = nil
    let value: Int
    let range: ClosedRange<Int>
    var prominent = false
    /// Unit written after the figure, e.g. "m".
    var suffix: String = ""
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(prominent ? .headline : .body)
                if let detail { Text(detail).font(.caption).foregroundStyle(Book.pencil) }
            }
            Spacer(minLength: 8)
            stepButton("minus", enabled: value > range.lowerBound) { onChange(value - 1) }
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: prominent ? 34 : 24, weight: .bold).width(.condensed))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
                if !suffix.isEmpty {
                    Text(suffix).font(.subheadline.weight(.semibold)).foregroundStyle(Book.pencil)
                }
            }
            .frame(minWidth: 40)
            .animation(.snappy(duration: 0.18), value: value)
            stepButton("plus", enabled: value < range.upperBound) { onChange(value + 1) }
        }
        .padding(.vertical, prominent ? 12 : 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(suffix.isEmpty ? "\(value)" : "\(value) \(suffix)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if value < range.upperBound { onChange(value + 1) }
            case .decrement: if value > range.lowerBound { onChange(value - 1) }
            @unknown default: break
            }
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Circle().strokeBorder(Book.ink.opacity(enabled ? 0.6 : 0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}
