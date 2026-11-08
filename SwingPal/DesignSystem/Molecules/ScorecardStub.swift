import SwiftUI

/// A saved round as a stub torn from its card: date on the stub, course and
/// record in the body, strokes as the figure.
struct ScorecardStub: View {
    let round: RoundHistorySummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: -2) {
                Text(round.updatedAt.formatted(.dateTime.day()))
                    .font(Book.Typeface.title)
                    .monospacedDigit()
                BookNote(round.updatedAt.formatted(.dateTime.month(.abbreviated)))
            }
            .frame(minWidth: 42)

            Rectangle()
                .fill(.clear)
                .frame(width: 1)
                .overlay {
                    GeometryReader { g in
                        Path { p in
                            p.move(to: .zero)
                            p.addLine(to: CGPoint(x: 0, y: g.size.height))
                        }
                        .stroke(Book.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(round.courseName)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Book.pencil)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                Text(round.totalStrokes > 0 ? "\(round.totalStrokes)" : "–")
                    .font(Book.Typeface.figure)
                BookNote(round.status == .finished ? "Strokes" : "Draft",
                         color: round.status == .finished ? Book.pencil : Book.flag)
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the round record")
    }

    private var detail: String {
        if round.status == .finished {
            return "\(round.totalPutts) putts · \(round.totalPenalties) penalt\(round.totalPenalties == 1 ? "y" : "ies")"
        }
        return "Saved at hole \(round.holeNumber) · \(round.completedHoleCount) of \(round.totalHoleCount) confirmed"
    }
}
