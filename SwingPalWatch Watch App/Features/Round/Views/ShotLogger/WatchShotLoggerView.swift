import SwiftUI

/// Tee and full shots: the phone's landing dial, with club and lie written at
/// the top of the page. Nothing is sent until the stamp is pressed.
struct WatchShotLoggerView: View {
    let model: WatchRoundPresentation
    let onLog: (RoundCompanionShotEntry) -> Void
    var onSwitchToPutt: (() -> Void)? = nil

    @State private var draft: WatchShotDraft
    @State private var isPickingClub = false
    @State private var isPickingLie = false

    init(model: WatchRoundPresentation, onLog: @escaping (RoundCompanionShotEntry) -> Void, onSwitchToPutt: (() -> Void)? = nil) {
        self.model = model
        self.onLog = onLog
        self.onSwitchToPutt = onSwitchToPutt
        let suggested = model.snapshot?.suggestedSurface ?? .fairway
        _draft = State(initialValue: WatchShotDraft(
            clubName: model.snapshot?.selectedClubName ?? "7i",
            surface: suggested == .green ? .fairway : suggested
        ))
    }

    private var context: RoundCompanionShotContext {
        draft.surface == .tee || model.snapshot?.strokeNumber == 1 ? .tee : .shot
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.strokeText).font(WatchBook.Typeface.heading)
                    Spacer(minLength: 4)
                    Text(model.hasYardage ? "\(model.centreText) \(model.unitSuffix)" : "—")
                        .font(WatchBook.Typeface.smallFigure)
                        .foregroundStyle(WatchBook.pencil)
                }

                VStack(spacing: 0) {
                    pageLine(title: "Club", value: draft.clubName, symbol: "figure.golf") { isPickingClub = true }
                    WatchBookHairline().padding(.leading, 30)
                    pageLine(title: "Lie", value: WatchBookLabels.surface(draft.surface), symbol: WatchBookLabels.surfaceSymbol(draft.surface)) { isPickingLie = true }
                }
                .watchLeaf()

                WatchOutcomeDial(selection: $draft.outcome, isCentreSelected: $draft.isCentre, showsCentre: true)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)

                Text(draft.summary)
                    .font(.footnote.weight(draft.isComplete ? .semibold : .regular))
                    .foregroundStyle(draft.isComplete ? WatchBook.ink : WatchBook.pencil)
                    .frame(maxWidth: .infinity)

                if draft.outcome?.hasLateralMiss == true {
                    HStack(spacing: 6) {
                        intensityChoice("Normal", isSelected: !draft.isFar) { draft.isFar = false }
                        intensityChoice("Far", isSelected: draft.isFar) { draft.isFar = true }
                    }
                }

                if context == .tee {
                    Toggle("Provisional ball", isOn: $draft.isProvisional)
                        .font(.footnote)
                        .tint(WatchBook.stamp)
                }

                Button {
                    if let entry = draft.entry { onLog(entry) }
                } label: {
                    Text(WatchBookLabels.shotConfirmTitle(context: context, puttHoled: nil))
                }
                .buttonStyle(WatchStampButtonStyle())
                .disabled(!draft.isComplete)
                .sensoryFeedback(.selection, trigger: draft.summary)

                if let onSwitchToPutt {
                    Button("On the green? Log a putt", action: onSwitchToPutt)
                        .font(.caption2)
                        .foregroundStyle(WatchBook.pencil)
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
            }
        }
        .navigationTitle("Log shot")
        .watchPaper()
        .sheet(isPresented: $isPickingClub) {
            WatchClubPickerView(model: model, selectedName: draft.clubName) { name in
                draft.clubName = name
                isPickingClub = false
            }
        }
        .sheet(isPresented: $isPickingLie) {
            WatchLiePickerView(selection: draft.surface) { surface in
                draft.surface = surface
                isPickingLie = false
            }
        }
    }

    private func pageLine(title: String, value: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.caption).foregroundStyle(WatchBook.pencil).frame(width: 18)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.caption2).foregroundStyle(WatchBook.pencil)
                    Text(value).font(.footnote.weight(.semibold)).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(WatchBook.pencil)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
        }
        .buttonStyle(WatchRowButtonStyle())
        .accessibilityLabel("\(title), \(value)")
    }

    private func intensityChoice(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.footnote.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 36)
                .watchChoice(isSelected: isSelected, cornerRadius: 10)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
