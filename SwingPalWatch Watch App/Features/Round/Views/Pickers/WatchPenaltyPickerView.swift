import SwiftUI

struct WatchPenaltyPickerView: View {
    let onPick: (RoundCompanionPenalty) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(RoundCompanionPenalty.allCases.enumerated()), id: \.element) { index, penalty in
                    let label = WatchBookLabels.penalty(penalty)
                    if index > 0 { WatchBookHairline().padding(.leading, 34) }
                    Button { onPick(penalty) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: label.symbol).font(.footnote).frame(width: 20)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(label.title).font(.footnote.weight(.semibold))
                                Text(label.detail).font(.caption2).foregroundStyle(WatchBook.pencil)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .frame(minHeight: 48)
                    }
                    .buttonStyle(WatchRowButtonStyle())
                }
            }
            .watchLeaf()
            WatchBookNote("Adds one penalty stroke")
                .padding(.top, 6)
        }
        .navigationTitle("Penalty")
        .watchPaper()
    }
}
