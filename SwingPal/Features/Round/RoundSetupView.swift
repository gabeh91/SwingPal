import SwiftUI

private struct RoundSetupPalette {
    let bgApp: Color
    let surfacePrimary: Color
    let surfaceSecondary: Color
    let surfaceHUD: Color
    let surfaceTinted: Color
    let surfaceOverlay: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textInverse: Color
    let pine700: Color
    let pine500: Color
    let pine300: Color
    let strokeDefault: Color
    let shadowSoft: Color
    let shadowFloating: Color

    static func forColorScheme(_ colorScheme: ColorScheme) -> RoundSetupPalette {
        switch colorScheme {
        case .dark:
            return .init(
                bgApp: Color(red: 0.06, green: 0.08, blue: 0.07),
                surfacePrimary: Color(red: 0.12, green: 0.15, blue: 0.13),
                surfaceSecondary: Color(red: 0.16, green: 0.19, blue: 0.17),
                surfaceHUD: Color.white.opacity(0.08),
                surfaceTinted: Color(red: 0.14, green: 0.22, blue: 0.18),
                surfaceOverlay: Color.white.opacity(0.10),
                textPrimary: Color(red: 0.95, green: 0.97, blue: 0.96),
                textSecondary: Color(red: 0.77, green: 0.82, blue: 0.79),
                textTertiary: Color(red: 0.58, green: 0.64, blue: 0.61),
                textInverse: Color(red: 0.06, green: 0.08, blue: 0.07),
                pine700: Color(red: 0.50, green: 0.76, blue: 0.60),
                pine500: Color(red: 0.38, green: 0.66, blue: 0.50),
                pine300: Color(red: 0.27, green: 0.39, blue: 0.32),
                strokeDefault: Color.white.opacity(0.14),
                shadowSoft: Color.black.opacity(0.36),
                shadowFloating: Color.black.opacity(0.46)
            )
        default:
            return .init(
                bgApp: ShellTokens.ColorRole.bgApp,
                surfacePrimary: ShellTokens.ColorRole.surfacePrimary,
                surfaceSecondary: ShellTokens.ColorRole.surfaceSecondary,
                surfaceHUD: ShellTokens.ColorRole.surfaceHUD,
                surfaceTinted: ShellTokens.ColorRole.surfaceTinted,
                surfaceOverlay: ShellTokens.ColorRole.surfaceOverlay,
                textPrimary: ShellTokens.ColorRole.textPrimary,
                textSecondary: ShellTokens.ColorRole.textSecondary,
                textTertiary: ShellTokens.ColorRole.textTertiary,
                textInverse: ShellTokens.ColorRole.textInverse,
                pine700: ShellTokens.ColorRole.pine700,
                pine500: ShellTokens.ColorRole.pine500,
                pine300: ShellTokens.ColorRole.pine300,
                strokeDefault: ShellTokens.ColorRole.strokeDefault,
                shadowSoft: ShellTokens.Shadow.soft,
                shadowFloating: ShellTokens.Shadow.floating
            )
        }
    }
}

private struct RoundSetupHeroModel {
    let eyebrow: String
    let title: String
    let subtitle: String
    let stageSummary: String
    let highlights: [String]

    @MainActor
    init(state: RoundSetupState, distanceUnit: DistanceUnit) {
        eyebrow = "Round Setup"

        if let course = state.selectedCourse {
            title = course.name
            subtitle = "Lock the tee, confirm the group, and start with the course context already loaded."
            stageSummary = state.roundSetupSummaryDetail
            highlights = [
                "\(distanceUnit.travelLabel(forKilometers: course.distanceKilometers)) away",
                "\(course.holeCount) holes",
                "Par \(course.par)",
            ]
        } else {
            title = "Build the round in one pass"
            subtitle = "Choose a nearby course, lock the tees, then confirm who is playing without hopping between setup screens."
            stageSummary = "Course first • Tee second • Players last"
            highlights = [
                "Nearby courses",
                "Tee-ready yardages",
                "Guest players supported",
            ]
        }
    }
}

private struct RoundSetupSwipeBehavior {
    static let revealWidth: CGFloat = 104
    static let openThreshold: CGFloat = 46

    static func contentOffset(
        dragTranslation: CGFloat,
        isRevealed: Bool,
        revealWidth: CGFloat = revealWidth
    ) -> CGFloat {
        if isRevealed {
            return min(0, max(-revealWidth, -revealWidth + dragTranslation))
        }
        return max(-revealWidth, min(0, dragTranslation))
    }

    static func actionWidth(
        forContentOffset contentOffset: CGFloat,
        revealWidth: CGFloat = revealWidth
    ) -> CGFloat {
        max(0, min(revealWidth, -contentOffset))
    }

    static func shouldRemainRevealed(
        afterDragTranslation dragTranslation: CGFloat,
        wasRevealed: Bool,
        openThreshold: CGFloat = openThreshold
    ) -> Bool {
        if wasRevealed {
            return dragTranslation < openThreshold
        }
        return dragTranslation < -openThreshold
    }
}

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

struct RoundSetupView: View {
    @ObservedObject var state: RoundSetupState
    let distanceUnit: DistanceUnit
    let requiresLocationPermissionPrimer: Bool
    let onStartRound: () -> Void
    let onExitSetup: () -> Void
    /// Phase 2+ injects the import flow here. In Phase 1 the host wires this
    /// to a placeholder that just records that the user wants to import.
    let onDiscoveredCourseSelected: (DiscoveredCourse) -> Void

    init(
        state: RoundSetupState,
        distanceUnit: DistanceUnit = .meters,
        requiresLocationPermissionPrimer: Bool = false,
        onStartRound: @escaping () -> Void,
        onExitSetup: @escaping () -> Void,
        onDiscoveredCourseSelected: @escaping (DiscoveredCourse) -> Void = { _ in }
    ) {
        self.state = state
        self.distanceUnit = distanceUnit
        self.requiresLocationPermissionPrimer = requiresLocationPermissionPrimer
        self.onStartRound = onStartRound
        self.onExitSetup = onExitSetup
        self.onDiscoveredCourseSelected = onDiscoveredCourseSelected
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isShowingGuestSheet = false
    @State private var isShowingExitConfirmation = false
    @State private var isShowingCourseDiscovery = false
    @State private var isHeroHighlightListExpanded = false
    @State private var locationPrimerTrigger: RoundSetupLocationPrimerTrigger?
    @State private var didHandleInitialNearbyLoad = false
    @State private var revealedPlayerID: UUID?

    private static let nearbyPreviewCount = 5

    private let teeSectionID = "tee-section"
    private let playerSectionID = "player-section"

    private var heroModel: RoundSetupHeroModel {
        RoundSetupHeroModel(state: state, distanceUnit: distanceUnit)
    }

    private var palette: RoundSetupPalette {
        .forColorScheme(colorScheme)
    }

    private var usesCompactHeroLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var compactHeroHighlightPresentation: ShellTokens.PillLayout.CompactPresentation {
        ShellTokens.PillLayout.compactPresentation(from: heroModel.highlights, isExpanded: isHeroHighlightListExpanded)
    }

    private var hasSetupProgress: Bool {
        state.selectedCourse != nil || state.selectedTee != nil || state.players.count > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x24) {
                        heroCard
                        courseSection
                        teeSection
                            .id(teeSectionID)
                        playersSection
                            .id(playerSectionID)
                    }
                    .padding(.horizontal, ShellTokens.Spacing.x20)
                    .padding(.top, ShellTokens.Spacing.x20)
                    .padding(.bottom, ShellTokens.Spacing.x24)
                }
                .onChange(of: state.selectedCourse?.id, initial: false) { _, newValue in
                    guard newValue != nil else { return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        proxy.scrollTo(teeSectionID, anchor: .top)
                    }
                }
                .onChange(of: state.selectedTeeName, initial: false) { _, newValue in
                    guard newValue != nil else { return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        proxy.scrollTo(playerSectionID, anchor: .top)
                    }
                }
            }

            footerBar
        }
        .background(
            Group {
                if colorScheme == .dark {
                    palette.bgApp
                } else {
                    LinearGradient(
                        colors: [
                            palette.bgApp,
                            palette.surfaceTinted.opacity(0.42)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .ignoresSafeArea()
        )
        .sheet(isPresented: $isShowingGuestSheet) {
            AddGuestPlayerSheet(
                onAdd: { state.addGuest(named: $0) },
                onDismiss: { isShowingGuestSheet = false }
            )
        }
        .sheet(isPresented: $isShowingCourseDiscovery) {
            courseDiscoverySheet
        }
        .sheet(item: $locationPrimerTrigger) { trigger in
            locationPermissionPrimerSheet
        }
        .confirmationDialog(
            "Leave round setup?",
            isPresented: $isShowingExitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave Setup", role: .destructive) {
                onExitSetup()
            }

            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your course, tee, and player selections will be cleared.")
        }
        .navigationTitle("Round Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if hasSetupProgress {
                        isShowingExitConfirmation = true
                    } else {
                        onExitSetup()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                }
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: state.selectedCourse?.id)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: state.selectedTeeName)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: state.players.count)
        .task {
            guard !didHandleInitialNearbyLoad else { return }
            didHandleInitialNearbyLoad = true

            if requiresLocationPermissionPrimer {
                locationPrimerTrigger = .nearbyDiscovery
            } else {
                await state.loadNearbyCoursesIfNeeded()
            }
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(palette.surfaceOverlay)
                .frame(width: 190, height: 190)
                .offset(x: 58, y: -64)

            Circle()
                .fill(palette.pine300.opacity(colorScheme == .dark ? 0.28 : 0.18))
                .frame(width: 112, height: 112)
                .offset(x: -18, y: 88)

            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                    Text(heroModel.eyebrow.uppercased())
                        .font(ShellTokens.Typography.eyebrow)
                        .tracking(1.2)
                        .foregroundStyle(palette.pine700)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(palette.surfaceOverlay, in: Capsule())

                    if usesCompactHeroLayout {
                        VStack(alignment: .leading, spacing: 8) {
                            setupStageChip("Course", isComplete: state.selectedCourse != nil, isActive: state.selectedCourse == nil)
                            setupStageChip("Tee", isComplete: state.selectedTee != nil, isActive: state.selectedCourse != nil && state.selectedTee == nil)
                            setupStageChip("Players", isComplete: state.canStartRound, isActive: state.selectedTee != nil)
                        }
                    } else {
                        HStack(spacing: 8) {
                            setupStageChip("Course", isComplete: state.selectedCourse != nil, isActive: state.selectedCourse == nil)
                            setupStageChip("Tee", isComplete: state.selectedTee != nil, isActive: state.selectedCourse != nil && state.selectedTee == nil)
                            setupStageChip("Players", isComplete: state.canStartRound, isActive: state.selectedTee != nil)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                    Text(heroModel.title)
                        .font(usesCompactHeroLayout ? .system(size: 30, weight: .semibold, design: .serif) : .system(size: 34, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(heroModel.subtitle)
                        .font(ShellTokens.Typography.lead)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if usesCompactHeroLayout {
                    ShellCompactPillFlow(spacing: ShellTokens.Spacing.x8) {
                        ForEach(compactHeroHighlightPresentation.visibleTexts, id: \.self) { text in
                            highlightPill(text)
                        }
                        if compactHeroHighlightPresentation.showsCollapseControl {
                            highlightOverflowPill("Less") {
                                isHeroHighlightListExpanded = false
                            }
                        } else if compactHeroHighlightPresentation.overflowCount > 0 {
                            highlightOverflowPill("+\(compactHeroHighlightPresentation.overflowCount)") {
                                isHeroHighlightListExpanded = true
                            }
                        }
                    }
                } else {
                    HStack(spacing: ShellTokens.Spacing.x8) {
                        ForEach(heroModel.highlights, id: \.self) { highlight in
                            highlightPill(highlight)
                        }
                    }
                }

                Text(heroModel.stageSummary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.textPrimary)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
            .padding(usesCompactHeroLayout ? ShellTokens.Spacing.x16 : ShellTokens.Spacing.x20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    palette.surfacePrimary,
                    palette.surfaceSecondary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: ShellTokens.Radius.lg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.lg)
                .stroke(palette.strokeDefault, lineWidth: 1)
        )
        .shadow(color: palette.shadowSoft, radius: 14, y: 10)
    }

    private var courseSection: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
            sectionHeader(
                eyebrow: "Course",
                title: state.selectedCourse == nil ? "Choose the course" : "Course locked in",
                detail: state.selectedCourse == nil
                ? "Pick the course first. The tee and player setup will unlock right below."
                : "You can still switch courses here before you start the round."
            )

            ForEach(Array(state.sortedCourses.enumerated()), id: \.element.id) { index, course in
                courseCard(course, rank: index + 1)
            }

            nearbyDiscoveryPreviewSection

            if let message = state.discoveryStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .padding(.top, 4)
                    .transition(.opacity)
            }
        }
    }

    private var discoverySearchField: some View {
        HStack(spacing: ShellTokens.Spacing.x10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.textSecondary)

            TextField(
                state.searchFieldPlaceholder,
                text: Binding(
                    get: { state.searchQuery },
                    set: { state.updateSearchQuery($0) }
                )
            )
            .font(.subheadline)
            .foregroundStyle(palette.textPrimary)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled(true)
            .submitLabel(.search)

            if state.isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if !state.searchQuery.isEmpty {
                Button {
                    state.updateSearchQuery("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(palette.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ShellTokens.Spacing.x14)
        .padding(.vertical, ShellTokens.Spacing.x12)
        .background(palette.surfacePrimary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                .stroke(palette.strokeDefault, lineWidth: 1)
        )
    }

    private var nearbyDiscoveryPreviewSection: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            if state.isLoadingNearby && state.nearbyDiscoveries.isEmpty {
                discoveryLoadingPlaceholder(
                    title: "Looking for nearby courses…",
                    detail: "Searching within \(distanceUnit.travelLabel(forKilometers: 10)) of your current location."
                )
            } else if !state.nearbyDiscoveries.isEmpty {
                discoverySubheader(
                    title: "Discover nearby",
                    detail: "A quick preview — open the full list to search by name or see every match."
                )
                ForEach(Array(state.nearbyDiscoveries.prefix(Self.nearbyPreviewCount))) { discovered in
                    discoveredCourseCard(discovered, onSelect: onDiscoveredCourseSelected)
                }
                if state.nearbyDiscoveries.count > Self.nearbyPreviewCount {
                    Text("Showing \(Self.nearbyPreviewCount) of \(state.nearbyDiscoveries.count) nearby")
                        .font(.caption)
                        .foregroundStyle(palette.textTertiary)
                }
            } else {
                Text("No courses within \(distanceUnit.travelLabel(forKilometers: 10)) yet. Open browse & search to look up by name.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            browseAllCoursesButton
        }
    }

    private var browseAllCoursesButton: some View {
        Button {
            isShowingCourseDiscovery = true
        } label: {
            HStack(alignment: .center, spacing: ShellTokens.Spacing.x12) {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x4) {
                    Text("Browse & search courses")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text("Full nearby list, country search, and quick course downloads")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textTertiary)
            }
            .padding(ShellTokens.Spacing.x16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surfacePrimary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                    .stroke(palette.strokeDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the full course discovery screen")
    }

    private var discoveryFullNearbySection: some View {
        Group {
            if state.isLoadingNearby && state.nearbyDiscoveries.isEmpty {
                discoveryLoadingPlaceholder(
                    title: "Looking for nearby courses…",
                    detail: "Searching within \(distanceUnit.travelLabel(forKilometers: 10)) of your current location."
                )
            } else if !state.nearbyDiscoveries.isEmpty {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                    discoverySubheader(
                        title: "Discover nearby",
                        detail: "Tap one and we’ll download the course layout."
                    )
                    ForEach(state.nearbyDiscoveries) { discovered in
                        discoveredCourseCard(discovered) { course in
                            onDiscoveredCourseSelected(course)
                            isShowingCourseDiscovery = false
                        }
                    }
                }
            } else if !state.isLoadingNearby {
                Text("No golf courses found within \(distanceUnit.travelLabel(forKilometers: 10)). Try search above.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var discoverySearchResultsSection: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            if state.isSearching && state.searchResults.isEmpty {
                discoveryLoadingPlaceholder(
                    title: "Searching courses…",
                    detail: state.userCountryCode.map { "Looking in \($0)." } ?? "One moment."
                )
            } else if !state.searchResults.isEmpty {
                discoverySubheader(
                    title: "Search results",
                    detail: state.userCountryCode.map { "Showing matches in \($0)." }
                        ?? "Showing matches in your country."
                )
                ForEach(state.searchResults) { discovered in
                    discoveredCourseCard(discovered) { course in
                        onDiscoveredCourseSelected(course)
                        isShowingCourseDiscovery = false
                    }
                }
            }
        }
    }

    private var courseDiscoverySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                    discoverySearchField

                    if !state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        discoverySearchResultsSection
                    } else {
                        discoveryFullNearbySection
                    }

                    if let message = state.discoveryStatusMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, ShellTokens.Spacing.x20)
                .padding(.vertical, ShellTokens.Spacing.x16)
            }
            .background(
                Group {
                    if colorScheme == .dark {
                        palette.bgApp
                    } else {
                        LinearGradient(
                            colors: [
                                palette.bgApp,
                                palette.surfaceTinted.opacity(0.42)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .ignoresSafeArea()
            )
            .navigationTitle("Find a course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        state.updateSearchQuery("")
                        isShowingCourseDiscovery = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func discoverySubheader(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x4) {
            Text(title.uppercased())
                .font(ShellTokens.Typography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(palette.textTertiary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func discoveryLoadingPlaceholder(title: String, detail: String) -> some View {
        HStack(spacing: ShellTokens.Spacing.x12) {
            ProgressView()
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
        }
        .padding(ShellTokens.Spacing.x14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfacePrimary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                .stroke(palette.strokeDefault, lineWidth: 1)
        )
    }

    private func discoveredCourseCard(
        _ course: DiscoveredCourse,
        onSelect: @escaping (DiscoveredCourse) -> Void
    ) -> some View {
        Button {
            onSelect(course)
        } label: {
            HStack(alignment: .top, spacing: ShellTokens.Spacing.x14) {
                ZStack {
                    RoundedRectangle(cornerRadius: ShellTokens.Radius.md, style: .continuous)
                        .fill(palette.surfaceTinted)
                    Image(systemName: "globe.europe.africa")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.pine700)
                }
                .frame(width: 60, height: 64)

                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x6) {
                    Text(course.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(2)

                    Text(discoveredCourseSubtitle(for: course))
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(2)

                    HStack(spacing: ShellTokens.Spacing.x8) {
                        courseMetaPill("Tap to import", accent: true)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.down.circle")
                    .font(.title3)
                    .foregroundStyle(palette.pine700)
            }
            .padding(ShellTokens.Spacing.x16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surfacePrimary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                    .stroke(palette.strokeDefault.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func discoveredCourseSubtitle(for course: DiscoveredCourse) -> String {
        var parts: [String] = []
        if let distance = course.distanceKilometers {
            parts.append("\(distanceUnit.travelLabel(forKilometers: distance)) away")
        }
        if let region = course.region, !region.isEmpty {
            parts.append(region)
        }
        if let countryCode = course.countryCode, !countryCode.isEmpty {
            parts.append(countryCode)
        }
        if parts.isEmpty {
            parts.append("Course match")
        }
        return parts.joined(separator: " • ")
    }

    private var teeSection: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
            sectionHeader(
                eyebrow: "Tee",
                title: state.selectedCourse == nil ? "Choose a course first" : "Lock the tee context",
                detail: state.selectedCourse == nil
                ? "Tee options appear as soon as you select a course."
                : "Select the tee that matches today’s round so yardages and round context stay aligned."
            )

            if state.availableTees.isEmpty {
                lockedPlaceholderCard(
                    title: "Tee selection is waiting on the course",
                    detail: "Pick a nearby course above to reveal its tee set."
                )
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: ShellTokens.Spacing.x12),
                        GridItem(.flexible(), spacing: ShellTokens.Spacing.x12),
                    ],
                    spacing: ShellTokens.Spacing.x12
                ) {
                    ForEach(state.availableTees, id: \.id) { tee in
                        teeCard(tee)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
            sectionHeader(
                eyebrow: "Players",
                title: state.selectedTee == nil ? "Confirm the tee first" : "Confirm the group",
                detail: state.selectedTee == nil
                ? "Once the tee is selected, you can confirm who is in the round."
                : "You’re seeded into the round already. Add guests if the group isn’t locked yet."
            )

            if state.selectedTee == nil {
                lockedPlaceholderCard(
                    title: "Players unlock after tee selection",
                    detail: "That keeps the round setup in one clean order: course, tee, then group."
                )
            } else {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                    VStack(spacing: ShellTokens.Spacing.x12) {
                        ForEach(state.players) { player in
                            if player.kind == .guest {
                                RoundSetupSwipeRevealRow(
                                    id: player.id,
                                    revealedID: $revealedPlayerID,
                                    onDelete: {
                                        state.removeGuest(id: player.id)
                                    }
                                ) {
                                    playerRow(player)
                                }
                            } else {
                                playerRow(player)
                            }
                        }
                    }

                    Button {
                        isShowingGuestSheet = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Guest Player")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, ShellTokens.Spacing.x16)
                        .padding(.vertical, ShellTokens.Spacing.x14)
                        .foregroundStyle(palette.pine700)
                        .background(palette.surfaceTinted, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md))
                    }
                    .buttonStyle(.plain)
                }
                .padding(ShellTokens.Spacing.x16)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                        .stroke(palette.strokeDefault.opacity(colorScheme == .dark ? 0.9 : 0.34), lineWidth: 1)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var footerBar: some View {
        VStack(spacing: ShellTokens.Spacing.x12) {
            ViewThatFits(in: .vertical) {
                HStack(spacing: ShellTokens.Spacing.x8) {
                    footerChip(state.selectedCourse?.name ?? "Course pending")
                    footerChip(state.selectedTeeName ?? "Tee pending")
                    footerChip("\(state.players.count) golfer\(state.players.count == 1 ? "" : "s")")
                }

                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                    footerChip(state.selectedCourse?.name ?? "Course pending")
                    HStack(spacing: ShellTokens.Spacing.x8) {
                        footerChip(state.selectedTeeName ?? "Tee pending")
                        footerChip("\(state.players.count) golfer\(state.players.count == 1 ? "" : "s")")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: handleStartRoundTapped) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start Round")
                            .font(.headline.weight(.semibold))
                        Text(state.canStartRound ? state.roundSetupSummaryDetail : "Choose a course and tee to unlock the round.")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(
                                state.canStartRound
                                ? palette.textInverse.opacity(0.84)
                                : palette.textSecondary
                            )
                            .lineLimit(2)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .padding(.horizontal, ShellTokens.Spacing.x18)
                .padding(.vertical, ShellTokens.Spacing.x16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(state.canStartRound ? palette.textInverse : palette.textPrimary)
            .background(
                LinearGradient(
                    colors: state.canStartRound
                    ? [palette.pine700, palette.pine500]
                    : [palette.surfacePrimary, palette.surfaceSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                    .stroke(
                        state.canStartRound ? Color.clear : palette.strokeDefault.opacity(colorScheme == .dark ? 0.9 : 0.55),
                        lineWidth: 1
                    )
            )
            .shadow(color: state.canStartRound ? palette.shadowFloating : .clear, radius: 12, y: 6)
            .disabled(!state.canStartRound)
            .opacity(1.0)
        }
        .padding(.horizontal, ShellTokens.Spacing.x20)
        .padding(.top, ShellTokens.Spacing.x10)
        .padding(.bottom, 32)
        .background(
            Rectangle()
                .fill(colorScheme == .dark ? palette.bgApp : palette.bgApp.opacity(0.88))
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [
                            palette.strokeDefault.opacity(colorScheme == .dark ? 0.90 : 0.55),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 18)
                }
                .shadow(
                    color: palette.shadowFloating.opacity(colorScheme == .dark ? 0.42 : 0.14),
                    radius: 18,
                    y: -6
                )
        )
    }

    private func courseCard(_ course: SwingPalCourse, rank: Int) -> some View {
        let isSelected = state.selectedCourse?.id == course.id

        return Button {
            state.selectCourse(course)
        } label: {
            HStack(alignment: .top, spacing: ShellTokens.Spacing.x14) {
                ZStack {
                    RoundedRectangle(cornerRadius: ShellTokens.Radius.md, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    palette.pine700,
                                    palette.pine500
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(String(format: "%02d", rank))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(palette.textInverse)
                }
                .frame(width: 60, height: 72)

                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x6) {
                    HStack(spacing: 8) {
                        Text(course.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(palette.textPrimary)

                        if isSelected {
                            Text("Selected")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(palette.pine700)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(palette.surfaceTinted, in: Capsule())
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Text("\(distanceUnit.travelLabel(forKilometers: course.distanceKilometers)) away • \(course.holeCount) holes • Par \(course.par)")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)

                    HStack(spacing: ShellTokens.Spacing.x8) {
                        courseMetaPill(course.quality.readinessLabel, accent: isSelected)
                        courseMetaPill("\(course.tees.count) tee sets", accent: false)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? palette.pine700 : palette.textTertiary)
            }
            .padding(ShellTokens.Spacing.x16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                let shape = RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                if isSelected {
                    shape.fill(.ultraThinMaterial)
                } else {
                    shape.fill(palette.surfacePrimary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                    .stroke(
                        isSelected ? palette.pine500 : palette.strokeDefault,
                        lineWidth: 1
                    )
            )
            .shadow(color: isSelected ? palette.shadowSoft.opacity(0.85) : .clear, radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        .contentTransition(.opacity)
    }

    private func teeCard(_ tee: SwingPalCourse.Tee) -> some View {
        let isSelected = state.selectedTee?.id == tee.id

        return Button {
            state.selectTee(tee)
        } label: {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
                HStack {
                    Text(tee.name)
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? palette.pine700 : palette.textTertiary)
                }

                Text("\(tee.yards) yds")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)

                Text("Carries into the live round as the default course context.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(ShellTokens.Spacing.x16)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background {
                let shape = RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                if isSelected {
                    shape.fill(.ultraThinMaterial)
                } else {
                    shape.fill(palette.surfacePrimary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                    .stroke(
                        isSelected ? palette.pine500 : palette.strokeDefault,
                        lineWidth: 1
                    )
            )
            .shadow(color: isSelected ? palette.shadowSoft.opacity(0.8) : .clear, radius: 10, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func playerRow(_ player: RoundPlayerDraft) -> some View {
        HStack(spacing: ShellTokens.Spacing.x12) {
            ZStack {
                Circle()
                    .fill(player.kind == .selfPlayer ? palette.pine700 : palette.surfaceTinted)
                Text(String(player.name.prefix(1)).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(player.kind == .selfPlayer ? palette.textInverse : palette.pine700)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)

                Text(player.kind == .selfPlayer ? "Primary player" : "Guest player")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()

            Text(player.kind == .selfPlayer ? "You" : "Guest")
                .font(.caption.weight(.semibold))
                .foregroundStyle(player.kind == .selfPlayer ? palette.pine700 : palette.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    player.kind == .selfPlayer ? palette.surfaceTinted : palette.surfaceHUD,
                    in: Capsule()
                )
        }
        .padding(ShellTokens.Spacing.x14)
        .background(palette.surfacePrimary.opacity(colorScheme == .dark ? 0.92 : 0.76), in: RoundedRectangle(cornerRadius: ShellTokens.Radius.sm))
    }

    private func sectionHeader(eyebrow: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x6) {
            Text(eyebrow.uppercased())
                .font(ShellTokens.Typography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(palette.textTertiary)

            Text(title)
                .font(ShellTokens.Typography.sectionTitle)
                .foregroundStyle(palette.textPrimary)

            Text(detail)
                .font(ShellTokens.Typography.lead)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func lockedPlaceholderCard(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: ShellTokens.Spacing.x12) {
            Image(systemName: "lock.circle.fill")
                .font(.title2)
                .foregroundStyle(palette.textTertiary)

            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .padding(ShellTokens.Spacing.x16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfacePrimary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                .stroke(palette.strokeDefault, lineWidth: 1)
        )
    }

    private func setupStageChip(_ title: String, isComplete: Bool, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : (isActive ? "circle.lefthalf.filled" : "circle"))
                .font(.caption.weight(.bold))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(isComplete || isActive ? palette.pine700 : palette.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            (isComplete || isActive) ? palette.surfaceTinted : palette.surfaceOverlay,
            in: Capsule()
        )
    }

    private func highlightPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(palette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(palette.surfaceOverlay, in: Capsule())
    }

    private func highlightOverflowPill(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            highlightPill(text)
        }
        .buttonStyle(.plain)
    }

    private func courseMetaPill(_ text: String, accent: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(accent ? palette.pine700 : palette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                accent ? palette.surfaceTinted : palette.surfaceHUD,
                in: Capsule()
            )
    }

    private func footerChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(palette.surfacePrimary.opacity(colorScheme == .dark ? 0.96 : 0.84), in: Capsule())
            .foregroundStyle(palette.textPrimary)
    }

    private func handleStartRoundTapped() {
        guard state.canStartRound else { return }

        if requiresLocationPermissionPrimer {
            locationPrimerTrigger = .startRound
        } else {
            onStartRound()
        }
    }

    private var locationPermissionPrimerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x20) {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                        Text("LOCATION ACCESS")
                            .font(ShellTokens.Typography.eyebrow)
                            .tracking(1.2)
                            .foregroundStyle(palette.pine700)

                        Text("Why SwingPal needs your location")
                            .font(ShellTokens.Typography.sectionTitle)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("We use your location during a live round to calculate GPS yardages, place your ball accurately on the hole, and keep your course context in sync as you move.")
                            .font(ShellTokens.Typography.body)
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
                        locationBenefitRow(
                            title: "Live GPS yardages",
                            detail: "Front, pin, and back numbers update from where you actually are on the course."
                        )
                        locationBenefitRow(
                            title: "Smarter shot context",
                            detail: "Your position helps SwingPal understand lie, distance, and the next play more accurately."
                        )
                        locationBenefitRow(
                            title: "Round-only purpose",
                            detail: "This permission is used to power live-round GPS features, not generic background tracking."
                        )
                    }
                    .padding(ShellTokens.Spacing.x16)
                    .background(palette.surfacePrimary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ShellTokens.Radius.lg, style: .continuous)
                            .stroke(palette.strokeDefault, lineWidth: 1)
                    )

                    VStack(spacing: ShellTokens.Spacing.x12) {
                        Button {
                            let trigger = locationPrimerTrigger
                            locationPrimerTrigger = nil

                            switch trigger {
                            case .nearbyDiscovery:
                                Task {
                                    await state.loadNearbyCoursesIfNeeded()
                                }
                            case .startRound:
                                onStartRound()
                            case .none:
                                break
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Continue")
                                        .font(.headline.weight(.semibold))
                                    Text(locationPrimerTrigger == .nearbyDiscovery ? "We’ll ask iOS for location to find nearby courses" : "We’ll ask iOS for location next")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(palette.textInverse.opacity(0.84))
                                }

                                Spacer(minLength: 12)

                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title3)
                            }
                            .padding(.horizontal, ShellTokens.Spacing.x18)
                            .padding(.vertical, ShellTokens.Spacing.x16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(palette.textInverse)
                            .background(
                                LinearGradient(
                                    colors: [palette.pine700, palette.pine500],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                            )
                        }
                        .buttonStyle(.plain)

                        Button("Not now") {
                            locationPrimerTrigger = nil
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(ShellTokens.Spacing.x20)
            }
            .background(palette.bgApp.ignoresSafeArea())
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(palette.bgApp)
    }

    private func locationBenefitRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ShellTokens.Typography.microEyebrow)
                .tracking(0.8)
                .foregroundStyle(palette.textPrimary)

            Text(detail)
                .font(ShellTokens.Typography.body)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RoundSetupSwipeRevealRow<Content: View>: View {
    private enum CommittedDragAxis {
        case horizontal
        case vertical
    }

    let id: UUID
    @Binding var revealedID: UUID?
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var dragOffset: CGFloat = 0
    @State private var committedDragAxis: CommittedDragAxis?

    private var isOpen: Bool {
        revealedID == id
    }

    private var contentOffset: CGFloat {
        RoundSetupSwipeBehavior.contentOffset(
            dragTranslation: dragOffset,
            isRevealed: isOpen
        )
    }

    private var actionWidth: CGFloat {
        RoundSetupSwipeBehavior.actionWidth(forContentOffset: contentOffset)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if actionWidth > 0.5 {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        revealedID = nil
                        dragOffset = 0
                    }
                    onDelete()
                } label: {
                    ZStack {
                        Color(red: 0.86, green: 0.22, blue: 0.22)
                        VStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Delete")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                    }
                    .frame(width: RoundSetupSwipeBehavior.revealWidth)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: actionWidth, alignment: .trailing)
                .clipped()
                .zIndex(0)
            }

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .offset(x: contentOffset)
                .zIndex(1)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let w = value.translation.width
                            let h = value.translation.height
                            if committedDragAxis == nil {
                                let dist = max(abs(w), abs(h))
                                if dist >= 16 {
                                    committedDragAxis = abs(w) > abs(h) ? .horizontal : .vertical
                                }
                            }
                            guard committedDragAxis == .horizontal else { return }
                            if w < 0 {
                                dragOffset = w
                            } else if isOpen {
                                dragOffset = w
                            }
                        }
                        .onEnded { value in
                            let wasVertical = committedDragAxis == .vertical
                            committedDragAxis = nil
                            if wasVertical {
                                dragOffset = 0
                                return
                            }
                            let shouldOpen = RoundSetupSwipeBehavior.shouldRemainRevealed(
                                afterDragTranslation: value.translation.width,
                                wasRevealed: isOpen
                            )
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                revealedID = shouldOpen ? id : nil
                                dragOffset = 0
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture().onEnded {
                        if isOpen {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                revealedID = nil
                                dragOffset = 0
                            }
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: ShellTokens.Radius.sm, style: .continuous))
                .onChange(of: revealedID) { _, newValue in
                    if newValue != id {
                        dragOffset = 0
                    }
                }
        }
    }
}
