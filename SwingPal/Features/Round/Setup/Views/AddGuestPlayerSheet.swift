import SwiftUI

/// Writing a guest's name on the card.
struct AddGuestPlayerSheet: View {
    @State private var guestName: String = ""
    @FocusState private var isNameFocused: Bool
    let onAdd: (String) -> Void
    let onDismiss: () -> Void

    private var trimmedName: String { guestName.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Text("Their name goes on the card next to yours. Guests don't need a SwingPal account.")
                    .font(.subheadline)
                    .foregroundStyle(Book.pencil)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    BookNote("Name")
                    TextField("Guest name", text: $guestName)
                        .font(.title3)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isNameFocused)
                        .onSubmit(add)
                        .bookRuledField()
                }

                Button(action: add) {
                    HStack {
                        Text("Add to the card")
                        Spacer(minLength: 12)
                        Image(systemName: "plus")
                    }
                }
                .buttonStyle(BookStampButtonStyle())
                .disabled(trimmedName.isEmpty)

                Spacer(minLength: 0)
            }
            .padding(20)
            .bookSheetChrome()
            .navigationTitle("Add guest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
            .onAppear { isNameFocused = true }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Book.paper)
    }

    private func add() {
        guard !trimmedName.isEmpty else { return }
        onAdd(guestName)
        onDismiss()
    }
}
