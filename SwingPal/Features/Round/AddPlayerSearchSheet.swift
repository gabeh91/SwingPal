import SwiftUI

struct AddPlayerSearchSheet: View {
    let onSearch: (String) async throws -> [PublicProfile]
    let myUserId: UUID?
    let onFetchNearbyProfile: (UUID) async throws -> PublicProfile?
    let onSelect: (PublicProfile) -> Void
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var results: [PublicProfile] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var nearbyProfile: PublicProfile?
    @State private var nearbyErrorText: String?
    @StateObject private var nearby = NearbyDiscoveryCoordinator()

    var body: some View {
        NavigationStack {
            List {
                if let nearbyErrorText {
                    Section("Nearby") {
                        Text(nearbyErrorText)
                            .foregroundStyle(.secondary)
                    }
                } else if let nearbyProfile {
                    Section("Nearby") {
                        Button {
                            onSelect(nearbyProfile)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(nearbyProfile.displayName?.isEmpty == false ? (nearbyProfile.displayName ?? "") : nearbyProfile.presentationName)
                                        .foregroundStyle(.primary)
                                    if let username = nearbyProfile.username, !username.isEmpty {
                                        Text("@\(username)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()
                            }
                        }
                    }
                } else if myUserId != nil {
                    Section("Nearby") {
                        HStack(spacing: 12) {
                            if nearby.isRunning {
                                ProgressView()
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(.secondary)
                            }
                            Text(nearby.isRunning ? "Looking for nearby SwingPal players…" : "Searching nearby is paused.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .foregroundStyle(.red)
                    }
                }

                if isLoading {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Searching…")
                        }
                    }
                }

                if !results.isEmpty {
                    Section("Results") {
                        ForEach(results) { profile in
                            Button {
                                onSelect(profile)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.displayName?.isEmpty == false ? (profile.displayName ?? "") : profile.presentationName)
                                            .foregroundStyle(.primary)
                                        if let username = profile.username, !username.isEmpty {
                                            Text("@\(username)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()
                                }
                            }
                        }
                    }
                } else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isLoading, errorText == nil {
                    Section {
                        Text("No matching players.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Text("Search by username or name.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
            .searchable(text: $query, prompt: "Search SwingPal players")
            .onChange(of: query) { _, newValue in
                Task { await runSearch(newValue) }
            }
            .onChange(of: nearby.discoveredUserId) { _, newValue in
                guard let newValue else { return }
                Task { await fetchNearbyProfileIfNeeded(userId: newValue) }
            }
            .task {
                startNearbyIfPossible()
                await runSearch(query)
            }
            .onDisappear {
                nearby.stop()
            }
        }
    }

    @MainActor
    private func runSearch(_ raw: String) async {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        errorText = nil

        guard trimmed.count >= 2 else {
            results = []
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            results = try await onSearch(trimmed)
        } catch {
            results = []
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func startNearbyIfPossible() {
        nearbyProfile = nil
        nearbyErrorText = nil

        guard let myUserId else {
            nearby.stop()
            nearbyErrorText = "Sign in to add nearby players."
            return
        }

        nearby.start(myUserId: myUserId)
    }

    @MainActor
    private func fetchNearbyProfileIfNeeded(userId: UUID) async {
        guard nearbyProfile?.id != userId else { return }

        do {
            nearbyProfile = try await onFetchNearbyProfile(userId)
            if nearbyProfile == nil {
                nearbyErrorText = "Nearby player found, but their profile isn’t available yet."
            } else {
                nearbyErrorText = nil
            }
        } catch {
            nearbyProfile = nil
            nearbyErrorText = error.localizedDescription
        }
    }
}

