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

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    nearbySection

                    if let errorText {
                        Text(errorText)
                            .font(.subheadline)
                            .foregroundStyle(Book.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Searching…").font(.subheadline).foregroundStyle(Book.pencil)
                        }
                    }

                    if !results.isEmpty {
                        BookGroup("Players", ruleInset: 58) {
                            ForEach(results) { profile in
                                playerRow(profile)
                            }
                        }
                    } else if !trimmedQuery.isEmpty, !isLoading, errorText == nil {
                        Text("No players match “\(trimmedQuery)”.")
                            .font(.subheadline)
                            .foregroundStyle(Book.pencil)
                    } else if trimmedQuery.isEmpty {
                        Text("Search by name or username.")
                            .font(.subheadline)
                            .foregroundStyle(Book.pencil)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .bookSheetChrome()
            .navigationTitle("Add player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search SwingPal players")
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
        .presentationBackground(Book.paper)
    }

    @ViewBuilder
    private var nearbySection: some View {
        if let nearbyProfile {
            BookGroup("Nearby", ruleInset: 58) {
                playerRow(nearbyProfile, symbol: "antenna.radiowaves.left.and.right")
            }
        } else if let nearbyErrorText {
            VStack(alignment: .leading, spacing: 6) {
                BookNote("Nearby")
                Text(nearbyErrorText).font(.subheadline).foregroundStyle(Book.pencil)
            }
        } else if myUserId != nil {
            VStack(alignment: .leading, spacing: 6) {
                BookNote("Nearby")
                HStack(spacing: 10) {
                    if nearby.isRunning {
                        ProgressView()
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right").foregroundStyle(Book.pencil)
                    }
                    Text(nearby.isRunning ? "Looking for SwingPal players close by…" : "Not looking for players close by.")
                        .font(.subheadline)
                        .foregroundStyle(Book.pencil)
                }
            }
        }
    }

    private func playerRow(_ profile: PublicProfile, symbol: String? = nil) -> some View {
        let name = profile.displayName?.isEmpty == false ? (profile.displayName ?? "") : profile.presentationName
        return Button {
            onSelect(profile)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Book.wash)
                    if let symbol {
                        Image(systemName: symbol).font(.subheadline.weight(.semibold))
                    } else {
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(.headline, weight: .bold).width(.condensed))
                    }
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.body)
                    if let username = profile.username, !username.isEmpty {
                        Text("@\(username)").font(.caption).foregroundStyle(Book.pencil)
                    }
                }
                Spacer(minLength: 8)
                Text("Add")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Book.stamp)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(BookRowButtonStyle())
        .accessibilityLabel("Add \(name)")
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

