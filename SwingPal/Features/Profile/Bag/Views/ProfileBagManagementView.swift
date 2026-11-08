import SwiftUI

struct ProfileBagManagementView: View {
    let bag: Bag
    let distanceUnit: DistanceUnit
    let onAddClubs: ([Club]) -> Void
    let onUpdateClub: (Club) -> Void
    let onDeleteClub: (UUID) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isAddClubPresented = false
    @State private var editingClub: Club?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(bag.clubs.count) clubs").font(Book.Typeface.display)
                    Text("Tap a club to edit its carry. These are your bag values, not measured shot distances.")
                        .font(.subheadline).foregroundStyle(Book.pencil)
                    if !bag.clubs.isEmpty {
                        CarryLadder(clubs: bag.clubs, distanceUnit: distanceUnit)
                            .padding(.top, 8)
                    }
                }
                .listRowBackground(Color.clear)
            }
            Section("Carry distances") {
                if bag.clubs.isEmpty {
                    ContentUnavailableView("No clubs yet", systemImage: "figure.golf", description: Text("Add a club from the catalog or enter a custom club."))
                        .listRowBackground(Color.clear)
                }
                ForEach(bag.clubs) { club in
                    Button { editingClub = club } label: {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 8) {
                                identity(club)
                                distance(club)
                            }.padding(.vertical, 8)
                        } else {
                            HStack(spacing: 16) {
                                identity(club)
                                Spacer(minLength: 12)
                                distance(club)
                            }.padding(.vertical, 8)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Book.leaf)
                    .swipeActions { Button("Delete", role: .destructive) { onDeleteClub(club.id) } }
                    .accessibilityHint("Edit club and carry distance")
                    .accessibilityAction(named: "Delete club") { onDeleteClub(club.id) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(CourseStyle.ground)
        .foregroundStyle(CourseStyle.ink)
        .tint(CourseStyle.action)
        .navigationTitle("My bag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAddClubPresented = true } label: { Label("Add club", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $isAddClubPresented) {
            AddClubSheet(existingClubs: bag.clubs, distanceUnit: distanceUnit, onAddClubs: onAddClubs)
        }
        .sheet(item: $editingClub) { club in
            ProfileEditClubSheet(club: club, distanceUnit: distanceUnit, onSave: onUpdateClub)
        }
    }

    private func identity(_ club: Club) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(club.name).font(.headline)
            Text(club.subtitle ?? (club.source == .custom ? "Custom club" : "Catalog club"))
                .font(.caption).foregroundStyle(CourseStyle.muted)
        }
    }

    private func distance(_ club: Club) -> some View {
        Text(club.isPutter ? "Putter" : distanceUnit.shortLabel(forMeters: club.typicalDistanceMeters))
            .font(Book.Typeface.heading).monospacedDigit()
            .foregroundStyle(Book.ink)
    }
}
