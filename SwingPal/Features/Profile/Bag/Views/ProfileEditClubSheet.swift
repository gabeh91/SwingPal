import SwiftUI

/// Changing a club's carry: the figure is the page, written large.
struct ProfileEditClubSheet: View {
    let club: Club
    let distanceUnit: DistanceUnit
    let onSave: (Club) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var distanceText: String
    @FocusState private var isDistanceFocused: Bool

    init(club: Club, distanceUnit: DistanceUnit, onSave: @escaping (Club) -> Void) {
        self.club = club
        self.distanceUnit = distanceUnit
        self.onSave = onSave
        _distanceText = State(initialValue: ClubCarryInput.text(meters: club.typicalDistanceMeters, unit: distanceUnit))
    }

    private var enteredMeters: Int? { ClubCarryInput.meters(from: distanceText, unit: distanceUnit) }
    private var canSave: Bool { club.isPutter || enteredMeters != nil }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(club.name)
                        .font(Book.Typeface.display)
                    Text(club.subtitle ?? (club.source == .custom ? "Custom club" : "Catalog club"))
                        .font(.subheadline)
                        .foregroundStyle(Book.pencil)
                }

                if club.isPutter {
                    Text("A putter has no full-swing carry to set.")
                        .font(.subheadline)
                        .foregroundStyle(Book.pencil)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        BookNote("Typical carry")
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            TextField("0", text: $distanceText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 48, weight: .bold).width(.condensed))
                                .monospacedDigit()
                                .focused($isDistanceFocused)
                                .fixedSize()
                            Text(distanceUnit.shortSuffix)
                                .font(Book.Typeface.subheading)
                                .foregroundStyle(Book.pencil)
                            Spacer(minLength: 0)
                        }
                        .bookRuledField()
                        Text("How far it flies on a good strike, before roll.")
                            .font(.caption)
                            .foregroundStyle(Book.pencil)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    guard let meters = club.isPutter ? club.typicalDistanceMeters : enteredMeters else { return }
                    onSave(
                        Club(
                            id: club.id,
                            name: club.name,
                            typicalDistanceMeters: meters,
                            brand: club.brand,
                            family: club.family,
                            source: club.source,
                            category: club.category
                        )
                    )
                    dismiss()
                } label: {
                    HStack {
                        Text("Save club")
                        Spacer(minLength: 12)
                        Image(systemName: "checkmark")
                    }
                }
                .buttonStyle(BookStampButtonStyle())
                .disabled(!canSave)
            }
            .padding(20)
            .bookSheetChrome()
            .navigationTitle("Edit club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { if !club.isPutter { isDistanceFocused = true } }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Book.paper)
    }
}
