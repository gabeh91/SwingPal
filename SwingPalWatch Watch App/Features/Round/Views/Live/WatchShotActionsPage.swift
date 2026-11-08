import SwiftUI

/// Page two: everything else the phone's round actions offer for this shot
/// and hole, with the card for this hole at the top.
struct WatchShotActionsPage: View {
    let model: WatchRoundPresentation
    @ObservedObject var store: WatchRoundCompanionStore
    @Binding var path: [WatchRoundRoute]
    @State private var isConfirmingUndo = false
    @State private var isConfirmingRetee = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                card
                if let reason = model.recordBlockedReason {
                    Label(reason, systemImage: "iphone")
                        .font(.caption2)
                        .foregroundStyle(WatchBook.pencil)
                }
                VStack(alignment: .leading, spacing: 4) {
                    WatchBookNote("This shot")
                    VStack(spacing: 0) {
                        if model.snapshot?.ballMark != .hidden {
                            row(model.ballMarkTitle, detail: "Measure from here", symbol: model.snapshot?.ballMark == .marked ? "checkmark" : "scope") {
                                store.send(.markBall)
                            }
                            WatchBookHairline().padding(.leading, 34)
                        }
                        row(model.undoTitle, detail: model.undoDetail, symbol: "arrow.uturn.backward", enabled: model.snapshot?.canUndoLastShot == true) {
                            isConfirmingUndo = true
                        }
                        WatchBookHairline().padding(.leading, 34)
                        row("Penalty", detail: "Lost, OB, unplayable, water", symbol: "exclamationmark.triangle") {
                            path.append(.penalty)
                        }
                        WatchBookHairline().padding(.leading, 34)
                        row("Re-tee", detail: "+1 · play again from the tee", symbol: "arrow.counterclockwise") {
                            isConfirmingRetee = true
                        }
                    }
                    .watchLeaf()
                    .disabled(!model.canRecordShots)
                    .opacity(model.canRecordShots ? 1 : 0.5)
                }
                if let status = model.statusLine {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(model.isStale ? WatchBook.warning : WatchBook.pencil)
                }
            }
            .padding(.horizontal, 2)
        }
        .confirmationDialog("Undo last shot?", isPresented: $isConfirmingUndo, titleVisibility: .visible) {
            Button("Undo", role: .destructive) { store.send(.undoLastShot) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text([model.undoTitle.replacingOccurrences(of: "Undo ", with: ""), model.undoDetail].compactMap { $0 }.joined(separator: " · "))
        }
        .confirmationDialog("Re-tee from the tee?", isPresented: $isConfirmingRetee, titleVisibility: .visible) {
            Button("Re-tee · +1 penalty", role: .destructive) { store.send(.retee) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Adds a penalty stroke. Log the replayed shot as normal.")
        }
    }

    /// The hole so far, and the stamp that writes it on the card.
    private var card: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(model.folioText).font(WatchBook.Typeface.heading).monospacedDigit()
                Text(model.holeTallyText)
                    .font(.footnote)
                    .foregroundStyle(WatchBook.pencil)
                    .lineLimit(2)
            }
            Button { path.append(.score) } label: {
                HStack {
                    Text("Hole score")
                    Spacer(minLength: 2)
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(WatchStampButtonStyle())
            .disabled(!model.canRecordShots)
        }
    }

    private func row(_ title: String, detail: String? = nil, symbol: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.footnote.weight(.medium))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.footnote.weight(.semibold))
                    if let detail {
                        Text(detail).font(.caption2).foregroundStyle(WatchBook.pencil).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
        }
        .buttonStyle(WatchRowButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}
