import SwiftUI

struct PeopleSearchSheet: View {
    @ObservedObject var appState: AppState

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [PublicProfile] = []
    @State private var following: Set<UUID> = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isSearching && results.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Searching…").font(.subheadline).foregroundStyle(Book.pencil)
                        }
                    } else if results.isEmpty {
                        Text(trimmedQuery.count < 2 ? "Search by name or username — two letters or more." : "No golfers match “\(trimmedQuery)”.")
                            .font(.subheadline)
                            .foregroundStyle(Book.pencil)
                    } else {
                        BookGroup("Golfers", ruleInset: 60) {
                            ForEach(results) { profile in
                                golferRow(profile)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .bookSheetChrome()
            .navigationTitle("Find golfers")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name or username")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onChange(of: query) { _, newValue in
                scheduleSearch(newValue)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationBackground(Book.paper)
        .task {
            await refreshFollowing()
        }
        .onChange(of: appState.followInvite) { _, newValue in
            if newValue == nil {
                Task { await refreshFollowing() }
            }
        }
    }

    private func golferRow(_ profile: PublicProfile) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Book.wash)
                Text(String(profile.presentationName.prefix(1)).uppercased())
                    .font(.system(.headline, weight: .bold).width(.condensed))
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.presentationName).font(.body)
                if let displayName = profile.displayName, !displayName.isEmpty, profile.username != nil {
                    Text(displayName).font(.caption).foregroundStyle(Book.pencil)
                }
            }
            Spacer(minLength: 8)
            if following.contains(profile.id) {
                Text("FOLLOWING")
                    .font(Book.Typeface.noteSmall)
                    .foregroundStyle(Book.pencil)
            } else {
                Button("Follow") {
                    appState.presentFollowInvite(userId: profile.id, displayName: profile.presentationName)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Book.onStamp)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Book.stamp, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .buttonStyle(.plain)
                .disabled(appState.currentUser == nil)
                .opacity(appState.currentUser == nil ? 0.4 : 1)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
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
