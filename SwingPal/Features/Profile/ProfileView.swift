import SwiftUI


private struct ProfileBagManagementView: View {
    let bag: Bag
    let distanceUnit: DistanceUnit
    let onAddClubs: ([Club]) -> Void
    let onUpdateClub: (Club) -> Void
    let onDeleteClub: (UUID) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isAddClubPresented = false
    @State private var editingClub: Club?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(bag.clubs.count) clubs").font(Book.Typeface.display)
                    Text("Tap a club to edit its carry. These are your bag values, not measured shot distances.")
                        .font(.subheadline).foregroundStyle(Book.pencil)
                    if !bag.clubs.isEmpty {
                        CarryLadder(clubs: bag.clubs, distanceUnit: distanceUnit)
                            .padding(.top, 8)
                    }
                }
                .listRowBackground(Color.clear)
            }
            Section("Carry distances") {
                if bag.clubs.isEmpty {
                    ContentUnavailableView("No clubs yet", systemImage: "figure.golf", description: Text("Add a club from the catalog or enter a custom club."))
                        .listRowBackground(Color.clear)
                }
                ForEach(bag.clubs) { club in
                    Button { editingClub = club } label: {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 8) {
                                identity(club)
                                distance(club)
                            }.padding(.vertical, 8)
                        } else {
                            HStack(spacing: 16) {
                                identity(club)
                                Spacer(minLength: 12)
                                distance(club)
                            }.padding(.vertical, 8)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Book.leaf)
                    .swipeActions { Button("Delete", role: .destructive) { onDeleteClub(club.id) } }
                    .accessibilityHint("Edit club and carry distance")
                    .accessibilityAction(named: "Delete club") { onDeleteClub(club.id) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(CourseStyle.ground)
        .foregroundStyle(CourseStyle.ink)
        .tint(CourseStyle.action)
        .navigationTitle("My bag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAddClubPresented = true } label: { Label("Add club", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $isAddClubPresented) {
            AddClubSheet(existingClubs: bag.clubs, distanceUnit: distanceUnit, onAddClubs: onAddClubs)
        }
        .sheet(item: $editingClub) { club in
            ProfileEditClubSheet(club: club, distanceUnit: distanceUnit, onSave: onUpdateClub)
        }
    }

    private func identity(_ club: Club) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(club.name).font(.headline)
            Text(club.subtitle ?? (club.source == .custom ? "Custom club" : "Catalog club"))
                .font(.caption).foregroundStyle(CourseStyle.muted)
        }
    }

    private func distance(_ club: Club) -> some View {
        Text(club.isPutter ? "Putter" : distanceUnit.shortLabel(forMeters: club.typicalDistanceMeters))
            .font(Book.Typeface.heading).monospacedDigit()
            .foregroundStyle(Book.ink)
    }
}

/// Changing a club's carry: the figure is the page, written large.
private struct ProfileEditClubSheet: View {
    let club: Club
    let distanceUnit: DistanceUnit
    let onSave: (Club) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var distanceText: String
    @FocusState private var isDistanceFocused: Bool

    init(club: Club, distanceUnit: DistanceUnit, onSave: @escaping (Club) -> Void) {
        self.club = club
        self.distanceUnit = distanceUnit
        self.onSave = onSave
        _distanceText = State(initialValue: ClubCarryInput.text(meters: club.typicalDistanceMeters, unit: distanceUnit))
    }

    private var enteredMeters: Int? { ClubCarryInput.meters(from: distanceText, unit: distanceUnit) }
    private var canSave: Bool { club.isPutter || enteredMeters != nil }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(club.name)
                        .font(Book.Typeface.display)
                    Text(club.subtitle ?? (club.source == .custom ? "Custom club" : "Catalog club"))
                        .font(.subheadline)
                        .foregroundStyle(Book.pencil)
                }

                if club.isPutter {
                    Text("A putter has no full-swing carry to set.")
                        .font(.subheadline)
                        .foregroundStyle(Book.pencil)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        BookNote("Typical carry")
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            TextField("0", text: $distanceText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 48, weight: .bold).width(.condensed))
                                .monospacedDigit()
                                .focused($isDistanceFocused)
                                .fixedSize()
                            Text(distanceUnit.shortSuffix)
                                .font(Book.Typeface.subheading)
                                .foregroundStyle(Book.pencil)
                            Spacer(minLength: 0)
                        }
                        .bookRuledField()
                        Text("How far it flies on a good strike, before roll.")
                            .font(.caption)
                            .foregroundStyle(Book.pencil)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    guard let meters = club.isPutter ? club.typicalDistanceMeters : enteredMeters else { return }
                    onSave(
                        Club(
                            id: club.id,
                            name: club.name,
                            typicalDistanceMeters: meters,
                            brand: club.brand,
                            family: club.family,
                            source: club.source,
                            category: club.category
                        )
                    )
                    dismiss()
                } label: {
                    HStack {
                        Text("Save club")
                        Spacer(minLength: 12)
                        Image(systemName: "checkmark")
                    }
                }
                .buttonStyle(BookStampButtonStyle())
                .disabled(!canSave)
            }
            .padding(20)
            .bookSheetChrome()
            .navigationTitle("Edit club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { if !club.isPutter { isDistanceFocused = true } }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Book.paper)
    }
}

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

/// The bag as a caddie's club chart: one ruled line per club, longest first,
/// each carry drawn to a common scale so the gaps between clubs are visible.
struct CarryLadder: View {
    let clubs: [Club]
    let distanceUnit: DistanceUnit

    private var ordered: [Club] {
        clubs.filter { !$0.isPutter && $0.typicalDistanceMeters > 0 }.sorted { $0.typicalDistanceMeters > $1.typicalDistanceMeters }
    }

    var body: some View {
        let longest = Double(ordered.first?.typicalDistanceMeters ?? 1)
        VStack(alignment: .leading, spacing: 7) {
            ForEach(ordered.prefix(14)) { club in
                HStack(spacing: 10) {
                    Text(club.name)
                        .font(.system(.subheadline, weight: .bold).width(.condensed))
                        .lineLimit(1)
                        .frame(width: 58, alignment: .leading)
                    GeometryReader { g in
                        let w = max(g.size.width * CGFloat(Double(club.typicalDistanceMeters) / longest), 6)
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Book.rule).frame(height: 1)
                            Capsule().fill(Book.fairway).frame(width: w, height: 10)
                                .overlay(alignment: .trailing) {
                                    Circle().fill(Book.ink).frame(width: 6, height: 6).padding(.trailing, 2)
                                }
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(height: 14)
                    Text("\(distanceUnit.scalarValue(fromMeters: club.typicalDistanceMeters))")
                        .font(.system(.subheadline, weight: .semibold).width(.condensed))
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(club.name), \(distanceUnit.shortLabel(forMeters: club.typicalDistanceMeters)) carry")
            }
            if ordered.count > 14 {
                BookNote("+\(ordered.count - 14) more")
            }
            HStack {
                Spacer()
                BookNote("Carry, \(distanceUnit == .meters ? "metres" : "yards")")
            }
        }
    }
}

// MARK: - Public profile editor

private struct PublicProfileEditorSheet: View {
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
