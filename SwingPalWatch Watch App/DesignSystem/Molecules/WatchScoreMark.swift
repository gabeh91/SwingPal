import SwiftUI

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
