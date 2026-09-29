import SwiftUI

/// The round as a real scorecard: out and in nines, par row, scores in
/// scorecard notation, putts, then the hole-by-hole record with its
/// confirmation state. Every cell opens the same correction form.
struct RoundReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedHole: ReviewHoleSelection?
    @ObservedObject var state: LiveRoundState
    let onInspectHole: (Int) -> Void
    let onDone: () -> Void

    private var entries: [LiveRoundState.HoleInspectionEntry] { state.holeInspectionEntries }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                header
                totals
                if dynamicTypeSize.isAccessibilitySize {
                    holeRecord
                } else {
                    card
                    holeRecord
                }
                companions
                saveSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Book.paper.ignoresSafeArea())
        .foregroundStyle(Book.ink)
        .tint(Book.stamp)
        .navigationTitle("Scorecard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Book.paper, for: .navigationBar)
        .sheet(item: $selectedHole) { selection in
            RoundReviewHoleEditor(
                entry: selection.entry,
                canEdit: selection.index <= (entries.firstIndex(where: \.isActive) ?? -1),
                onInspect: { onInspectHole(selection.index) },
                onSave: { score, putts in
                    let previousIndex = entries.firstIndex(where: \.isDisplayed)
                    state.inspectHole(at: selection.index)
                    state.updateInspectedHoleScore(score)
                    if let putts { state.updateInspectedHolePutts(putts) }
                    if let previousIndex { state.inspectHole(at: previousIndex) }
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back to round") { dismiss() }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            BookNote(Date().formatted(date: .complete, time: .omitted))
            Text(state.courseName)
                .font(Book.Typeface.display)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var myStrokes: Int? { state.reviewPlayers.first(where: { !$0.isGuest })?.strokes }

    private var toPar: Int? {
        let scored = entries.filter { $0.score != nil }
        guard !scored.isEmpty else { return nil }
        return scored.reduce(0) { $0 + ($1.score ?? 0) - $1.par }
    }

    private var totalPutts: Int? {
        let putts = entries.compactMap(\.putts)
        return putts.isEmpty ? nil : putts.reduce(0, +)
    }

    private var totals: some View {
        VStack(spacing: 0) {
            BookHairline(color: Book.ink.opacity(0.85))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) { totalFigures(stacked: false) }
                VStack(alignment: .leading, spacing: 0) { totalFigures(stacked: true) }
            }
            BookHairline()
        }
    }

    @ViewBuilder private func totalFigures(stacked: Bool) -> some View {
        let figures: [(String, String, Bool)] = [
            ("Strokes", myStrokes.map(String.init) ?? "–", false),
            ("To par", toPar.map(ScoreMark.toParText) ?? "–", (toPar ?? 0) < 0),
            ("Putts", totalPutts.map(String.init) ?? "–", false),
            ("Holes", "\(state.roundConfirmedHoleCount)/\(state.roundTotalHoleCount)", false)
        ]
        ForEach(Array(figures.enumerated()), id: \.offset) { index, figure in
            VStack(alignment: .leading, spacing: 0) {
                Text(figure.1)
                    .font(.system(size: 36, weight: .bold).width(.condensed))
                    .monospacedDigit()
                    .foregroundStyle(figure.2 ? Book.flag : Book.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                BookNote(figure.0)
            }
            .frame(maxWidth: stacked ? nil : .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.leading, stacked || index == 0 ? 0 : 10)
            .overlay(alignment: .leading) {
                if !stacked && index > 0 { Rectangle().fill(Book.rule).frame(width: 1) }
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: The card

    private var nines: [[IndexedEntry]] {
        let indexed = entries.enumerated().map { IndexedEntry(offset: $0.offset, element: $0.element) }
        guard indexed.count > 9 else { return [indexed] }
        return [Array(indexed.prefix(9)), Array(indexed.dropFirst(9))]
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(nines.enumerated()), id: \.offset) { nineIndex, nine in
                nineGrid(nine, label: nines.count == 1 ? "Total" : (nineIndex == 0 ? "Out" : "In"))
            }
            legend
        }
    }

    private func nineGrid(_ nine: [IndexedEntry], label: String) -> some View {
        let parTotal = nine.reduce(0) { $0 + $1.element.par }
        let scores = nine.compactMap { $0.element.score }
        let putts = nine.compactMap { $0.element.putts }
        let complete = scores.count == nine.count
        return Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                rowLabel("Hole")
                ForEach(nine) { item in
                    Text("\(item.element.number)")
                        .font(.system(size: 12, weight: .bold).width(.condensed))
                        .foregroundStyle(item.element.isActive ? Book.onStamp : Book.ink)
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .background(item.element.isActive ? Book.stamp : Book.wash)
                }
                Text(label)
                    .font(.system(size: 12, weight: .bold).width(.condensed))
                    .frame(width: 40, height: 26)
                    .background(Book.wash)
            }
            GridRow {
                rowLabel("Par")
                ForEach(nine) { item in
                    Text("\(item.element.par)")
                        .font(.system(size: 12, weight: .medium).width(.condensed))
                        .foregroundStyle(Book.pencil)
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
                Text("\(parTotal)")
                    .font(.system(size: 12, weight: .medium).width(.condensed))
                    .foregroundStyle(Book.pencil)
                    .frame(width: 40)
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Book.rule).frame(height: 1) }
            GridRow {
                rowLabel("Score")
                ForEach(nine) { item in
                    Button { selectedHole = .init(index: item.offset, entry: item.element) } label: {
                        ScoreMark(score: item.element.score, par: item.element.par, size: 25)
                            .opacity(item.element.isConfirmed || item.element.score == nil ? 1 : 0.55)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hole \(item.element.number), par \(item.element.par). \(ScoreMark.spoken(score: item.element.score, par: item.element.par))")
                    .accessibilityHint("Opens the hole record")
                }
                Text(scores.isEmpty ? "–" : "\(scores.reduce(0, +))")
                    .font(.system(size: 17, weight: .bold).width(.condensed))
                    .monospacedDigit()
                    .foregroundStyle(complete ? Book.ink : Book.pencil)
                    .frame(width: 40)
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Book.rule).frame(height: 1) }
            GridRow {
                rowLabel("Putts")
                ForEach(nine) { item in
                    Text(item.element.putts.map(String.init) ?? "·")
                        .font(.system(size: 12, weight: .medium).width(.condensed))
                        .foregroundStyle(Book.pencil)
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
                Text(putts.isEmpty ? "–" : "\(putts.reduce(0, +))")
                    .font(.system(size: 12, weight: .semibold).width(.condensed))
                    .foregroundStyle(Book.pencil)
                    .frame(width: 40)
            }
        }
        .monospacedDigit()
        .background(Book.leaf)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Book.ink.opacity(0.55), lineWidth: 1))
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold).width(.expanded))
            .foregroundStyle(Book.pencil)
            .frame(width: 44, alignment: .leading)
            .padding(.leading, 6)
            .accessibilityHidden(true)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(score: 3, par: 4, text: "Birdie")
            legendItem(score: 2, par: 4, text: "Eagle")
            legendItem(score: 5, par: 4, text: "Bogey")
            legendItem(score: 6, par: 4, text: "Double+")
        }
        .accessibilityHidden(true)
    }

    private func legendItem(score: Int, par: Int, text: String) -> some View {
        HStack(spacing: 5) {
            ScoreMark(score: score, par: par, size: 16, showsNumber: false)
            Text(text).font(.caption).foregroundStyle(Book.pencil)
        }
    }

    // MARK: Record

    private var holeRecord: some View {
        VStack(alignment: .leading, spacing: 0) {
            BookSectionRule(title: "Hole by hole").padding(.bottom, 4)
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                Button { selectedHole = .init(index: index, entry: entry) } label: {
                    HStack(alignment: .center, spacing: 14) {
                        Text(String(format: "%02d", entry.number))
                            .font(Book.Typeface.subheading)
                            .monospacedDigit()
                            .frame(minWidth: 30, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Par \(entry.par)").font(.subheadline.weight(.medium))
                            Label(status(for: entry), systemImage: entry.isConfirmed ? "checkmark" : entry.score == nil ? "circle.dashed" : "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(entry.isConfirmed ? Book.stamp : entry.score == nil ? Book.pencil : Book.warning)
                        }
                        Spacer(minLength: 8)
                        if let putts = entry.putts {
                            Text("\(putts) putt\(putts == 1 ? "" : "s")").font(.caption).foregroundStyle(Book.pencil)
                        }
                        ScoreMark(score: entry.score, par: entry.par, size: 34)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Book.pencil)
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(BookRowButtonStyle())
                .accessibilityElement(children: .combine)
                .accessibilityHint("Opens hole details, score correction and map inspection.")
                BookHairline()
            }
        }
    }

    private func status(for entry: LiveRoundState.HoleInspectionEntry) -> String {
        if entry.wasEditedAfterConfirmation { return "Confirmed · corrected" }
        return entry.isConfirmed ? "Confirmed" : (entry.score == nil ? "Not recorded" : "Needs confirmation")
    }

    @ViewBuilder private var companions: some View {
        let guests = state.reviewPlayers.filter(\.isGuest)
        if !guests.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                BookSectionRule(title: "Companions")
                Text(guests.map(\.name).joined(separator: ", ")).font(.body)
                Text("Listed on the card only. Their scores and attestation are not kept.")
                    .font(.subheadline).foregroundStyle(Book.pencil)
            }
        }
    }

    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(state.canCompleteRound ? "Every hole is confirmed." : "Some holes are still open.")
                .font(.headline)
            Text(state.canCompleteRound
                 ? "Saving files this card with your scorecards."
                 : "Save a draft to keep your scores and shots, then resume from Home. Open holes stay unfinished.")
                .font(.subheadline)
                .foregroundStyle(Book.pencil)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onDone) {
                HStack {
                    Text(state.canCompleteRound ? "Sign and save card" : "Save draft")
                    Spacer(minLength: 12)
                    Image(systemName: state.canCompleteRound ? "checkmark" : "pause")
                }
            }
            .buttonStyle(BookStampButtonStyle())
        }
    }
}

private struct IndexedEntry: Identifiable {
    let offset: Int
    let element: LiveRoundState.HoleInspectionEntry
    var id: Int { element.id }
}

private struct ReviewHoleSelection: Identifiable {
    let index: Int
    let entry: LiveRoundState.HoleInspectionEntry
    var id: Int { entry.id }
}

private struct RoundReviewHoleEditor: View {
    @Environment(\.dismiss) private var dismiss
    let entry: LiveRoundState.HoleInspectionEntry
    let canEdit: Bool
    let onInspect: () -> Void
    let onSave: (Int, Int?) -> Void
    @State private var scoreText: String
    @State private var puttsText: String

    init(entry: LiveRoundState.HoleInspectionEntry, canEdit: Bool,
         onInspect: @escaping () -> Void, onSave: @escaping (Int, Int?) -> Void) {
        self.entry = entry
        self.canEdit = canEdit
        self.onInspect = onInspect
        self.onSave = onSave
        _scoreText = State(initialValue: entry.score.map(String.init) ?? "")
        _puttsText = State(initialValue: entry.putts.map(String.init) ?? "")
    }

    private var parsedScore: Int? { Int(scoreText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var parsedPutts: Int? { Int(puttsText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var hasPuttsInput: Bool { !puttsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var canSave: Bool {
        guard canEdit, let score = parsedScore, score > 0 else { return false }
        guard hasPuttsInput else { return (entry.putts ?? 0) <= score }
        guard let putts = parsedPutts else { return false }
        return putts >= 0 && putts <= score
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        Text(String(format: "%02d", entry.number))
                            .font(.system(size: 48, weight: .bold).width(.condensed))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Par \(entry.par)").font(.headline)
                            Text(entry.isConfirmed ? "Confirmed" : "Not confirmed").font(.subheadline).foregroundStyle(Book.pencil)
                        }
                        Spacer()
                        ScoreMark(score: parsedScore, par: entry.par, size: 44)
                    }
                    .accessibilityElement(children: .combine)
                }
                .listRowBackground(Book.leaf)
                if canEdit {
                    Section {
                        LabeledContent("Total strokes") {
                            TextField("Strokes", text: $scoreText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .accessibilityLabel("Total strokes, including putts and penalties")
                        }
                        LabeledContent("Putts") {
                            TextField("Not recorded", text: $puttsText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .accessibilityLabel("Putts, optional")
                        }
                    } footer: {
                        Text("Total strokes includes putts and penalties. A blank putt field keeps the existing record. Editing a confirmed hole keeps its confirmation and marks it corrected.")
                    }
                    .listRowBackground(Book.leaf)
                    if !canSave {
                        Section {
                            Label("Enter a positive stroke total. Putts must be between zero and the stroke total.", systemImage: "info.circle")
                                .foregroundStyle(Book.pencil)
                        }
                        .listRowBackground(Book.leaf)
                    }
                } else {
                    Section {
                        Text("You haven’t reached this hole yet. Return to the active hole to record play in order.")
                    }
                    .listRowBackground(Book.leaf)
                }
                Section {
                    Button(action: onInspect) {
                        Label("Open this hole’s page", systemImage: "map").frame(minHeight: 44)
                    }
                }
                .listRowBackground(Book.leaf)
            }
            .navigationTitle("Hole \(entry.number)")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Book.paper)
            .tint(Book.stamp)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if canEdit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard canSave, let score = parsedScore else { return }
                            onSave(score, hasPuttsInput ? parsedPutts : nil)
                            dismiss()
                        }
                        .disabled(!canSave)
                    }
                }
            }
        }
    }
}
