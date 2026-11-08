import SwiftUI

struct FollowInviteSheet: View {
    let invite: FollowInvitePresentation
    @ObservedObject var appState: AppState

    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                BookNote("Follow")
                Text(invite.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? invite.displayName! : "A golfer")
                    .font(Book.Typeface.title)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Book.pencil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorText {
                Text(errorText)
                    .font(.subheadline)
                    .foregroundStyle(Book.warning)
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Button {
                    Task { await confirm() }
                } label: {
                    HStack {
                        Text("Follow")
                        Spacer(minLength: 12)
                        if isWorking {
                            ProgressView().tint(Book.onStamp)
                        } else {
                            Image(systemName: "plus")
                        }
                    }
                }
                .buttonStyle(BookStampButtonStyle())
                .disabled(isWorking || appState.currentUser == nil)

                Button("Not now") {
                    appState.dismissFollowInvite()
                    dismiss()
                }
                .buttonStyle(BookStampButtonStyle(prominent: false))
            }
        }
        .padding(20)
        .padding(.top, 8)
        .bookSheetChrome()
        .presentationBackground(Book.paper)
        .presentationDragIndicator(.visible)
    }

    private var subtitle: String {
        if let name = invite.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return "Follow \(name) to see shared rounds in your feed."
        }
        return "Follow this golfer to see shared rounds in your feed."
    }

    private func confirm() async {
        guard appState.currentUser != nil else {
            errorText = "Sign in to follow others."
            return
        }
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        do {
            try await appState.performFollowInvite()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
