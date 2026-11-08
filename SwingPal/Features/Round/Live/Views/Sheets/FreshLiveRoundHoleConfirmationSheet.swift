import SwiftUI

/// Writing the score on the card: the hole's par sets the scale, the score is
/// picked by its golf name or counted, and the mark it will earn on the card is
/// shown before it is committed.
struct FreshLiveRoundHoleConfirmationSheet: View {
    @ObservedObject var state: LiveRoundState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onRoundFinished: () -> Void

    private var par: Int { state.displayedHoleSession.par }
    private var score: Int { min(max(state.pendingHoleScore ?? par, 1), 20) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    quickNames
                    VStack(spacing: 0) {
                        BookHairline()
                        BookCounter(title: "Strokes", detail: "Includes putts and penalties", value: score, range: 1...20, prominent: true) { state.setPendingHoleScore($0) }
                        BookHairline()
                        BookCounter(title: "Putts", value: min(max(state.pendingHolePutts ?? 0, 0), 10), range: 0...10) { state.setPendingHolePutts($0) }
                        BookHairline()
                        BookCounter(title: "Penalties", value: min(max(state.pendingHolePenaltyCount ?? 0, 0), 10), range: 0...10) { state.setPendingHolePenaltyCount($0) }
                        BookHairline()
                        BookCounter(title: "Drops", value: min(max(state.pendingHoleDropCount ?? 0, 0), 10), range: 0...10) { state.setPendingHoleDropCount($0) }
                        BookHairline()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        BookNote("Notes")
                        TextField("Anything worth remembering", text: Binding(
                            get: { state.pendingHoleNotes ?? "" },
                            set: { state.setPendingHoleNotes($0) }
                        ), axis: .vertical)
                        .lineLimit(2, reservesSpace: true)
                        .padding(.vertical, 6)
                        .overlay(alignment: .bottom) { Rectangle().fill(Book.ink.opacity(0.6)).frame(height: 1) }
                    }
                    Button {
                        let previousHoleNumber = state.hole.number
                        guard state.confirmCurrentHole() else { return }
                        if state.hole.number == previousHoleNumber {
                            onRoundFinished()
                        }
                    } label: {
                        HStack {
                            Text(state.canInspectNextHole ? "Write it on the card" : "Write it and finish")
                            Spacer()
                            Text(state.canInspectNextHole ? "Hole \(state.displayedHoleNumber + 1)" : "Card")
                                .opacity(0.75)
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(BookStampButtonStyle())
                    .disabled(!state.canConfirmHoleSummary)
                    .sensoryFeedback(.success, trigger: state.hole.number)
                }
                .padding(20)
                .padding(.bottom, 16)
            }
            .background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .tint(Book.stamp)
            .navigationTitle("Hole score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { state.dismissHoleConfirmation() }
                }
            }
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.large])
        .presentationBackground(Book.paper)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(String(format: "%02d", state.displayedHoleNumber))
                .font(Book.Typeface.folio)
                .monospacedDigit()
            VStack(alignment: .leading, spacing: 2) {
                Text("Par \(par)").font(Book.Typeface.heading)
                Text(ScoreMark.spoken(score: score, par: par).components(separatedBy: ", ").last?.capitalized ?? "")
                    .font(.subheadline)
                    .foregroundStyle(score < par ? Book.flag : Book.pencil)
                    .contentTransition(.opacity)
            }
            Spacer()
            ScoreMark(score: score, par: par, size: 64)
                .animation(.snappy(duration: 0.2), value: score)
        }
        .accessibilityElement(children: .combine)
    }

    private var quickNames: some View {
        let options: [(String, Int)] = [("Eagle", -2), ("Birdie", -1), ("Par", 0), ("Bogey", 1), ("Double", 2), ("Triple", 3)]
        return ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(options.filter { par + $0.1 >= 1 }, id: \.0) { option in
                    let value = par + option.1
                    let selected = value == score
                    Button { state.setPendingHoleScore(value) } label: {
                        VStack(spacing: 4) {
                            ScoreMark(score: value, par: par, size: 30)
                            Text(option.0).font(.caption.weight(selected ? .bold : .regular))
                        }
                        .frame(width: 62, height: 70)
                        .background(selected ? Book.leaf : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(selected ? Book.ink : Book.rule, lineWidth: selected ? 1.25 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(option.0), \(value)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: score)
    }
}
