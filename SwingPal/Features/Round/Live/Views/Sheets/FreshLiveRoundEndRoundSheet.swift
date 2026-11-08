import SwiftUI

/// What the player chose on the end-round sheet. The screen acts on it once
/// the sheet has gone, so the next sheet (the card) can present cleanly.
enum FreshLiveRoundEndRoundChoice {
    case signCard
    case reviewCard
    case finishLater
    case discard
}

/// Leaving the course: the card so far, then sign it, keep it for later, or
/// throw it away.
struct FreshLiveRoundEndRoundSheet: View {
    @ObservedObject var state: LiveRoundState
    /// `nil` means keep playing.
    let onChoose: (FreshLiveRoundEndRoundChoice?) -> Void

    @State private var isConfirmingDiscard = false
    @State private var contentHeight: CGFloat = 460

    private var entries: [LiveRoundState.HoleInspectionEntry] { state.holeInspectionEntries }
    private var confirmed: [LiveRoundState.HoleInspectionEntry] { entries.filter { $0.isConfirmed && $0.score != nil } }
    private var strokes: Int { confirmed.compactMap(\.score).reduce(0, +) }
    private var isCardComplete: Bool { state.canCompleteRound }

    private var headline: String {
        if confirmed.isEmpty { return "Nothing on the card yet" }
        if confirmed.count == entries.count { return "All \(entries.count) holes on the card" }
        return "Thru \(confirmed.count) of \(entries.count)"
    }

    private var summary: String {
        guard !confirmed.isEmpty else { return state.courseName }
        return "\(state.courseName) · \(state.roundScoreToParDisplay) · \(strokes) strokes"
    }

    private var discardMessage: String {
        let holes = confirmed.count
        let scores = holes == 0 ? "Every shot you've logged" : "Your scores for \(holes) hole\(holes == 1 ? "" : "s") and every shot logged"
        return "\(scores) will be deleted. This can't be undone."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(headline)
                            .font(Book.Typeface.heading)
                            .accessibilityAddTraits(.isHeader)
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(Book.pencil)
                            .lineLimit(2)
                    }

                    card

                    VStack(spacing: 10) {
                        if isCardComplete {
                            choiceButton("Sign and save the card", symbol: "signature", prominent: true, choice: .signCard)
                            Text("You'll check every hole before it's filed with your scorecards.")
                                .font(.footnote).foregroundStyle(Book.pencil)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 6)
                            choiceButton("Save and finish later", symbol: "bookmark", prominent: false, choice: .finishLater)
                        } else {
                            choiceButton("Save and finish later", symbol: "bookmark", prominent: true, choice: .finishLater)
                            Text("Pick up at hole \(state.hole.number) from Home. A round is filed with your scorecards once every hole is on the card.")
                                .font(.footnote).foregroundStyle(Book.pencil)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 6)
                            if !confirmed.isEmpty {
                                choiceButton("Check the card", symbol: "tablecells", prominent: false, choice: .reviewCard)
                            }
                        }

                        Button { isConfirmingDiscard = true } label: {
                            Text("Discard round")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Book.warning)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 20)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Book.paper)
            .navigationTitle("End round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { onChoose(nil) } label: {
                        Image(systemName: "xmark").font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Keep playing")
                }
            }
            .foregroundStyle(Book.ink)
            .tint(Book.ink)
            .confirmationDialog("Discard this round?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("Discard round", role: .destructive) { onChoose(.discard) }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text(discardMessage)
            }
        }
        // Sized to the page so the choices sit together near the thumb.
        .presentationDetents([.height(contentHeight + 64), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Book.paper)
    }

    private func choiceButton(_ title: String, symbol: String, prominent: Bool, choice: FreshLiveRoundEndRoundChoice) -> some View {
        Button { onChoose(choice) } label: {
            HStack {
                Text(title)
                Spacer(minLength: 12)
                Image(systemName: symbol).font(.body.weight(.semibold))
            }
        }
        .buttonStyle(BookStampButtonStyle(prominent: prominent))
    }

    // MARK: The card so far

    private var nines: [[LiveRoundState.HoleInspectionEntry]] {
        entries.count > 9 ? [Array(entries.prefix(9)), Array(entries.dropFirst(9))] : [entries]
    }

    private var card: some View {
        VStack(spacing: 0) {
            ForEach(Array(nines.enumerated()), id: \.offset) { index, nine in
                if index > 0 { BookHairline() }
                nineRow(nine, label: nines.count == 1 ? "Tot" : (index == 0 ? "Out" : "In"))
            }
        }
        .padding(.horizontal, 8)
        .background(Book.leaf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Book.rule, lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
    }

    private func nineRow(_ nine: [LiveRoundState.HoleInspectionEntry], label: String) -> some View {
        let scores = nine.compactMap { $0.isConfirmed ? $0.score : nil }
        return HStack(spacing: 0) {
            ForEach(nine) { entry in
                VStack(spacing: 3) {
                    Text("\(entry.number)")
                        .font(.system(size: 11, weight: entry.isActive ? .heavy : .semibold).width(.condensed))
                        .foregroundStyle(entry.isActive ? Book.ink : Book.pencil)
                    ScoreMark(score: entry.isConfirmed ? entry.score : nil, par: entry.par, size: 24)
                }
                .frame(maxWidth: .infinity)
            }
            VStack(spacing: 3) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .semibold).width(.condensed))
                    .foregroundStyle(Book.pencil)
                Text(scores.isEmpty ? "–" : "\(scores.reduce(0, +))")
                    .font(.system(size: 16, weight: .bold).width(.condensed))
                    .monospacedDigit()
                    .foregroundStyle(scores.count == nine.count ? Book.ink : Book.pencil)
                    .frame(height: 24)
            }
            .frame(width: 38)
        }
        .padding(.vertical, 10)
    }

    private var cardAccessibilityLabel: String {
        guard !confirmed.isEmpty else { return "No holes on the card yet" }
        return "\(confirmed.count) of \(entries.count) holes on the card, \(strokes) strokes, \(state.roundScoreToParDisplay) to par"
    }
}
