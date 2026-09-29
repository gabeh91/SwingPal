import SwiftUI

private enum RoundSetupLocationPrimerTrigger: Identifiable {
    case nearbyDiscovery
    case startRound

    var id: Int {
        switch self {
        case .nearbyDiscovery: return 0
        case .startRound: return 1
        }
    }
}

/// Setting the card: course, tees and players are the header of a scorecard.
/// Each choice collapses into a filled line once made, and the book's table of
/// contents (every hole in miniature) confirms the course you picked.
struct RoundSetupView: View {
    @ObservedObject var state: RoundSetupState
    let distanceUnit: DistanceUnit
    let requiresLocationPermissionPrimer: Bool
    let onStartRound: () -> Void
    let onExitSetup: () -> Void
    let authState: AuthState
    let onAuthGateRequired: (GateRequirement) -> Void
    let myUserId: UUID?
    let onSearchPlayers: (String) async throws -> [PublicProfile]
    let onFetchPlayerProfileById: (UUID) async throws -> PublicProfile?
    let onDiscoveredCourseSelected: (DiscoveredCourse) -> Void

    init(
        state: RoundSetupState,
        distanceUnit: DistanceUnit = .meters,
        requiresLocationPermissionPrimer: Bool = false,
        onStartRound: @escaping () -> Void,
        onExitSetup: @escaping () -> Void,
        authState: AuthState = .guest,
        onAuthGateRequired: @escaping (GateRequirement) -> Void = { _ in },
        myUserId: UUID? = nil,
        onSearchPlayers: @escaping (String) async throws -> [PublicProfile] = { _ in [] },
        onFetchPlayerProfileById: @escaping (UUID) async throws -> PublicProfile? = { _ in nil },
        onDiscoveredCourseSelected: @escaping (DiscoveredCourse) -> Void = { _ in }
    ) {
        self.state = state
        self.distanceUnit = distanceUnit
        self.requiresLocationPermissionPrimer = requiresLocationPermissionPrimer
        self.onStartRound = onStartRound
        self.onExitSetup = onExitSetup
        self.authState = authState
        self.onAuthGateRequired = onAuthGateRequired
        self.myUserId = myUserId
        self.onSearchPlayers = onSearchPlayers
        self.onFetchPlayerProfileById = onFetchPlayerProfileById
        self.onDiscoveredCourseSelected = onDiscoveredCourseSelected
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isChangingCourse = false
    @State private var isShowingGuestSheet = false
    @State private var isShowingPlayerSearch = false
    @State private var isShowingExitConfirmation = false
    @State private var isShowingCourseDiscovery = false
    @State private var locationPrimerTrigger: RoundSetupLocationPrimerTrigger?
    @State private var didHandleInitialNearbyLoad = false

    private static let nearbyPreviewCount = 5
    private let teeSectionID = "tee-section"
    private let playerSectionID = "player-section"

    private var hasSetupProgress: Bool {
        state.selectedCourse != nil || state.selectedTee != nil || state.players.count > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 34) {
                        if let course = state.selectedCourse, !isChangingCourse {
                            selectedCourseHeader(course).id("selected-course")
                            teeSection.id(teeSectionID)
                        } else {
                            courseSection
                        }
                        if state.selectedTee != nil, !isChangingCourse {
                            playersSection.id(playerSectionID)
                        }
                        if dynamicTypeSize.isAccessibilitySize { footerBar }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: state.selectedCourse?.id, initial: false) { _, newValue in
                    guard newValue != nil else { return }
                    isChangingCourse = false
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.35)) {
                        proxy.scrollTo("selected-course", anchor: .top)
                    }
                }
                .onChange(of: state.selectedTeeName, initial: false) { _, newValue in
                    guard newValue != nil else { return }
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.35)) {
                        proxy.scrollTo(playerSectionID, anchor: .top)
                    }
                }
            }

            if !dynamicTypeSize.isAccessibilitySize { footerBar }
        }
        .background(Book.paper.ignoresSafeArea())
        .foregroundStyle(Book.ink)
        .tint(Book.stamp)
        .sheet(isPresented: $isShowingGuestSheet) {
            AddGuestPlayerSheet(
                onAdd: { state.addGuest(named: $0) },
                onDismiss: { isShowingGuestSheet = false }
            )
        }
        .sheet(isPresented: $isShowingPlayerSearch) {
            AddPlayerSearchSheet(
                onSearch: onSearchPlayers,
                myUserId: myUserId,
                onFetchNearbyProfile: onFetchPlayerProfileById,
                onSelect: { profile in
                    let name = profile.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let username = profile.username?.trimmingCharacters(in: .whitespacesAndNewlines)
                    state.addGuest(named: (name?.isEmpty == false ? name! : (username?.isEmpty == false ? username! : "Player")))
                    isShowingPlayerSearch = false
                },
                onDismiss: { isShowingPlayerSearch = false }
            )
        }
        .sheet(isPresented: $isShowingCourseDiscovery) { courseDiscoverySheet }
        .sheet(item: $locationPrimerTrigger) { _ in locationPermissionPrimerSheet }
        .confirmationDialog("Leave round setup?", isPresented: $isShowingExitConfirmation, titleVisibility: .visible) {
            Button("Leave setup", role: .destructive) { onExitSetup() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your course, tee and player choices will be cleared.")
        }
        .navigationTitle("New round")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Book.paper, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if hasSetupProgress { isShowingExitConfirmation = true } else { onExitSetup() }
                } label: {
                    Label("Home", systemImage: "chevron.left")
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: state.selectedCourse?.id)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: state.selectedTeeName)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: state.players.count)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: isChangingCourse)
        .task {
            guard !didHandleInitialNearbyLoad else { return }
            didHandleInitialNearbyLoad = true
            await state.refreshStoredCourses()
        }
    }

    // MARK: Selected course

    private func selectedCourseHeader(_ course: SwingPalCourse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                BookNote("Course")
                Spacer()
                Button("Change") { isChangingCourse = true }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .foregroundStyle(Book.ink)
                    .accessibilityLabel("Change course")
            }
            Text(course.name)
                .font(Book.Typeface.display)
                .fixedSize(horizontal: false, vertical: true)
            Text(courseFacts(course))
                .font(.subheadline)
                .foregroundStyle(Book.pencil)
            if !dynamicTypeSize.isAccessibilitySize, course.holes.contains(where: { HoleProjection(hole: $0) != nil }) {
                CourseContentsStrip(holes: course.holes)
                    .padding(.top, 4)
            }
            if let note = course.sourceReferences.compactMap(\.note).first(where: { !$0.isEmpty }) {
                Text(note).font(.caption).foregroundStyle(Book.pencil)
            }
        }
    }

    private func courseFacts(_ course: SwingPalCourse) -> String {
        var parts = ["\(course.holeCount) holes", "Par \(course.par)", course.quality.readinessLabel]
        if let source = course.sourceReferences.first?.kind.label { parts.append(source) }
        return parts.joined(separator: " · ")
    }

    // MARK: Course choice

    private var courseSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Where are you playing?")
                    .font(Book.Typeface.display)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if isChangingCourse {
                    Button("Cancel") { isChangingCourse = false }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
            }
            discoverySearchField
            if !state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                discoverySearchResultsSection
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    BookSectionRule(title: "In your book", trailing: state.sortedCourses.isEmpty ? nil : "\(state.sortedCourses.count)")
                        .padding(.bottom, 4)
                    if state.sortedCourses.isEmpty {
                        Text("Search by name to find and download your course.")
                            .font(.subheadline)
                            .foregroundStyle(Book.pencil)
                            .padding(.vertical, 12)
                    }
                    ForEach(state.sortedCourses) { course in
                        courseRow(course)
                        BookHairline()
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    BookSectionRule(title: "Elsewhere")
                        .padding(.bottom, 4)
                    Button {
                        if requiresLocationPermissionPrimer { locationPrimerTrigger = .nearbyDiscovery }
                        else { Task { await state.loadNearbyCoursesIfNeeded() } }
                    } label: {
                        actionRowLabel(title: "Courses near me", detail: "Uses your location once, when you tap", symbol: "location")
                    }
                    .buttonStyle(BookRowButtonStyle())
                    BookHairline()
                    if state.isLoadingNearby || !state.nearbyDiscoveries.isEmpty {
                        nearbyDiscoveryPreviewSection
                    }
                    Button { isShowingCourseDiscovery = true } label: {
                        actionRowLabel(title: "Browse and search", detail: "Every match by name, with quick downloads", symbol: "books.vertical")
                    }
                    .buttonStyle(BookRowButtonStyle())
                    .accessibilityHint("Opens the full course discovery screen")
                    BookHairline()
                }
            }
            if let message = state.discoveryStatusMessage {
                Label(message, systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(Book.pencil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func actionRowLabel(title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.body.weight(.medium)).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Book.pencil)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Book.pencil)
        }
        .padding(.vertical, 14)
    }

    private var discoverySearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(Book.pencil)
            TextField(
                state.searchFieldPlaceholder,
                text: Binding(get: { state.searchQuery }, set: { state.updateSearchQuery($0) })
            )
            .font(.title3)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled(true)
            .submitLabel(.search)
            if state.isSearching {
                ProgressView().controlSize(.small)
            } else if !state.searchQuery.isEmpty {
                Button { state.updateSearchQuery("") } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Book.pencil)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear course search")
            }
        }
        .frame(minHeight: 48)
        .overlay(alignment: .bottom) { Rectangle().fill(Book.ink.opacity(0.7)).frame(height: 1.25) }
    }

    private func courseRow(_ course: SwingPalCourse) -> some View {
        let isSelected = state.selectedCourse?.id == course.id
        return Button { state.selectCourse(course) } label: {
            HStack(alignment: .center, spacing: 16) {
                CourseThumbnail(course: course)
                    .frame(width: 46, height: 62)
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name).font(.headline)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(course.holeCount) holes · Par \(course.par)")
                        .font(.subheadline).foregroundStyle(Book.pencil)
                    Text(course.distanceKilometers == nil ? course.quality.readinessLabel : course.proximityLabel(distanceUnit: distanceUnit))
                        .font(.caption).foregroundStyle(Book.pencil)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                    .font(isSelected ? .title3 : .footnote.weight(.semibold))
                    .foregroundStyle(isSelected ? Book.stamp : Book.pencil)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(BookRowButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var nearbyDiscoveryPreviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.isLoadingNearby && state.nearbyDiscoveries.isEmpty {
                loadingRow("Looking for courses within \(distanceUnit.travelLabel(forKilometers: 10))…")
            } else {
                ForEach(Array(state.nearbyDiscoveries.prefix(Self.nearbyPreviewCount))) { discovered in
                    discoveredCourseRow(discovered, onSelect: onDiscoveredCourseSelected)
                    BookHairline()
                }
                if state.nearbyDiscoveries.count > Self.nearbyPreviewCount {
                    BookNote("Showing \(Self.nearbyPreviewCount) of \(state.nearbyDiscoveries.count) nearby")
                        .padding(.vertical, 10)
                }
            }
        }
    }

    private var discoveryFullNearbySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.isLoadingNearby && state.nearbyDiscoveries.isEmpty {
                loadingRow("Looking for courses within \(distanceUnit.travelLabel(forKilometers: 10))…")
            } else if !state.nearbyDiscoveries.isEmpty {
                BookSectionRule(title: "Nearby").padding(.bottom, 4)
                ForEach(state.nearbyDiscoveries) { discovered in
                    discoveredCourseRow(discovered) { course in
                        onDiscoveredCourseSelected(course)
                        isShowingCourseDiscovery = false
                    }
                    BookHairline()
                }
            } else if !state.isLoadingNearby {
                Text("Type a course name above. Nearby results appear after you ask for them.")
                    .font(.subheadline)
                    .foregroundStyle(Book.pencil)
            }
        }
    }

    private var discoverySearchResultsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.isSearching && state.searchResults.isEmpty {
                loadingRow(state.userCountryCode.map { "Searching courses in \($0)…" } ?? "Searching courses…")
            } else if !state.searchResults.isEmpty {
                BookSectionRule(title: "Matches", trailing: state.userCountryCode).padding(.bottom, 4)
                ForEach(state.searchResults) { discovered in
                    discoveredCourseRow(discovered) { course in
                        onDiscoveredCourseSelected(course)
                        isShowingCourseDiscovery = false
                    }
                    BookHairline()
                }
            }
        }
    }

    private func loadingRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small)
            Text(text).font(.subheadline).foregroundStyle(Book.pencil)
        }
        .padding(.vertical, 14)
    }

    private func discoveredCourseRow(_ course: DiscoveredCourse, onSelect: @escaping (DiscoveredCourse) -> Void) -> some View {
        Button { onSelect(course) } label: {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Book.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    Image(systemName: "arrow.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Book.pencil)
                }
                .frame(width: 46, height: 62)
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
                    Text(discoveredCourseSubtitle(for: course)).font(.subheadline).foregroundStyle(Book.pencil)
                    BookNote("Tap to add to your book", color: Book.stamp)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(BookRowButtonStyle())
    }

    private func discoveredCourseSubtitle(for course: DiscoveredCourse) -> String {
        var parts: [String] = []
        if let distance = course.distanceKilometers { parts.append("\(distanceUnit.travelLabel(forKilometers: distance)) away") }
        if let region = course.region, !region.isEmpty { parts.append(region) }
        if let countryCode = course.countryCode, !countryCode.isEmpty { parts.append(countryCode) }
        return parts.isEmpty ? "Course match" : parts.joined(separator: " · ")
    }

    private var courseDiscoverySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    discoverySearchField
                    if !state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        discoverySearchResultsSection
                    } else {
                        discoveryFullNearbySection
                    }
                    if let message = state.discoveryStatusMessage {
                        Text(message).font(.caption).foregroundStyle(Book.pencil)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .navigationTitle("Find a course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isShowingCourseDiscovery = false }
                }
            }
        }
        .tint(Book.stamp)
        .presentationDetents([.large])
    }

    // MARK: Tees

    private var teeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            BookSectionRule(title: "Tees").padding(.bottom, 4)
            if state.availableTees.isEmpty {
                Label("No tee data for this course. You can still score it.", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(Book.warning)
                    .padding(.vertical, 12)
            } else {
                ForEach(state.availableTees, id: \.id) { tee in
                    teeRow(tee)
                    BookHairline()
                }
            }
        }
    }

    private func teeRow(_ tee: SwingPalCourse.Tee) -> some View {
        let isSelected = state.selectedTeeName == tee.name
        return Button { state.selectTee(tee) } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().strokeBorder(Book.ink.opacity(isSelected ? 1 : 0.45), lineWidth: 1.25)
                    if isSelected { Circle().fill(Book.ink).padding(5) }
                }
                .frame(width: 22, height: 22)
                Text(tee.name).font(.headline.weight(isSelected ? .semibold : .regular))
                Spacer(minLength: 12)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(teeDistanceValue(for: tee)).font(Book.Typeface.smallFigure)
                    Text(distanceUnit.shortSuffix).font(.caption).foregroundStyle(Book.pencil)
                }
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(BookRowButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func teeDistanceValue(for tee: SwingPalCourse.Tee) -> String {
        switch distanceUnit {
        case .yards: return "\(tee.yards)"
        case .meters: return "\(Int((Double(tee.yards) * 0.9144).rounded()))"
        }
    }

    // MARK: Players

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            BookSectionRule(title: "Playing with", trailing: "\(state.players.count)").padding(.bottom, 4)
            ForEach(state.players) { player in
                HStack(spacing: 14) {
                    Text(String(player.name.prefix(1)).uppercased())
                        .font(.system(.subheadline, weight: .bold).width(.condensed))
                        .foregroundStyle(player.kind == .selfPlayer ? Book.onStamp : Book.ink)
                        .frame(width: 34, height: 34)
                        .background {
                            if player.kind == .selfPlayer { Circle().fill(Book.stamp) }
                            else { Circle().strokeBorder(Book.ink.opacity(0.5), lineWidth: 1) }
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name).font(.headline)
                        Text(player.kind == .selfPlayer ? "Your scorecard" : "Companion · listed, score not kept")
                            .font(.subheadline).foregroundStyle(Book.pencil)
                    }
                    Spacer(minLength: 0)
                    if player.kind == .guest {
                        Button(role: .destructive) { state.removeGuest(id: player.id) } label: {
                            Image(systemName: "xmark").font(.footnote.weight(.semibold)).frame(width: 44, height: 44)
                        }
                        .foregroundStyle(Book.pencil)
                        .accessibilityLabel("Remove \(player.name)")
                    }
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .contain)
                BookHairline()
            }
            HStack(spacing: 18) {
                Button { isShowingGuestSheet = true } label: {
                    Label("Add companion", systemImage: "plus").frame(minHeight: 44)
                }
                Button {
                    if authState == .authenticated { isShowingPlayerSearch = true } else { onAuthGateRequired(.signIn) }
                } label: {
                    Label("Find a player", systemImage: "magnifyingglass").frame(minHeight: 44)
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    // MARK: Footer

    private var footerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !state.canStartRound {
                Text(state.selectedCourse == nil ? "Choose a course to begin." : "Choose your tees to begin.")
                    .font(.subheadline)
                    .foregroundStyle(Book.pencil)
            }
            Button(action: handleStartRoundTapped) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tee off").font(.headline)
                        if let course = state.selectedCourse, let tee = state.selectedTeeName {
                            Text("\(course.name) · \(tee)").font(.subheadline).opacity(0.78).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 12)
                    Image(systemName: "arrow.right").font(.headline)
                }
            }
            .buttonStyle(BookStampButtonStyle())
            .disabled(!state.canStartRound)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Book.paper)
        .overlay(alignment: .top) { BookHairline() }
    }

    private func handleStartRoundTapped() {
        guard state.canStartRound else { return }
        if requiresLocationPermissionPrimer { locationPrimerTrigger = .startRound } else { onStartRound() }
    }

    // MARK: Location primer

    private var locationPermissionPrimerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "location.north.circle")
                        .font(.system(size: 44, weight: .light))
                    Text("Yardages from where you stand")
                        .font(Book.Typeface.display)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("SwingPal uses your location during a round to measure to the green, place your ball on the hole and keep the page turned to the hole you’re on.")
                        .font(.body)
                        .foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 0) {
                        primerRow("Front, centre and back", "Measured from your position to the green geometry.")
                        primerRow("Ball placement", "Shots you log are pinned where you hit them.")
                        primerRow("Only while playing", "Used for live-round features, not background tracking.")
                    }
                    VStack(spacing: 10) {
                        Button {
                            let trigger = locationPrimerTrigger
                            locationPrimerTrigger = nil
                            switch trigger {
                            case .nearbyDiscovery:
                                Task {
                                    await state.refreshStoredCourses()
                                    await state.loadNearbyCoursesIfNeeded()
                                }
                            case .startRound:
                                onStartRound()
                            case .none:
                                break
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Continue").font(.headline)
                                    Text("iOS will ask for permission next").font(.subheadline).opacity(0.78)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                        }
                        .buttonStyle(BookStampButtonStyle())
                        Button("Not now") { locationPrimerTrigger = nil }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Book.pencil)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(24)
            }
            .background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Book.paper)
    }

    private func primerRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(Book.pencil).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { BookHairline() }
    }
}

// MARK: - Course miniatures

/// The book's table of contents: every hole in miniature, tee to green, numbered.
struct CourseContentsStrip: View {
    let holes: [SwingPalCourse.Hole]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(holes) { hole in
                    VStack(spacing: 4) {
                        HolePageDrawing(hole: hole, showsArcs: false, showsCentreLine: false, showsScale: false,
                                        insets: EdgeInsets(top: 4, leading: 3, bottom: 3, trailing: 3))
                            .frame(width: 30, height: 64)
                        Text("\(hole.number)")
                            .font(.system(size: 11, weight: .semibold).width(.condensed))
                            .foregroundStyle(Book.pencil)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityHidden(true)
    }
}

/// A course's first hole, drawn small: its spine in the book.
struct CourseThumbnail: View {
    let course: SwingPalCourse

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Book.leaf)
            RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Book.rule)
            if let hole = course.holes.first(where: { HoleProjection(hole: $0) != nil }) {
                HolePageDrawing(hole: hole, showsArcs: false, showsCentreLine: false, showsScale: false,
                                insets: EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
            } else {
                Image(systemName: "flag").foregroundStyle(Book.pencil)
            }
        }
        .accessibilityHidden(true)
    }
}
