import SwiftUI

/// The locker: who you are, your handicap, your bag as a carry ladder, and the
/// settings that change how the book is written (units, appearance, GPS).
struct ProfileView: View {
    let authState: AuthState
    let entitlements: EntitlementState
    let bag: Bag
    let previousRounds: [RoundHistorySummary]
    let gpsMode: AppGPSMode
    let appearanceMode: AppAppearanceMode
    let distanceUnit: DistanceUnit
    let onGPSModeChanged: (AppGPSMode) -> Void
    let onAppearanceModeChanged: (AppAppearanceMode) -> Void
    let onDistanceUnitChanged: (DistanceUnit) -> Void
    let onSignInTapped: () -> Void
    let onSignOut: () -> Void
    let onAddClubs: ([Club]) -> Void
    let onUpdateClub: (Club) -> Void
    let onDeleteClub: (UUID) -> Void
    let onWatchCompanionTapped: () -> Void
    let handicapSnapshot: HandicapIndexSnapshot
    let handicapEstimate: Double?
    let onSetManualHandicapIndex: (Double?) -> Void
    let currentUserDisplayName: String?
    let cloudProfile: PublicProfile?
    let onRefreshProfile: (() async -> Void)?
    let onSavePublicProfile: ((UserPublicProfileUpdate) async throws -> Void)?

    @State private var isBagPresented = false
    @State private var isHandicapPresented = false
    @State private var handicapText: String = ""
    @State private var isPublicProfileEditorPresented = false
    #if DEBUG
    @State private var isGreenScanTestPresented = false
    #endif

    init(
        authState: AuthState,
        entitlements: EntitlementState,
        bag: Bag,
        previousRounds: [RoundHistorySummary],
        gpsMode: AppGPSMode,
        appearanceMode: AppAppearanceMode,
        distanceUnit: DistanceUnit,
        onGPSModeChanged: @escaping (AppGPSMode) -> Void,
        onAppearanceModeChanged: @escaping (AppAppearanceMode) -> Void,
        onDistanceUnitChanged: @escaping (DistanceUnit) -> Void,
        onSignInTapped: @escaping () -> Void,
        onSignOut: @escaping () -> Void = {},
        onAddClubs: @escaping ([Club]) -> Void,
        onUpdateClub: @escaping (Club) -> Void,
        onDeleteClub: @escaping (UUID) -> Void,
        onWatchCompanionTapped: @escaping () -> Void,
        handicapSnapshot: HandicapIndexSnapshot,
        handicapEstimate: Double?,
        onSetManualHandicapIndex: @escaping (Double?) -> Void,
        currentUserDisplayName: String? = nil,
        cloudProfile: PublicProfile? = nil,
        onRefreshProfile: (() async -> Void)? = nil,
        onSavePublicProfile: ((UserPublicProfileUpdate) async throws -> Void)? = nil
    ) {
        self.authState = authState
        self.entitlements = entitlements
        self.bag = bag
        self.previousRounds = previousRounds
        self.gpsMode = gpsMode
        self.appearanceMode = appearanceMode
        self.distanceUnit = distanceUnit
        self.onGPSModeChanged = onGPSModeChanged
        self.onAppearanceModeChanged = onAppearanceModeChanged
        self.onDistanceUnitChanged = onDistanceUnitChanged
        self.onSignInTapped = onSignInTapped
        self.onSignOut = onSignOut
        self.onAddClubs = onAddClubs
        self.onUpdateClub = onUpdateClub
        self.onDeleteClub = onDeleteClub
        self.onWatchCompanionTapped = onWatchCompanionTapped
        self.handicapSnapshot = handicapSnapshot
        self.handicapEstimate = handicapEstimate
        self.onSetManualHandicapIndex = onSetManualHandicapIndex
        self.currentUserDisplayName = currentUserDisplayName
        self.cloudProfile = cloudProfile
        self.onRefreshProfile = onRefreshProfile
        self.onSavePublicProfile = onSavePublicProfile
    }

    var body: some View {
        let model = ProfileViewModel(authState: authState, entitlements: entitlements, bag: bag, gpsMode: gpsMode)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    identity(model: model)
                    handicapSection
                    bagSection
                    settingsSection(model: model)
                    companionSection(model: model)
                    accountSection
                    #if DEBUG
                    developerSection
                    #endif
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .refreshable { if let onRefreshProfile { await onRefreshProfile() } }
            .background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isBagPresented) {
                ProfileBagManagementView(
                    bag: bag,
                    distanceUnit: distanceUnit,
                    onAddClubs: onAddClubs,
                    onUpdateClub: onUpdateClub,
                    onDeleteClub: onDeleteClub
                )
            }
            .sheet(isPresented: $isHandicapPresented) { handicapSheet }
            .sheet(isPresented: $isPublicProfileEditorPresented) {
                if let save = onSavePublicProfile {
                    PublicProfileEditorSheet(
                        snapshot: cloudProfile,
                        fallbackDisplayName: currentUserDisplayName,
                        onSave: save,
                        onDismiss: { isPublicProfileEditorPresented = false }
                    )
                }
            }
        }
        .tint(Book.stamp)
    }

    private var trimmedPublicBio: String? {
        let raw = cloudProfile?.bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? nil : raw
    }

    // MARK: Identity

    private func identity(model: ProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SwingPal")
                .font(.system(.headline, weight: .heavy).width(.expanded))
            HStack(alignment: .center, spacing: 16) {
                avatar
                VStack(alignment: .leading, spacing: 4) {
                    Text(authState == .authenticated ? (currentUserDisplayName ?? model.identityTitle) : "Guest golfer")
                        .font(Book.Typeface.display)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(authState == .authenticated ? model.statusTitle : "Rounds stay on this iPhone until you sign in.")
                        .font(.subheadline)
                        .foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let trimmedPublicBio {
                Text(trimmedPublicBio).font(.body).fixedSize(horizontal: false, vertical: true)
            }
            if authState == .guest {
                Button(action: onSignInTapped) {
                    HStack {
                        Text("Sign in")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(BookStampButtonStyle())
            }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle().strokeBorder(Book.ink.opacity(0.6), lineWidth: 1.25)
            if authState != .guest,
               let raw = cloudProfile?.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !raw.isEmpty, let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: initials
                    default: ProgressView()
                    }
                }
                .clipShape(Circle())
                .padding(3)
            } else {
                initials
            }
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Text(String((currentUserDisplayName ?? "G").prefix(1)).uppercased())
            .font(.system(size: 28, weight: .bold).width(.condensed))
    }

    // MARK: Handicap

    private var handicapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BookSectionRule(title: "Handicap")
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                if handicapSnapshot.manualIndex == nil && handicapEstimate == nil {
                    Text("Not set")
                        .font(Book.Typeface.title)
                        .foregroundStyle(Book.pencil)
                } else {
                    Text(handicapFigure)
                        .font(.system(size: 64, weight: .bold).width(.condensed))
                        .monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 2) {
                    if handicapSnapshot.manualIndex != nil || handicapEstimate != nil {
                        BookNote(handicapSnapshot.manualIndex != nil ? "Handicap Index" : "Estimate")
                    }
                    Text(handicapSecondaryValue)
                        .font(.caption)
                        .foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            Button {
                handicapText = handicapSnapshot.manualIndex.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? ""
                isHandicapPresented = true
            } label: {
                Label(handicapSnapshot.manualIndex == nil ? "Enter your index" : "Edit index", systemImage: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private var handicapFigure: String {
        if let manual = handicapSnapshot.manualIndex { return manual.formatted(.number.precision(.fractionLength(1))) }
        if let estimate = handicapEstimate { return estimate.formatted(.number.precision(.fractionLength(1))) }
        return "–"
    }

    private var handicapSecondaryValue: String {
        if handicapSnapshot.manualIndex != nil { return "Entered by you and used across the app." }
        if handicapEstimate != nil { return "From finished rounds against par. Not an official index." }
        return "Enter your index, or finish a few full rounds for an estimate."
    }

    private var handicapSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Handicap Index")
                    .font(Book.Typeface.display)
                Text("Enter your official index, for example 12.4. Leave it blank to use SwingPal’s par-based estimate once you’ve finished a few full rounds.")
                    .font(.subheadline)
                    .foregroundStyle(Book.pencil)
                TextField("12.4", text: $handicapText)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 48, weight: .bold).width(.condensed))
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) { Rectangle().fill(Book.ink.opacity(0.7)).frame(height: 1.25) }
                Spacer()
            }
            .padding(24)
            .background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isHandicapPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = handicapText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            onSetManualHandicapIndex(nil)
                        } else if let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
                            onSetManualHandicapIndex(value)
                        }
                        isHandicapPresented = false
                    }
                }
            }
        }
        .tint(Book.stamp)
        .presentationDetents([.medium, .large])
    }

    // MARK: Bag

    private var bagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BookSectionRule(title: "Bag", trailing: bag.clubs.isEmpty ? nil : "\(bag.clubs.count) clubs")
            Button { isBagPresented = true } label: {
                VStack(alignment: .leading, spacing: 12) {
                    if bag.clubs.isEmpty {
                        Text("No clubs yet. Add your clubs and their carries so SwingPal can suggest what to hit.")
                            .font(.subheadline)
                            .foregroundStyle(Book.pencil)
                            .multilineTextAlignment(.leading)
                    } else {
                        CarryLadder(clubs: bag.clubs, distanceUnit: distanceUnit)
                    }
                    HStack {
                        Text(bag.clubs.isEmpty ? "Add clubs" : "Edit carries and clubs")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(Book.ink)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens My bag")
            Text("Carries are the values saved in your bag, not measured shots.")
                .font(.caption)
                .foregroundStyle(Book.pencil)
        }
    }

    // MARK: Settings

    private func settingsSection(model: ProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            BookSectionRule(title: "How the book is written").padding(.bottom, 8)
            settingRow("Distances") {
                Picker("Distance units", selection: Binding(get: { distanceUnit }, set: { onDistanceUnitChanged($0) })) {
                    Text("Metres").tag(DistanceUnit.meters)
                    Text("Yards").tag(DistanceUnit.yards)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }
            BookHairline()
            settingRow("Appearance") {
                Picker("Appearance", selection: Binding(get: { appearanceMode }, set: { onAppearanceModeChanged($0) })) {
                    Text("Auto").tag(AppAppearanceMode.system)
                    Text("Day").tag(AppAppearanceMode.light)
                    Text("Night").tag(AppAppearanceMode.dark)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }
            BookHairline()
            Toggle(isOn: Binding(get: { gpsMode == .testPreview }, set: { onGPSModeChanged($0 ? .testPreview : .live) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Test GPS").font(.body)
                    Text(model.gpsModeSubtitle).font(.caption).foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Book.stamp)
            .padding(.vertical, 12)
            BookHairline()
        }
    }

    private func settingRow<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title).font(.body)
                Spacer(minLength: 12)
                control()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.body)
                control()
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: Companion & account

    private func companionSection(model: ProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            BookSectionRule(title: "Extras").padding(.bottom, 4)
            Button(action: onWatchCompanionTapped) {
                HStack(spacing: 14) {
                    Image(systemName: "applewatch.side.right").font(.title3).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Watch").font(.headline)
                        Text("Connection and availability").font(.subheadline).foregroundStyle(Book.pencil)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Book.pencil)
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(BookRowButtonStyle())
            BookHairline()
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "seal").font(.title3).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.premiumTitle).font(.headline)
                    Text(model.premiumSubtitle).font(.subheadline).foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 14)
            .accessibilityElement(children: .combine)
            BookHairline()
        }
    }

    #if DEBUG
    /// Bench tests that only exist in Debug builds.
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            BookSectionRule(title: "Developer", trailing: "DEBUG").padding(.bottom, 4)
            Button { isGreenScanTestPresented = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Green scan test").font(.body)
                        Text("Read a surface's slope with LiDAR").font(.subheadline).foregroundStyle(Book.pencil)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Book.pencil)
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(BookRowButtonStyle())
            BookHairline()
        }
        .fullScreenCover(isPresented: $isGreenScanTestPresented) { GreenScanTestView() }
    }
    #endif

    @ViewBuilder private var accountSection: some View {
        if authState == .authenticated {
            VStack(alignment: .leading, spacing: 0) {
                BookSectionRule(title: "Account").padding(.bottom, 4)
                if let label = currentUserDisplayName, !label.isEmpty {
                    HStack {
                        Text("Signed in as").foregroundStyle(Book.pencil)
                        Spacer()
                        Text(label).lineLimit(1)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 12)
                    BookHairline()
                }
                if onSavePublicProfile != nil {
                    Button { isPublicProfileEditorPresented = true } label: {
                        HStack {
                            Text("Edit public profile").font(.body)
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Book.pencil)
                        }
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(BookRowButtonStyle())
                    BookHairline()
                }
                Button(role: .destructive, action: onSignOut) {
                    Text("Sign out").font(.body.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14)
                }
                .buttonStyle(BookRowButtonStyle())
                .foregroundStyle(Book.warning)
                BookHairline()
            }
        }
    }
}
