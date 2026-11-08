import SwiftUI

/// Write it on the card: the score the hole earns, chosen with the Digital
/// Crown or the steppers, shown in scorecard notation before it is committed.
struct WatchHoleScoreView: View {
    let model: WatchRoundPresentation
    let onWrite: (_ score: Int, _ putts: Int) -> Void

    @State private var crown: Double
    @State private var putts: Int
    @State private var hasEdited = false

    private static let scoreRange = 1...15

    init(model: WatchRoundPresentation, onWrite: @escaping (_ score: Int, _ putts: Int) -> Void) {
        self.model = model
        self.onWrite = onWrite
        _crown = State(initialValue: Double(model.snapshot?.proposedHoleScore ?? model.snapshot?.par ?? 4))
        _putts = State(initialValue: model.snapshot?.proposedHolePutts ?? 0)
    }

    private var par: Int { model.snapshot?.par ?? 4 }
    private var score: Int { min(max(Int(crown.rounded()), Self.scoreRange.lowerBound), Self.scoreRange.upperBound) }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(model.folioText).font(WatchBook.Typeface.folio)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(model.parText).font(WatchBook.Typeface.heading)
                        Text(WatchBookLabels.scoreName(score: score, par: par))
                            .font(.caption2)
                            .foregroundStyle(score < par ? WatchBook.flag : WatchBook.pencil)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    stepButton("minus", enabled: score > Self.scoreRange.lowerBound) { setScore(score - 1) }
                    WatchScoreMark(score: score, par: par, size: 58)
                        .frame(maxWidth: .infinity)
                        .focusable()
                        .digitalCrownRotation(
                            Binding(get: { crown }, set: { value in
                                if value.rounded() != crown.rounded() { hasEdited = true }
                                crown = value
                            }),
                            from: Double(Self.scoreRange.lowerBound),
                            through: Double(Self.scoreRange.upperBound),
                            by: 1,
                            sensitivity: .low,
                            isContinuous: false,
                            isHapticFeedbackEnabled: true
                        )
                    stepButton("plus", enabled: score < Self.scoreRange.upperBound) { setScore(score + 1) }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Strokes")
                .accessibilityValue("\(score), \(WatchBookLabels.scoreName(score: score, par: par).lowercased())")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: setScore(score + 1)
                    case .decrement: setScore(score - 1)
                    @unknown default: break
                    }
                }

                WatchBookCounter(title: "Putts", value: min(putts, score), range: 0...min(score, 10)) { value in
                    hasEdited = true
                    putts = value
                }

                if let penalties = model.snapshot?.penaltyCount, penalties > 0 {
                    Text(penalties == 1 ? "Includes 1 penalty stroke" : "Includes \(penalties) penalty strokes")
                        .font(.caption2)
                        .foregroundStyle(WatchBook.pencil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    onWrite(score, min(putts, score))
                } label: {
                    HStack {
                        Text(isLastHole ? "Write it and finish" : "Write it on the card")
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 2)
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(WatchStampButtonStyle())
                .disabled(!model.canRecordShots)
            }
        }
        .navigationTitle("Hole score")
        .watchPaper()
        .onChange(of: model.snapshot?.proposedHoleScore) { _, proposed in
            // A holed putt reaches the iPhone after this form opens; follow its
            // count until the golfer changes anything.
            guard !hasEdited, let proposed else { return }
            crown = Double(proposed)
            putts = model.snapshot?.proposedHolePutts ?? putts
        }
    }

    private var isLastHole: Bool {
        guard let snapshot = model.snapshot else { return false }
        return snapshot.holeNumber >= snapshot.holeCount
    }

    private func setScore(_ value: Int) {
        hasEdited = true
        crown = Double(min(max(value, Self.scoreRange.lowerBound), Self.scoreRange.upperBound))
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(Circle().strokeBorder(WatchBook.ink.opacity(enabled ? 0.6 : 0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}
