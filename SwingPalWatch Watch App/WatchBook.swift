import SwiftUI

// The yardage book on the wrist. The Watch is always dark, so it uses the
// phone's night-book values (docs/design/YARDAGE_BOOK.md) directly: paper and
// ink carry everything, the stamp is the one committed action and the flag
// colour marks the target, the player and scores under par.

enum WatchBook {
    static let paper = Color(bookHex: 0x101714)
    static let leaf = Color(bookHex: 0x18211D)
    static let wash = Color(bookHex: 0x1F2A25)
    static let rule = Color(bookHex: 0x2C3631)
    static let ink = Color(bookHex: 0xECE7DA)
    static let pencil = Color(bookHex: 0xA4AAA0)
    static let stamp = Color(bookHex: 0xCFE3C4)
    static let onStamp = Color(bookHex: 0x13241C)
    static let flag = Color(bookHex: 0xFF7452)
    static let warning = Color(bookHex: 0xFF9F80)

    // Terrain inks, used only inside the hole drawing.
    static let fairway = Color(bookHex: 0x2C4531)
    static let fairwayEdge = Color(bookHex: 0x4F7550)
    static let green = Color(bookHex: 0x3F6A3C)
    static let greenContour = Color(bookHex: 0x7DAA6E)
    static let sand = Color(bookHex: 0x6E6243)
    static let sandDot = Color(bookHex: 0xB7A06A)
    static let water = Color(bookHex: 0x274B56)
    static let waterLine = Color(bookHex: 0x5F90A0)

    enum Typeface {
        /// The hole number, fixed like the phone's folio.
        static let folio = Font.system(size: 34, weight: .bold).width(.condensed).monospacedDigit()
        static let figure = Font.system(size: 46, weight: .bold).width(.condensed).monospacedDigit()
        static let clubCode = Font.system(size: 30, weight: .bold).width(.condensed)
        static let heading = Font.system(.headline, weight: .semibold).width(.condensed)
        static let smallFigure = Font.system(.body, weight: .semibold).width(.condensed).monospacedDigit()
        static let note = Font.system(.caption2, weight: .semibold).width(.expanded)
    }
}

extension Color {
    init(bookHex hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

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

struct WatchBookHairline: View {
    var body: some View {
        Rectangle().fill(WatchBook.rule).frame(height: 1).accessibilityHidden(true)
    }
}

/// The ink stamp: the one committed action on a screen.
struct WatchStampButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? WatchBook.onStamp : WatchBook.pencil)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 10)
            .background(isEnabled ? WatchBook.stamp : WatchBook.wash, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.12), value: configuration.isPressed)
    }
}

/// A ruled row on a leaf: pressed paper darkens a little.
struct WatchRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(WatchBook.wash.opacity(configuration.isPressed ? 1 : 0))
    }
}

/// A tick-box choice: stamped when chosen, a ruled leaf otherwise.
struct WatchChoiceStyle: ViewModifier {
    let isSelected: Bool
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .foregroundStyle(isSelected ? WatchBook.onStamp : WatchBook.ink)
            .background(isSelected ? WatchBook.stamp : WatchBook.leaf, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : WatchBook.rule, lineWidth: 1)
            )
    }
}

extension View {
    func watchChoice(isSelected: Bool, cornerRadius: CGFloat = 12) -> some View {
        modifier(WatchChoiceStyle(isSelected: isSelected, cornerRadius: cornerRadius))
    }

    /// Rows grouped on a leaf of paper with a hairline edge.
    func watchLeaf(cornerRadius: CGFloat = 14) -> some View {
        background(WatchBook.leaf, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(WatchBook.rule, lineWidth: 0.5)
            )
    }

    /// Paper behind a pushed screen, written in ink.
    func watchPaper() -> some View {
        foregroundStyle(WatchBook.ink)
            .tint(WatchBook.stamp)
            .containerBackground(WatchBook.paper.gradient, for: .navigation)
    }
}

/// Scorecard notation: circle for birdie, double circle for eagle or better,
/// square for bogey, double square for double bogey or worse.
struct WatchScoreMark: View {
    let score: Int
    let par: Int
    var size: CGFloat = 52

    private var diff: Int { score - par }

    var body: some View {
        ZStack {
            if diff <= -1 {
                Circle().stroke(WatchBook.flag, lineWidth: 1.6).frame(width: size, height: size)
                if diff <= -2 {
                    Circle().stroke(WatchBook.flag, lineWidth: 1.3).frame(width: size - 8, height: size - 8)
                }
            } else if diff >= 1 {
                Rectangle().stroke(WatchBook.ink.opacity(0.8), lineWidth: 1.4).frame(width: size - 4, height: size - 4)
                if diff >= 2 {
                    Rectangle().stroke(WatchBook.ink.opacity(0.8), lineWidth: 1.2).frame(width: size - 12, height: size - 12)
                }
            }
            Text("\(score)")
                .font(.system(size: size * 0.5, weight: .semibold).width(.condensed))
                .monospacedDigit()
                .foregroundStyle(diff < 0 ? WatchBook.flag : WatchBook.ink)
                .contentTransition(.numericText(value: Double(score)))
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(score), \(WatchBookLabels.scoreName(score: score, par: par).lowercased())")
    }
}

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
