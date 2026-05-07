import SwiftUI

// MARK: - Follow invite (modal / sheet)

struct FollowInviteSheet: View {
    let invite: FollowInvitePresentation
    @ObservedObject var appState: AppState
    let palette: SocialPalette

    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
            Text("Follow golfer")
                .font(ShellTokens.Typography.sectionTitle)
                .foregroundStyle(palette.primaryText)

            Text(subtitle)
                .font(ShellTokens.Typography.body)
                .foregroundStyle(palette.secondaryText)

            if let errorText {
                Text(errorText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red.opacity(0.9))
            }

            HStack(spacing: ShellTokens.Spacing.x12) {
                Button("Not now") {
                    appState.dismissFollowInvite()
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await confirm() }
                } label: {
                    if isWorking {
                        ProgressView()
                            .tint(palette.accentForeground)
                    } else {
                        Text("Follow")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
                .disabled(isWorking || appState.currentUser == nil)
            }
        }
        .padding(ShellTokens.Spacing.x20)
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

// MARK: - People search

struct PeopleSearchSheet: View {
    @ObservedObject var appState: AppState
    let palette: SocialPalette

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [PublicProfile] = []
    @State private var following: Set<UUID> = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(palette.tertiaryText)
                        TextField("Name or username", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(palette.primaryText)
                            .onChange(of: query) { _, newValue in
                                scheduleSearch(newValue)
                            }
                    }
                    .listRowBackground(palette.cardMutedTint)
                }

                Section("Results") {
                    if isSearching && results.isEmpty {
                        ProgressView()
                            .listRowBackground(palette.cardMutedTint)
                    } else if results.isEmpty {
                        Text(query.trimmingCharacters(in: .whitespaces).count < 2
                             ? "Type at least two characters."
                             : "No golfers match that search.")
                            .font(ShellTokens.Typography.body)
                            .foregroundStyle(palette.secondaryText)
                            .listRowBackground(palette.cardMutedTint)
                    } else {
                        ForEach(results) { profile in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.presentationName)
                                        .font(.headline)
                                        .foregroundStyle(palette.primaryText)
                                    if let dn = profile.displayName,
                                       !dn.isEmpty,
                                       profile.username != nil {
                                        Text(dn)
                                            .font(.caption)
                                            .foregroundStyle(palette.tertiaryText)
                                    }
                                }
                                Spacer()
                                if following.contains(profile.id) {
                                    Text("Following")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(palette.tertiaryText)
                                } else {
                                    Button("Follow") {
                                        appState.presentFollowInvite(userId: profile.id, displayName: profile.presentationName)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(palette.accent)
                                    .disabled(appState.currentUser == nil)
                                }
                            }
                            .listRowBackground(palette.cardMutedTint)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.backgroundBase)
            .navigationTitle("Find golfers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(palette.accent)
                }
            }
        }
        .task {
            await refreshFollowing()
        }
        .onChange(of: appState.followInvite) { _, newValue in
            if newValue == nil {
                Task { await refreshFollowing() }
            }
        }
    }

    private func scheduleSearch(_ raw: String) {
        searchTask?.cancel()
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            await runSearch(q)
        }
    }

    private func runSearch(_ q: String) async {
        guard appState.currentUser != nil else {
            results = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await appState.searchProfiles(query: q)
        } catch {
            results = []
        }
    }

    private func refreshFollowing() async {
        guard appState.currentUser != nil else {
            following = []
            return
        }
        do {
            following = try await appState.loadFollowingIds()
        } catch {
            following = []
        }
    }
}

// MARK: - Nearby + NFC

struct NearbyConnectSheet: View {
    @ObservedObject var appState: AppState
    @ObservedObject var nearbyCoordinator: NearbyDiscoveryCoordinator
    @ObservedObject var nfcScanner: NFCFollowScanner
    let palette: SocialPalette

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x18) {
                    Text("SwingPal looks for other open apps near you using Bluetooth and Wi‑Fi (Apple MultipeerConnectivity). Hold phones close and tap Start looking on both devices.")
                        .font(ShellTokens.Typography.body)
                        .foregroundStyle(palette.secondaryText)

                    Text("NFC: Program a tag with a SwingPal link (swingpal://follow/…). iOS does not let third-party apps exchange custom data by tapping two phones together; use Nearby here, or scan a programmed NFC tag.")
                        .font(.footnote)
                        .foregroundStyle(palette.tertiaryText)

                    if nearbyCoordinator.isRunning {
                        Label("Searching…", systemImage: "dot.radiowaves.left.and.right")
                            .foregroundStyle(palette.accent)
                    }

                    Button {
                        toggleNearby()
                    } label: {
                        Text(nearbyCoordinator.isRunning ? "Stop" : "Start looking nearby")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)
                    .disabled(appState.currentUser.flatMap { UUID(uuidString: $0.id) } == nil)

                    if nfcScanner.isSupported {
                        Button {
                            nfcScanner.startScan()
                        } label: {
                            Label("Scan NFC tag", systemImage: "sensor.tag.radiowaves.forward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(nfcScanner.isScanning)
                    } else {
                        Text("NFC tag reading isn’t available on this device.")
                            .font(.footnote)
                            .foregroundStyle(palette.tertiaryText)
                    }
                }
                .padding(ShellTokens.Spacing.x20)
            }
            .background(palette.backgroundBase)
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        nearbyCoordinator.stop()
                        dismiss()
                    }
                    .foregroundStyle(palette.accent)
                }
            }
            .onChange(of: nearbyCoordinator.discoveredUserId) { _, uid in
                guard let uid else { return }
                appState.presentFollowInvite(userId: uid, displayName: nil)
            }
            .onChange(of: nfcScanner.parsedUserId) { _, uid in
                guard let uid else { return }
                appState.presentFollowInvite(userId: uid, displayName: nil)
                nfcScanner.clearParsed()
            }
            .onDisappear {
                nearbyCoordinator.stop()
            }
        }
    }

    private func toggleNearby() {
        guard let uidString = appState.currentUser?.id,
              let uid = UUID(uuidString: uidString)
        else {
            return
        }
        if nearbyCoordinator.isRunning {
            nearbyCoordinator.stop()
        } else {
            nearbyCoordinator.start(myUserId: uid)
        }
    }
}
