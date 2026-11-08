import SwiftUI

struct RoundReviewHoleEditor: View {
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
