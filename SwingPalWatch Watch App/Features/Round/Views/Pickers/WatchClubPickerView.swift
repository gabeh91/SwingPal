import SwiftUI

/// The bag as the phone's club sequence reads it: longest to shortest, the
/// code large, its carry and where that carry comes from beside it.
struct WatchClubPickerView: View {
    let model: WatchRoundPresentation
    let selectedName: String?
    let onPick: (String) -> Void

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(model.clubsByCarry.enumerated()), id: \.element.name) { index, club in
                        if index > 0 { WatchBookHairline() }
                        row(for: club).id(club.name)
                    }
                }
                .watchLeaf()
                WatchBookNote("Choosing a club logs nothing")
                    .padding(.top, 6)
            }
            .onAppear {
                if let selectedName { reader.scrollTo(selectedName, anchor: .center) }
            }
        }
        .navigationTitle("Club")
        .watchPaper()
    }

    private func row(for club: RoundCompanionClub) -> some View {
        let isSelected = club.name.caseInsensitiveCompare(selectedName ?? "") == .orderedSame
        let isSuggested = club.name.caseInsensitiveCompare(model.snapshot?.recommendedClubName ?? "") == .orderedSame
        return Button { onPick(club.name) } label: {
            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text(WatchBookLabels.club(club.name))
                        .font(.system(size: isSelected ? 26 : 22, weight: isSelected ? .bold : .medium).width(.condensed))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Rectangle()
                        .fill(isSelected ? WatchBook.flag : Color.clear)
                        .frame(width: 18, height: 2)
                }
                .frame(width: 44)
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.carryLabel(for: club))
                        .font(WatchBook.Typeface.smallFigure)
                    Text(isSuggested ? "Suggested" : club.isEstimated ? "Estimated" : "From your bag")
                        .font(.caption2)
                        .foregroundStyle(isSuggested ? WatchBook.flag : WatchBook.pencil)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark").font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(isSelected ? WatchBook.ink : WatchBook.ink.opacity(0.85))
            .padding(.horizontal, 8)
            .frame(minHeight: 50)
        }
        .buttonStyle(WatchRowButtonStyle())
        .accessibilityLabel("\(club.name), \(model.carryLabel(for: club)), \(club.isEstimated ? "estimated carry" : "bag carry")\(isSuggested ? ", suggested" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
