import SwiftUI

struct WatchClubPickerView: View {
    @ObservedObject var store: WatchRoundCompanionStore
    let model: WatchRoundCompanionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Club")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(model.selectedClubText)
                        .font(.headline.weight(.semibold))
                    Text("\(model.primaryYardage) to pin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            }

            if model.showsTrustBanner {
                Section {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.trustBannerTitle)
                            .font(.caption.weight(.semibold))
                        Text(model.trustBannerDetail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                }
            }

            Section("Bag") {
                ForEach(model.clubOptions, id: \.self) { clubName in
                    Button {
                        store.sendChangeClub(named: clubName)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(clubName)
                                    .fontWeight(.semibold)
                                if clubName == model.selectedClubText {
                                    Text("Selected")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if clubName == model.selectedClubText {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(red: 0.81, green: 0.89, blue: 0.77))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Club")
    }
}
