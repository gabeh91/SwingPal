import SwiftUI

struct AddGuestPlayerSheet: View {
    @State private var guestName: String = ""
    let onAdd: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Guest name", text: $guestName)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle("Add Guest")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(guestName)
                        onDismiss()
                    }
                    .disabled(guestName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
