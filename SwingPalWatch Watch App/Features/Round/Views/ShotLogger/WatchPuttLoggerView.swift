import SwiftUI

/// Putts: holed or missed is the one required choice, as on the phone.
struct WatchPuttLoggerView: View {
    let model: WatchRoundPresentation
    let onLog: (RoundCompanionPuttEntry) -> Void
    var onSwitchToShot: (() -> Void)? = nil

    @State private var draft = WatchPuttDraft()
    @State private var isCentre = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.strokeText).font(WatchBook.Typeface.heading)
                    Spacer(minLength: 4)
                    WatchBookNote("On the green")
                }

                HStack(spacing: 6) {
                    puttChoice("Holed", symbol: "flag.fill", isSelected: draft.holed == true) {
                        draft.holed = true
                        draft.miss = nil
                    }
                    puttChoice("Missed", symbol: "xmark", isSelected: draft.holed == false) {
                        draft.holed = false
                    }
                }

                if draft.holed == false {
                    WatchBookNote("Where it finished · optional")
                    WatchOutcomeDial(selection: $draft.miss, isCentreSelected: $isCentre, showsCentre: false)
                        .frame(height: 130)
                        .frame(maxWidth: .infinity)
                }

                Button {
                    if let entry = draft.entry { onLog(entry) }
                } label: {
                    Text(WatchBookLabels.shotConfirmTitle(context: .putt, puttHoled: draft.holed))
                }
                .buttonStyle(WatchStampButtonStyle())
                .disabled(draft.holed == nil)

                if let onSwitchToShot {
                    Button("Not on the green? Log a shot", action: onSwitchToShot)
                        .font(.caption2)
                        .foregroundStyle(WatchBook.pencil)
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
            }
        }
        .navigationTitle("Putt")
        .watchPaper()
    }

    private func puttChoice(_ title: String, symbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.footnote.weight(.semibold))
                Text(title).font(.system(.headline, weight: .bold).width(.condensed))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .watchChoice(isSelected: isSelected, cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
