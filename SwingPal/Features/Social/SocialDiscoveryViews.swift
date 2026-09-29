import SwiftUI

// MARK: - Follow invite (modal / sheet)

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

// MARK: - People search

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

// MARK: - Nearby + NFC

struct NearbyConnectSheet: View {
    @ObservedObject var appState: AppState
    @ObservedObject var nearbyCoordinator: NearbyDiscoveryCoordinator
    @ObservedObject var nfcScanner: NFCFollowScanner

    @Environment(\.dismiss) private var dismiss

    private var canLook: Bool { appState.currentUser.flatMap { UUID(uuidString: $0.id) } != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Follow someone standing next to you")
                            .font(Book.Typeface.heading)
                        Text("Open this on both phones and tap Start looking. SwingPal finds the other phone over Bluetooth and Wi‑Fi.")
                            .font(.subheadline)
                            .foregroundStyle(Book.pencil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if nearbyCoordinator.isRunning {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Looking for SwingPal close by…").font(.subheadline)
                        }
                    }

                    Button {
                        toggleNearby()
                    } label: {
                        HStack {
                            Text(nearbyCoordinator.isRunning ? "Stop looking" : "Start looking")
                            Spacer(minLength: 12)
                            Image(systemName: nearbyCoordinator.isRunning ? "stop.fill" : "dot.radiowaves.left.and.right")
                        }
                    }
                    .buttonStyle(BookStampButtonStyle(prominent: !nearbyCoordinator.isRunning))
                    .disabled(!canLook)

                    if !canLook {
                        Text("Sign in to find golfers nearby.")
                            .font(.footnote)
                            .foregroundStyle(Book.pencil)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        BookNote("NFC tags")
                        Text("iPhones can't swap details by tapping together, but you can scan a tag programmed with a SwingPal follow link (swingpal://follow/…).")
                            .font(.footnote)
                            .foregroundStyle(Book.pencil)
                            .fixedSize(horizontal: false, vertical: true)
                        if nfcScanner.isSupported {
                            Button {
                                nfcScanner.startScan()
                            } label: {
                                HStack {
                                    Text("Scan a tag")
                                    Spacer(minLength: 12)
                                    Image(systemName: "sensor.tag.radiowaves.forward")
                                }
                            }
                            .buttonStyle(BookStampButtonStyle(prominent: false))
                            .disabled(nfcScanner.isScanning)
                        } else {
                            Text("This device can't read NFC tags.")
                                .font(.footnote.weight(.semibold))
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(20)
            }
            .bookSheetChrome()
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        nearbyCoordinator.stop()
                        dismiss()
                    }
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
        .presentationBackground(Book.paper)
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
