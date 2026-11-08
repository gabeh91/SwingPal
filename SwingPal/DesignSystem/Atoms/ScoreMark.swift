import SwiftUI

/// Scorecard notation: circle for birdie, double circle for eagle or better,
/// square for bogey, double square for double bogey or worse.
struct ScoreMark: View {
    let score: Int?
    let par: Int
    var size: CGFloat = 30
    var font: Font? = nil
    var showsNumber = true

    private var diff: Int? { score.map { $0 - par } }

    var body: some View {
        ZStack {
            if let diff {
                if diff <= -1 {
                    Circle().stroke(Book.flag, lineWidth: 1.4).frame(width: size, height: size)
                    if diff <= -2 {
                        Circle().stroke(Book.flag, lineWidth: 1.2).frame(width: size - 6, height: size - 6)
                    }
                } else if diff >= 1 {
                    Rectangle().stroke(Book.ink.opacity(0.8), lineWidth: 1.2).frame(width: size - 2, height: size - 2)
                    if diff >= 2 {
                        Rectangle().stroke(Book.ink.opacity(0.8), lineWidth: 1.1).frame(width: size - 8, height: size - 8)
                    }
                }
            }
            if showsNumber {
            Text(score.map(String.init) ?? "–")
                .font(font ?? .system(size: size * 0.52, weight: .semibold).width(.condensed))
                .monospacedDigit()
                .foregroundStyle(score == nil ? Book.pencil : (diff ?? 0) < 0 ? Book.flag : Book.ink)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(score: score, par: par))
    }

    static func spoken(score: Int?, par: Int) -> String {
        guard let score else { return "No score" }
        let name: String
        switch score - par {
        case ...(-3): name = "albatross or better"
        case -2: name = "eagle"
        case -1: name = "birdie"
        case 0: name = "par"
        case 1: name = "bogey"
        case 2: name = "double bogey"
        default: name = "\(score - par) over par"
        }
        return "\(score), \(name)"
    }

    static func toParText(_ value: Int) -> String {
        value == 0 ? "E" : value > 0 ? "+\(value)" : "\(value)"
    }
}
