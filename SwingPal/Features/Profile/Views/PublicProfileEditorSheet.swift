import SwiftUI

struct PublicProfileEditorSheet: View {
    @State private var displayName: String
    @State private var username: String
    @State private var avatarURL: String
    @State private var bio: String
    @State private var showHandicapToFollowers: Bool
    @State private var isSaving = false
    @State private var saveError: String?

    let onSave: (UserPublicProfileUpdate) async throws -> Void
    let onDismiss: () -> Void

    init(
        snapshot: PublicProfile?,
        fallbackDisplayName: String?,
        onSave: @escaping (UserPublicProfileUpdate) async throws -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _displayName = State(initialValue: snapshot?.displayName ?? fallbackDisplayName ?? "")
        _username = State(initialValue: snapshot?.username ?? "")
        _avatarURL = State(initialValue: snapshot?.avatarURL ?? "")
        _bio = State(initialValue: snapshot?.bio ?? "")
        _showHandicapToFollowers = State(initialValue: snapshot?.showHandicapToFollowers ?? false)
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("How other golfers see you when they search, follow you or play with you.")
                        .font(.subheadline)
                        .foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)

                    field("Display name", prompt: "Your name", text: $displayName)
                    field("Username", prompt: "Optional", text: $username, plain: true)
                    field("Photo link", prompt: "Optional image URL", text: $avatarURL, plain: true)

                    VStack(alignment: .leading, spacing: 6) {
                        BookNote("About")
                        TextField("A line or two about your game", text: $bio, axis: .vertical)
                            .lineLimit(2...6)
                            .bookRuledField()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Share handicap with followers", isOn: $showHandicapToFollowers)
                            .tint(Book.stamp)
                        Text("People who follow you can see the handicap index you keep in SwingPal.")
                            .font(.caption)
                            .foregroundStyle(Book.pencil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Book.leaf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Book.rule, lineWidth: 0.5))

                    if let saveError {
                        Text(saveError)
                            .font(.subheadline)
                            .foregroundStyle(Book.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }
            .bookSheetChrome()
            .navigationTitle("Public profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationBackground(Book.paper)
    }

    private func field(_ title: String, prompt: String, text: Binding<String>, plain: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            BookNote(title)
            TextField(prompt, text: text)
                .textInputAutocapitalization(plain ? .never : .words)
                .autocorrectionDisabled(plain)
                .bookRuledField()
        }
    }

    private func save() async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            saveError = "Display name is required."
            return
        }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAvatar = avatarURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBioText = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        let update = UserPublicProfileUpdate(
            display_name: trimmedName,
            username: trimmedUser.isEmpty ? nil : trimmedUser,
            avatar_url: trimmedAvatar.isEmpty ? nil : trimmedAvatar,
            bio: trimmedBioText.isEmpty ? nil : trimmedBioText,
            show_handicap_to_followers: showHandicapToFollowers
        )
        do {
            try await onSave(update)
            onDismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
