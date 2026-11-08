import SwiftUI

/// Correcting the record for the hole on the map, without leaving the round.
struct FreshLiveRoundCurrentHoleEditorSheet: View {
    @ObservedObject var state: LiveRoundState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LiveRoundState.CurrentHoleEditDraft

    init(state: LiveRoundState) {
        self.state = state
        _draft = State(initialValue: state.makeCurrentHoleEditDraft())
    }

    private var par: Int { state.displayedHoleSession.par }
    /// The hole being played and not yet on the card: the count is a running tally, not a score.
    private var isHoleInPlay: Bool { state.isDisplayedHoleLive && !state.displayedHoleSession.isConfirmed }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .center, spacing: 14) {
                        Text(String(format: "%02d", state.displayedHoleNumber))
                            .font(Book.Typeface.folio)
                            .monospacedDigit()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Par \(par)").font(Book.Typeface.heading)
                            if isHoleInPlay {
                                Text("\(draft.score) so far · still in play")
                                    .font(.subheadline)
                                    .foregroundStyle(Book.pencil)
                            } else {
                                Text(ScoreMark.spoken(score: draft.score, par: par).components(separatedBy: ", ").last?.capitalized ?? "")
                                    .font(.subheadline)
                                    .foregroundStyle(draft.score < par ? Book.flag : Book.pencil)
                            }
                        }
                        Spacer()
                        if !isHoleInPlay {
                            ScoreMark(score: draft.score, par: par, size: 56)
                                .animation(.snappy(duration: 0.2), value: draft.score)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    VStack(spacing: 0) {
                        BookHairline()
                        BookCounter(title: "Strokes", detail: "Includes putts and penalties", value: draft.score, range: 1...20, prominent: true) { draft.score = $0 }
                        BookHairline()
                        BookCounter(title: "Putts", value: draft.putts, range: 0...10) { draft.putts = $0 }
                        BookHairline()
                        BookCounter(title: "Penalties", value: draft.penaltyCount, range: 0...10) { draft.penaltyCount = $0 }
                        BookHairline()
                        BookCounter(title: "Drops", value: draft.dropCount, range: 0...10) { draft.dropCount = $0 }
                        BookHairline()
                    }

                    noteLine("How it played", prompt: "Where the shots finished", text: Binding(
                        get: { draft.shotOutcomeSummary },
                        set: { draft.shotOutcomeSummary = $0 }
                    ))
                    noteLine("Club corrections", prompt: "Any club logged wrongly", text: Binding(
                        get: { draft.clubCorrectionSummary },
                        set: { draft.clubCorrectionSummary = $0 }
                    ))
                    noteLine("Notes", prompt: "Anything worth remembering", text: Binding(
                        get: { draft.notes },
                        set: { draft.notes = $0 }
                    ))
                }
                .padding(20)
                .padding(.bottom, 16)
            }
            .bookSheetChrome()
            .navigationTitle("Edit hole \(state.displayedHoleNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        state.applyCurrentHoleEditDraft(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Book.paper)
    }

    private func noteLine(_ title: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            BookNote(title)
            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(1...4)
                .bookRuledField()
        }
    }
}
