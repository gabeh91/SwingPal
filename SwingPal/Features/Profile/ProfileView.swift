import SwiftUI

private struct ProfilePalette {
    let backgroundBase: Color
    let backgroundTopGlow: Color
    let backgroundBottomGlow: Color
    let cardTint: Color
    let cardStrongTint: Color
    let cardMutedTint: Color
    let border: Color
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    let accent: Color
    let accentForeground: Color
    let quietFill: Color
    let premiumTint: Color
    let premiumBorder: Color
    let shadow: Color
    let glassHighlight: Color

    static func forColorScheme(_ colorScheme: ColorScheme) -> ProfilePalette {
        switch colorScheme {
        case .dark:
            return .init(
                backgroundBase: Color(red: 0.05, green: 0.08, blue: 0.07),
                backgroundTopGlow: Color(red: 0.18, green: 0.30, blue: 0.22).opacity(0.54),
                backgroundBottomGlow: Color(red: 0.10, green: 0.15, blue: 0.13).opacity(0.72),
                cardTint: Color.white.opacity(0.08),
                cardStrongTint: Color(red: 0.16, green: 0.22, blue: 0.19).opacity(0.78),
                cardMutedTint: Color(red: 0.14, green: 0.18, blue: 0.16).opacity(0.62),
                border: Color.white.opacity(0.22),
                primaryText: Color.white.opacity(0.96),
                secondaryText: Color.white.opacity(0.82),
                tertiaryText: Color.white.opacity(0.62),
                accent: ShellTokens.ColorRole.pine500,
                accentForeground: .white,
                quietFill: Color.white.opacity(0.08),
                premiumTint: Color(red: 0.27, green: 0.21, blue: 0.10).opacity(0.72),
                premiumBorder: Color(red: 0.90, green: 0.72, blue: 0.36).opacity(0.40),
                shadow: Color.black.opacity(0.34),
                glassHighlight: Color.white.opacity(0.14)
            )
        default:
            return .init(
                backgroundBase: Color(red: 0.95, green: 0.96, blue: 0.92),
                backgroundTopGlow: Color(red: 0.84, green: 0.92, blue: 0.80).opacity(0.78),
                backgroundBottomGlow: Color(red: 0.97, green: 0.95, blue: 0.89).opacity(0.66),
                cardTint: Color.white.opacity(0.56),
                cardStrongTint: Color(red: 0.90, green: 0.95, blue: 0.89).opacity(0.88),
                cardMutedTint: Color.white.opacity(0.40),
                border: Color.white.opacity(0.42),
                primaryText: ShellTokens.ColorRole.textPrimary,
                secondaryText: ShellTokens.ColorRole.textSecondary,
                tertiaryText: ShellTokens.ColorRole.textTertiary,
                accent: ShellTokens.ColorRole.pine700,
                accentForeground: .white,
                quietFill: Color.white.opacity(0.44),
                premiumTint: Color(red: 0.97, green: 0.93, blue: 0.82).opacity(0.92),
                premiumBorder: Color(red: 0.82, green: 0.69, blue: 0.38).opacity(0.54),
                shadow: Color.black.opacity(0.10),
                glassHighlight: Color.white.opacity(0.24)
            )
        }
    }
}

private struct ProfileBagManagementView: View {
    let bag: Bag
    let palette: ProfilePalette
    let distanceUnit: DistanceUnit
    let onAddClubs: ([Club]) -> Void
    let onUpdateClub: (Club) -> Void
    let onDeleteClub: (UUID) -> Void

    @State private var isAddClubPresented = false
    @State private var editingClub: Club?
    @State private var revealedClubID: UUID?

    var body: some View {
        ScrollView { bagManagementContent }
        .background(
            ZStack {
                palette.backgroundBase
                LinearGradient(
                    colors: [palette.backgroundTopGlow, palette.backgroundBase, palette.backgroundBottomGlow],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        )
        .navigationTitle("My Bag")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddClubPresented) {
            ProfileAddClubSheet(
                palette: palette,
                distanceUnit: distanceUnit,
                onAddClubs: { clubs in
                    onAddClubs(clubs)
                }
            )
        }
        .sheet(item: $editingClub) { club in
            ProfileEditClubSheet(
                club: club,
                palette: palette,
                distanceUnit: distanceUnit,
                onSave: onUpdateClub
            )
        }
    }

    private var bagManagementContent: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x20) {
            bagHeader
            bagOverviewCard
            bagClubListCard
        }
        .padding(.horizontal, ShellTokens.Spacing.x20)
        .padding(.top, ShellTokens.Spacing.x20)
        .padding(.bottom, ShellTokens.Spacing.x32 + AppChromeMetrics.bottomContentInset)
    }

    private var bagHeader: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            Text("MY BAG")
                .font(ShellTokens.Typography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(palette.accent)

            Text("Manage the clubs you actually play.")
                .font(ShellTokens.Typography.mastheadTitle)
                .foregroundStyle(palette.primaryText)

            Text("Add catalog clubs in batches, drop in custom clubs when you need to, and adjust carry numbers whenever your real yardages change.")
                .font(ShellTokens.Typography.body)
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
        }
    }

    private var bagOverviewCard: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(palette.cardStrongTint)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            }
            .frame(height: 152)
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Bag Overview")
                        .font(ShellTokens.Typography.microEyebrow)
                        .tracking(1.2)
                        .foregroundStyle(palette.tertiaryText)

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(bag.clubs.count)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                        Text("clubs ready")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)
                    }

                    Text(bag.clubs.isEmpty ? "Start by importing a family or adding one custom club." : "Tap any club below to adjust its carry distance.")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
    }

    private var bagClubListCard: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
            HStack {
                Text("Current Clubs")
                    .font(ShellTokens.Typography.cardTitle)
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Button {
                    isAddClubPresented = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Club")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.accentForeground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(palette.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if bag.clubs.isEmpty {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.cardMutedTint)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(palette.border, lineWidth: 1)
                    }
                    .overlay {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No clubs added yet")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)
                            Text("Use the add flow to search the internal catalog or create a custom club for something you can’t find.")
                                .font(.subheadline)
                                .foregroundStyle(palette.secondaryText)
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 138)
            } else {
                ForEach(bag.clubs) { club in
                    ProfileSwipeRevealRow(
                        id: club.id,
                        revealedID: $revealedClubID,
                        palette: palette,
                        onTap: {
                            editingClub = club
                        },
                        onDelete: {
                            onDeleteClub(club.id)
                        }
                    ) {
                        HStack(spacing: ShellTokens.Spacing.x14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(palette.quietFill)
                                    .frame(width: 48, height: 48)

                                Text(club.name.prefix(2).uppercased())
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(palette.accent)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(club.name)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(palette.primaryText)
                                Text(club.subtitle ?? (club.source == .custom ? "Custom club" : "Catalog club"))
                                    .font(.caption)
                                    .foregroundStyle(palette.tertiaryText)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(distanceUnit.shortLabel(forMeters: club.typicalDistanceMeters))
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(palette.primaryText)
                                Text("Edit")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(palette.accent)
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.cardTint, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(palette.border, lineWidth: 1)
                        }
                    }
                }
            }
        }
    }
}

struct ProfileBagSwipeBehavior {
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

private struct ProfileSwipeRevealRow<Content: View>: View {

    private enum CommittedDragAxis {
        case horizontal
        case vertical
    }

    let id: UUID
    @Binding var revealedID: UUID?
    let palette: ProfilePalette
    let onTap: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var dragOffset: CGFloat = 0
    /// Lets vertical scroll win until movement clearly favors the horizontal axis.
    @State private var committedDragAxis: CommittedDragAxis?

    private var isOpen: Bool {
        revealedID == id
    }

    private var contentOffset: CGFloat {
        ProfileBagSwipeBehavior.contentOffset(
            dragTranslation: dragOffset,
            isRevealed: isOpen
        )
    }

    private var actionWidth: CGFloat {
        ProfileBagSwipeBehavior.actionWidth(forContentOffset: contentOffset)
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
                    .frame(width: ProfileBagSwipeBehavior.revealWidth)
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
                            let shouldOpen = ProfileBagSwipeBehavior.shouldRemainRevealed(
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
                        } else {
                            onTap()
                        }
                    }
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onChange(of: revealedID) { _, newValue in
            if newValue != id {
                dragOffset = 0
            }
        }
    }
}

private struct ProfileAddClubDraft: Identifiable, Equatable {
    let id: UUID
    let name: String
    let brand: String?
    let family: String?
    let source: ClubSource
    var distanceMetersText: String

    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        family: String? = nil,
        source: ClubSource,
        distanceMetersText: String
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.family = family
        self.source = source
        self.distanceMetersText = distanceMetersText
    }

    var club: Club? {
        guard let meters = Int(distanceMetersText), meters > 0 else {
            return nil
        }

        return Club(
            id: id,
            name: name,
            typicalDistanceMeters: meters,
            brand: brand,
            family: family,
            source: source
        )
    }
}

enum ProfileClubBrandSearch {
    static func filteredBrands(query: String, allBrands: [String]) -> [String] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.isEmpty == false else {
            return allBrands
        }

        return allBrands.filter { brand in
            brand.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }
}

enum ProfileAddClubSummaryGuard {
    static func interactiveDismissDisabled(isSummaryStage: Bool) -> Bool {
        isSummaryStage
    }

    static func requiresCancelConfirmation(isSummaryStage: Bool) -> Bool {
        isSummaryStage
    }
}

private struct ProfileAddClubSheet: View {
    enum EntryPath: String, CaseIterable, Identifiable {
        case catalog = "Search Catalog"
        case custom = "Custom Club"

        var id: String { rawValue }
    }

    enum Stage {
        case select
        case summary
    }

    let palette: ProfilePalette
    let distanceUnit: DistanceUnit
    let onAddClubs: ([Club]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var entryPath: EntryPath = .catalog
    @State private var stage: Stage = .select
    @State private var selectedBrand: String = ClubCatalog.brands.first ?? "Titleist"
    @State private var selectedFamilyID: String?
    @State private var selectedVariantIDs: Set<String> = []
    @State private var isBrandListExpanded = false
    @State private var brandSearchQuery = ""
    @State private var customClubName = ""
    @State private var customDistanceText = "150"
    @State private var drafts: [ProfileAddClubDraft] = []
    @State private var isCancelConfirmationPresented = false

    private var selectedFamily: ClubCatalogFamily? {
        ClubCatalog.families.first(where: { $0.id == selectedFamilyID })
    }

    private var familiesForBrand: [ClubCatalogFamily] {
        ClubCatalog.families(for: selectedBrand)
    }

    private var filteredBrands: [String] {
        ProfileClubBrandSearch.filteredBrands(
            query: brandSearchQuery,
            allBrands: ClubCatalog.brands
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x20) {
                    pathPicker

                    switch stage {
                    case .select:
                        switch entryPath {
                        case .catalog:
                            catalogSelection
                        case .custom:
                            customSelection
                        }
                    case .summary:
                        summaryStep
                    }
                }
                .padding(.horizontal, ShellTokens.Spacing.x20)
                .padding(.vertical, ShellTokens.Spacing.x20)
            }
            .background(
                ZStack {
                    palette.backgroundBase
                    LinearGradient(
                        colors: [palette.backgroundTopGlow, palette.backgroundBase, palette.backgroundBottomGlow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .ignoresSafeArea()
            )
            .navigationTitle(stage == .summary ? "Added Clubs Summary" : "Add Club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if stage == .summary {
                        Button("Back") {
                            stage = .select
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        if ProfileAddClubSummaryGuard.requiresCancelConfirmation(isSummaryStage: stage == .summary) {
                            isCancelConfirmationPresented = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .onChange(of: entryPath) { _, _ in
                stage = .select
                drafts = []
            }
            .onChange(of: selectedBrand) { _, _ in
                selectedFamilyID = familiesForBrand.first?.id
                selectedVariantIDs = []
            }
            .onAppear {
                if selectedFamilyID == nil {
                    selectedFamilyID = familiesForBrand.first?.id
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(
            ProfileAddClubSummaryGuard.interactiveDismissDisabled(isSummaryStage: stage == .summary)
        )
        .confirmationDialog(
            "Discard selected clubs?",
            isPresented: $isCancelConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Discard Selected Clubs", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You’ll lose the clubs and carry distances you’ve prepared on this summary step.")
        }
    }

    private var pathPicker: some View {
        Picker("Entry Path", selection: $entryPath) {
            ForEach(EntryPath.allCases) { path in
                Text(path.rawValue).tag(path)
            }
        }
        .pickerStyle(.segmented)
    }

    private var catalogSelection: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x18) {
            sheetSection(
                title: "Brand",
                subtitle: "Start from the maker, then narrow into the current family you want."
            )

            VStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                        isBrandListExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedBrand)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)
                            Text("Tap to search all brands")
                                .font(.caption)
                                .foregroundStyle(palette.tertiaryText)
                        }

                        Spacer()

                        Image(systemName: isBrandListExpanded ? "chevron.up" : "chevron.down")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.tertiaryText)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.cardTint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(palette.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)

                if isBrandListExpanded {
                    VStack(spacing: 12) {
                        TextField("Search brands", text: $brandSearchQuery)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .font(.subheadline)
                            .foregroundStyle(palette.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(palette.quietFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(filteredBrands, id: \.self) { brand in
                                    Button {
                                        selectedBrand = brand
                                        brandSearchQuery = ""
                                        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                                            isBrandListExpanded = false
                                        }
                                    } label: {
                                        HStack {
                                            Text(brand)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(palette.primaryText)

                                            Spacer()

                                            Image(systemName: selectedBrand == brand ? "checkmark.circle.fill" : "circle")
                                                .font(.headline)
                                                .foregroundStyle(selectedBrand == brand ? palette.accent : palette.tertiaryText)
                                        }
                                        .padding(14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(selectedBrand == brand ? palette.cardStrongTint : palette.cardTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(selectedBrand == brand ? palette.accent.opacity(0.42) : palette.border, lineWidth: 1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }

                                if filteredBrands.isEmpty {
                                    Text("No brands match that search.")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(palette.tertiaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                        .frame(maxHeight: 240)
                    }
                }
            }

            sheetSection(
                title: "Family",
                subtitle: "Choose the current in-production line that matches the clubs you want to add."
            )

            VStack(spacing: 10) {
                ForEach(familiesForBrand, id: \.id) { family in
                    Button {
                        selectedFamilyID = family.id
                        selectedVariantIDs = []
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(family.name)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(palette.primaryText)
                                Text(family.category.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(palette.tertiaryText)
                            }

                            Spacer()

                            Image(systemName: selectedFamilyID == family.id ? "checkmark.circle.fill" : "circle")
                                .font(.headline)
                                .foregroundStyle(selectedFamilyID == family.id ? palette.accent : palette.tertiaryText)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selectedFamilyID == family.id ? palette.cardStrongTint : palette.cardTint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(selectedFamilyID == family.id ? palette.accent.opacity(0.42) : palette.border, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if let family = selectedFamily {
                sheetSection(
                    title: "Select Clubs",
                    subtitle: "Check every head you want to add from this family."
                )

                LazyVGrid(columns: [.init(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                    ForEach(family.variants) { variant in
                        Button {
                            if selectedVariantIDs.contains(variant.id) {
                                selectedVariantIDs.remove(variant.id)
                            } else {
                                selectedVariantIDs.insert(variant.id)
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: selectedVariantIDs.contains(variant.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.headline)
                                    .foregroundStyle(selectedVariantIDs.contains(variant.id) ? palette.accent : palette.tertiaryText)

                                Text(variant.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.primaryText)
                            }
                            .frame(maxWidth: .infinity, minHeight: 84)
                            .padding(.horizontal, 10)
                            .background(selectedVariantIDs.contains(variant.id) ? palette.cardStrongTint : palette.cardTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(selectedVariantIDs.contains(variant.id) ? palette.accent.opacity(0.42) : palette.border, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    drafts = family.variants
                        .filter { selectedVariantIDs.contains($0.id) }
                        .map {
                            ProfileAddClubDraft(
                                name: $0.displayName,
                                brand: family.brand,
                                family: family.name,
                                source: .catalog,
                                distanceMetersText: "\(ClubCatalog.defaultDistanceMeters(for: $0, category: family.category))"
                            )
                        }
                    stage = .summary
                } label: {
                    Text("Review Selected Clubs")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(palette.accentForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedVariantIDs.isEmpty ? palette.quietFill : palette.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(selectedVariantIDs.isEmpty)
            }
        }
    }

    private var customSelection: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x18) {
            sheetSection(
                title: "Custom Club",
                subtitle: "Use this when the exact club is not in the internal catalog yet."
            )

            VStack(alignment: .leading, spacing: 12) {
                fieldLabel("Club Name")
                TextField("e.g. 7I bent strong", text: $customClubName)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(palette.cardTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(palette.border, lineWidth: 1)
                    }

                fieldLabel("Typical Carry (\(distanceUnit.shortSuffix))")
                TextField("150", text: $customDistanceText)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(palette.cardTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(palette.border, lineWidth: 1)
                    }
            }

            Button {
                drafts = [
                    ProfileAddClubDraft(
                        name: customClubName.trimmingCharacters(in: .whitespacesAndNewlines),
                        source: .custom,
                        distanceMetersText: customDistanceText
                    )
                ]
                stage = .summary
            } label: {
                Text("Review Custom Club")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.accentForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canReviewCustomClub ? palette.accent : palette.quietFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canReviewCustomClub)
        }
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x18) {
            sheetSection(
                title: "Review Distances",
                subtitle: "These clubs will be added together. Adjust any carry number now, then refine again from My Bag later."
            )

            ForEach($drafts) { $draft in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.name)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)
                            Text(draft.family ?? (draft.source == .custom ? "Custom club" : "Catalog club"))
                                .font(.caption)
                                .foregroundStyle(palette.tertiaryText)
                        }

                        Spacer()
                    }

                    fieldLabel("Carry Distance (\(distanceUnit.shortSuffix))")
                    TextField("Distance", text: $draft.distanceMetersText)
                        .keyboardType(.numberPad)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(palette.cardTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(palette.border, lineWidth: 1)
                        }
                }
                .padding(18)
                .background(palette.cardTint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                }
            }

            Button {
                onAddClubs(drafts.compactMap(\.club))
                dismiss()
            } label: {
                Text("Add \(drafts.count) Club\(drafts.count == 1 ? "" : "s")")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.accentForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSaveDrafts ? palette.accent : palette.quietFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSaveDrafts)
        }
    }

    private var canReviewCustomClub: Bool {
        !customClubName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(customDistanceText) != nil
    }

    private var canSaveDrafts: Bool {
        !drafts.isEmpty && drafts.allSatisfy { $0.club != nil }
    }

    private func sheetSection(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.primaryText)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
        }
    }

    private func chipButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? palette.accentForeground : palette.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(isSelected ? palette.accent : palette.quietFill, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? Color.white.opacity(0.08) : palette.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(ShellTokens.Typography.microEyebrow)
            .tracking(1.1)
            .foregroundStyle(palette.tertiaryText)
    }
}

private struct ProfileEditClubSheet: View {
    let club: Club
    let palette: ProfilePalette
    let distanceUnit: DistanceUnit
    let onSave: (Club) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var distanceText: String

    init(club: Club, palette: ProfilePalette, distanceUnit: DistanceUnit, onSave: @escaping (Club) -> Void) {
        self.club = club
        self.palette = palette
        self.distanceUnit = distanceUnit
        self.onSave = onSave
        _distanceText = State(initialValue: "\(club.typicalDistanceMeters)")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x18) {
                Text(club.name)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(palette.primaryText)

                Text(club.subtitle ?? (club.source == .custom ? "Custom club" : "Catalog club"))
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)

                Text("Carry Distance (\(distanceUnit.shortSuffix))")
                    .font(ShellTokens.Typography.microEyebrow)
                    .tracking(1.1)
                    .foregroundStyle(palette.tertiaryText)

                TextField("Distance", text: $distanceText)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(palette.cardTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(palette.border, lineWidth: 1)
                    }

                Spacer()

                Button {
                    guard let meters = Int(distanceText), meters > 0 else { return }
                    onSave(
                        Club(
                            id: club.id,
                            name: club.name,
                            typicalDistanceMeters: meters,
                            brand: club.brand,
                            family: club.family,
                            source: club.source
                        )
                    )
                    dismiss()
                } label: {
                    Text("Save Club")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(palette.accentForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background((Int(distanceText) ?? 0) > 0 ? palette.accent : palette.quietFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled((Int(distanceText) ?? 0) <= 0)
            }
            .padding(20)
            .background(
                ZStack {
                    palette.backgroundBase
                    LinearGradient(
                        colors: [palette.backgroundTopGlow, palette.backgroundBase, palette.backgroundBottomGlow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .ignoresSafeArea()
            )
            .navigationTitle("Edit Club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

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
    let onCompleteSignIn: () -> Void
    let onSignOut: () -> Void
    let onAddClubs: ([Club]) -> Void
    let onUpdateClub: (Club) -> Void
    let onDeleteClub: (UUID) -> Void
    let onWatchCompanionTapped: () -> Void
    let handicapSnapshot: HandicapIndexSnapshot
    let handicapEstimate: Double?
    let onSetManualHandicapIndex: (Double?) -> Void
    let currentUserDisplayName: String?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isIdentityPillListExpanded = false
    @State private var isSignInPresented = false
    @State private var isBagPresented = false
    @State private var isHandicapPresented = false
    @State private var handicapText: String = ""

    private static let bagClubsPreviewLimit = 5

    private var palette: ProfilePalette {
        ProfilePalette.forColorScheme(colorScheme)
    }

    private var usesCompactProfileCardLayout: Bool {
        horizontalSizeClass == .compact
    }

    private func compactHeroPillPresentation(_ texts: [String]) -> ShellTokens.PillLayout.CompactPresentation {
        ShellTokens.PillLayout.compactPresentation(from: texts, isExpanded: isIdentityPillListExpanded)
    }

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
        onCompleteSignIn: @escaping () -> Void,
        onSignOut: @escaping () -> Void = {},
        onAddClubs: @escaping ([Club]) -> Void,
        onUpdateClub: @escaping (Club) -> Void,
        onDeleteClub: @escaping (UUID) -> Void,
        onWatchCompanionTapped: @escaping () -> Void,
        handicapSnapshot: HandicapIndexSnapshot,
        handicapEstimate: Double?,
        onSetManualHandicapIndex: @escaping (Double?) -> Void,
        currentUserDisplayName: String? = nil
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
        self.onCompleteSignIn = onCompleteSignIn
        self.onSignOut = onSignOut
        self.onAddClubs = onAddClubs
        self.onUpdateClub = onUpdateClub
        self.onDeleteClub = onDeleteClub
        self.onWatchCompanionTapped = onWatchCompanionTapped
        self.handicapSnapshot = handicapSnapshot
        self.handicapEstimate = handicapEstimate
        self.onSetManualHandicapIndex = onSetManualHandicapIndex
        self.currentUserDisplayName = currentUserDisplayName
    }

    var body: some View {
        let model = ProfileViewModel(
            authState: authState,
            entitlements: entitlements,
            bag: bag,
            gpsMode: gpsMode
        )
        let recommendation = BagClubRecommendation.make(
            bag: bag,
            playsLikeDistanceMeters: 160,
            distanceUnit: distanceUnit
        )

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x20) {
                    masthead
                    identityMembershipCard(model: model)
                    handicapSection
                    bagAndSetupSection(model: model, recommendation: recommendation)
                    premiumCard(model: model)
                    diagnosticsSection(model: model)
                    if authState == .authenticated {
                        accountSection
                    }
                }
                .padding(.horizontal, ShellTokens.Spacing.x20)
                .padding(.top, ShellTokens.Spacing.x20)
                .padding(.bottom, ShellTokens.Spacing.x32 + AppChromeMetrics.bottomContentInset)
            }
            .background(background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isBagPresented) {
                ProfileBagManagementView(
                    bag: bag,
                    palette: palette,
                    distanceUnit: distanceUnit,
                    onAddClubs: onAddClubs,
                    onUpdateClub: onUpdateClub,
                    onDeleteClub: onDeleteClub
                )
            }
            .sheet(isPresented: $isSignInPresented) {
                AuthGateView(
                    title: "Sign in to save",
                    detail: "Save rounds, sync your bag and settings, and keep your golf identity ready across devices.",
                    onAuthenticated: {
                        onCompleteSignIn()
                        isSignInPresented = false
                    },
                    onDismiss: {
                        isSignInPresented = false
                    }
                )
            }
            .sheet(isPresented: $isHandicapPresented) {
                handicapSheet
            }
        }
    }

    private var handicapSection: some View {
        cardContainer(tint: palette.cardMutedTint, padding: 22) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("HANDICAP")
                            .font(ShellTokens.Typography.microEyebrow)
                            .tracking(1.2)
                            .foregroundStyle(palette.tertiaryText)
                        Text("Handicap Index")
                            .font(ShellTokens.Typography.cardTitle)
                            .foregroundStyle(palette.primaryText)
                    }

                    Spacer()

                    Button {
                        handicapText = handicapSnapshot.manualIndex.map {
                            $0.formatted(.number.precision(.fractionLength(1)))
                        } ?? ""
                        isHandicapPresented = true
                    } label: {
                        HStack(spacing: 8) {
                            Text(handicapSnapshot.manualIndex == nil ? "Set" : "Edit")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(palette.quietFill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(handicapPrimaryValue)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                    Text(handicapSecondaryValue)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var handicapPrimaryValue: String {
        if let manual = handicapSnapshot.manualIndex {
            return "HI \(manual.formatted(.number.precision(.fractionLength(1))))"
        }
        if let estimate = handicapEstimate {
            return "Est HI \(estimate.formatted(.number.precision(.fractionLength(1))))"
        }
        return "Not set"
    }

    private var handicapSecondaryValue: String {
        if handicapSnapshot.manualIndex != nil {
            return "Your entered index is used across the app."
        }
        if handicapEstimate != nil {
            return "Estimated from finished rounds (par-based)."
        }
        return "Add your Handicap Index, or log a few full rounds to get an estimate."
    }

    private var handicapSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                Text("Handicap Index")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.primaryText)

                Text("Enter your Handicap Index (e.g. 12.4). If you leave it blank, SwingPal can show an estimate once you’ve logged a few full rounds.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)

                TextField("12.4", text: $handicapText)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, ShellTokens.Spacing.x14)
                    .padding(.vertical, ShellTokens.Spacing.x12)
                    .background(palette.quietFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(palette.border, lineWidth: 1)
                    )

                Spacer()
            }
            .padding(ShellTokens.Spacing.x20)
            .background(background.ignoresSafeArea())
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
    }

    private var background: some View {
        ZStack {
            palette.backgroundBase

            LinearGradient(
                colors: [
                    palette.backgroundTopGlow,
                    palette.backgroundBase,
                    palette.backgroundBottomGlow
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette.accent.opacity(colorScheme == .dark ? 0.16 : 0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 42)
                .offset(x: 156, y: -176)

            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.03 : 0.24))
                .frame(width: 240, height: 240)
                .blur(radius: 36)
                .offset(x: -142, y: 188)
        }
        .ignoresSafeArea()
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
            HStack(alignment: .center) {
                Text("PROFILE")
                    .font(ShellTokens.Typography.eyebrow)
                    .tracking(1.2)
                    .foregroundStyle(palette.accent)

                Spacer()

                Text(entitlements == .premium ? "Member 01" : "Player 01")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(palette.quietFill, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(palette.border, lineWidth: 1)
                    }
            }

            Text("Profile")
                .font(ShellTokens.Typography.mastheadTitle)
                .foregroundStyle(palette.primaryText)

            Text("Keep your bag, settings, and account ready for the next round.")
                .font(ShellTokens.Typography.lead)
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
        }
    }

    private func identityMembershipCard(model: ProfileViewModel) -> some View {
        cardContainer(tint: palette.cardStrongTint, padding: 24) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x18) {
                if usesCompactProfileCardLayout {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                        profileIdentityBadge
                        profileIdentityTextStack(model: model)
                    }
                } else {
                    HStack(alignment: .top, spacing: ShellTokens.Spacing.x16) {
                        profileIdentityBadge
                        profileIdentityTextStack(model: model)
                    }
                }

                if usesCompactProfileCardLayout {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                        identityFactCard(
                            title: "Membership",
                            value: model.membershipTitle,
                            note: model.membershipSubtitle
                        )
                        identityFactCard(
                            title: "Bag",
                            value: model.bagSummary,
                            note: authState == .guest ? "Sign in to keep clubs synced." : "Your setup is ready across devices."
                        )
                    }
                } else {
                    HStack(spacing: ShellTokens.Spacing.x12) {
                        identityFactCard(
                            title: "Membership",
                            value: model.membershipTitle,
                            note: model.membershipSubtitle
                        )
                        identityFactCard(
                            title: "Bag",
                            value: model.bagSummary,
                            note: authState == .guest ? "Sign in to keep clubs synced." : "Your setup is ready across devices."
                        )
                    }
                }

                if authState == .guest {
                    if usesCompactProfileCardLayout {
                        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                            Button(action: { isSignInPresented = true }) {
                                HStack(spacing: 10) {
                                    Text(model.identityPrimaryActionTitle)
                                        .font(.headline.weight(.semibold))
                                    Image(systemName: "arrow.right")
                                        .font(.subheadline.weight(.bold))
                                }
                                .foregroundStyle(palette.accentForeground)
                                .padding(.horizontal, ShellTokens.Spacing.x18)
                                .padding(.vertical, ShellTokens.Spacing.x12)
                                .background(palette.accent, in: Capsule())
                            }
                            .buttonStyle(.plain)

                            Button(action: onWatchCompanionTapped) {
                                Text(model.identitySecondaryActionTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.primaryText)
                                    .padding(.horizontal, ShellTokens.Spacing.x16)
                                    .padding(.vertical, ShellTokens.Spacing.x12)
                                    .background(palette.quietFill, in: Capsule())
                                    .overlay {
                                        Capsule()
                                            .stroke(palette.border, lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        HStack(spacing: ShellTokens.Spacing.x12) {
                            Button(action: { isSignInPresented = true }) {
                                HStack(spacing: 10) {
                                    Text(model.identityPrimaryActionTitle)
                                        .font(.headline.weight(.semibold))
                                    Image(systemName: "arrow.right")
                                        .font(.subheadline.weight(.bold))
                                }
                                .foregroundStyle(palette.accentForeground)
                                .padding(.horizontal, ShellTokens.Spacing.x18)
                                .padding(.vertical, ShellTokens.Spacing.x12)
                                .background(palette.accent, in: Capsule())
                            }
                            .buttonStyle(.plain)

                            Button(action: onWatchCompanionTapped) {
                                Text(model.identitySecondaryActionTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.primaryText)
                                    .padding(.horizontal, ShellTokens.Spacing.x16)
                                    .padding(.vertical, ShellTokens.Spacing.x12)
                                    .background(palette.quietFill, in: Capsule())
                                    .overlay {
                                        Capsule()
                                            .stroke(palette.border, lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    if usesCompactProfileCardLayout {
                        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
                            heroPill(model.identityPrimaryActionTitle)
                            Button(action: onWatchCompanionTapped) {
                                HStack(spacing: 8) {
                                    Text(model.identitySecondaryActionTitle)
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        HStack(spacing: ShellTokens.Spacing.x8) {
                            heroPill(model.identityPrimaryActionTitle)
                            Button(action: onWatchCompanionTapped) {
                                HStack(spacing: 8) {
                                    Text(model.identitySecondaryActionTitle)
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var profileIdentityBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            palette.premiumTint.opacity(0.86),
                            palette.cardMutedTint.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 84, height: 84)

            Image(systemName: authState == .guest ? "person.crop.circle.badge.plus" : "person.crop.circle.badge.checkmark")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(palette.accent)
        }
    }

    private func profileIdentityTextStack(model: ProfileViewModel) -> some View {
        let pillPresentation = compactHeroPillPresentation([model.statusTitle, model.membershipTitle])

        return VStack(alignment: .leading, spacing: 8) {
            if usesCompactProfileCardLayout {
                ShellCompactPillFlow(spacing: ShellTokens.Spacing.x8) {
                    ForEach(pillPresentation.visibleTexts, id: \.self) { text in
                        heroPill(text)
                    }
                    if pillPresentation.showsCollapseControl {
                        heroOverflowPill("Less") {
                            isIdentityPillListExpanded = false
                        }
                    } else if pillPresentation.overflowCount > 0 {
                        heroOverflowPill("+\(pillPresentation.overflowCount)") {
                            isIdentityPillListExpanded = true
                        }
                    }
                }
            } else {
                HStack(spacing: ShellTokens.Spacing.x8) {
                    heroPill(model.statusTitle)
                    heroPill(model.membershipTitle)
                }
            }

            Text(model.identityTitle)
                .font(ShellTokens.Typography.sectionTitle)
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(model.identitySubtitle)
                .font(ShellTokens.Typography.body)
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
        }
    }

    private func profileBagClubPreviewRow(club: Club) -> some View {
        HStack(spacing: ShellTokens.Spacing.x12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.quietFill)
                    .frame(width: 44, height: 44)

                Text(club.name.prefix(2).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(club.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                Text(club.subtitle ?? "Typical carry")
                    .font(.caption)
                    .foregroundStyle(palette.tertiaryText)
            }

            Spacer()

            Text(distanceUnit.shortLabel(forMeters: club.typicalDistanceMeters))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryText)
        }
    }

    private var profileViewAllBagButton: some View {
        Button {
            isBagPresented = true
        } label: {
            HStack(alignment: .center, spacing: ShellTokens.Spacing.x12) {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x4) {
                    Text(bag.clubs.isEmpty ? "Open My Bag" : "View all clubs")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryText)
                    Text(
                        bag.clubs.isEmpty
                            ? "Add catalog or custom clubs and set carry distances"
                            : "Edit distances, add or remove clubs"
                    )
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.tertiaryText)
            }
            .padding(ShellTokens.Spacing.x14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.quietFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint(
            bag.clubs.isEmpty
                ? "Opens My Bag to add clubs"
                : "Opens My Bag with your full club list"
        )
    }

    private func bagAndSetupSection(model: ProfileViewModel, recommendation: BagClubRecommendation) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
            sectionHeader(
                eyebrow: "BAG & SETUP",
                title: model.setupTitle,
                subtitle: model.setupSubtitle
            )

            cardContainer(tint: palette.cardTint, padding: 22) {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                    HStack {
                        Text(model.clubRecommendationTitle)
                            .font(ShellTokens.Typography.microEyebrow)
                            .tracking(1.2)
                            .foregroundStyle(palette.tertiaryText)
                        Spacer()
                        heroPill(model.bagSummary)
                    }

                    Text("Suggested club: \(recommendation.clubName)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.primaryText)

                    Text(recommendation.reason)
                        .font(ShellTokens.Typography.body)
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
                }
            }

            cardContainer(tint: palette.cardMutedTint, padding: 22) {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
                    HStack {
                        Text("YOUR BAG")
                            .font(ShellTokens.Typography.microEyebrow)
                            .tracking(1.2)
                            .foregroundStyle(palette.tertiaryText)
                        Spacer()
                        Text("\(bag.clubs.count) clubs")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(palette.quietFill, in: Capsule())
                    }

                    let previewClubs = Array(bag.clubs.prefix(Self.bagClubsPreviewLimit))
                    ForEach(previewClubs) { club in
                        profileBagClubPreviewRow(club: club)
                    }

                    if bag.clubs.count > Self.bagClubsPreviewLimit {
                        Text("Showing \(Self.bagClubsPreviewLimit) of \(bag.clubs.count)")
                            .font(.caption)
                            .foregroundStyle(palette.tertiaryText)
                    }

                    profileViewAllBagButton
                }
            }

            appearanceCard(model: model)
            distanceUnitsCard
        }
    }

    private var distanceUnitsCard: some View {
        cardContainer(tint: palette.cardTint, padding: 22) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                HStack {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                        Text("DISTANCE")
                            .font(ShellTokens.Typography.microEyebrow)
                            .tracking(1.2)
                            .foregroundStyle(palette.tertiaryText)
                        Text("Distance units")
                            .font(ShellTokens.Typography.cardTitle)
                            .foregroundStyle(palette.primaryText)
                    }

                    Spacer()

                    Image(systemName: "ruler")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.accent)
                }

                Text("Choose metres or yards for yardages and carry numbers.")
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)

                Picker("Distance Units", selection: Binding(
                    get: { distanceUnit },
                    set: { onDistanceUnitChanged($0) }
                )) {
                    Text("Metres").tag(DistanceUnit.meters)
                    Text("Yards").tag(DistanceUnit.yards)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func appearanceCard(model: ProfileViewModel) -> some View {
        cardContainer(tint: palette.cardTint, padding: 22) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                HStack {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                        Text("DISPLAY")
                            .font(ShellTokens.Typography.microEyebrow)
                            .tracking(1.2)
                            .foregroundStyle(palette.tertiaryText)
                        Text(model.appearanceTitle)
                            .font(ShellTokens.Typography.cardTitle)
                            .foregroundStyle(palette.primaryText)
                    }

                    Spacer()

                    Image(systemName: "circle.lefthalf.filled")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.accent)
                }

                Text(model.appearanceSubtitle)
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)

                HStack(spacing: ShellTokens.Spacing.x12) {
                    appearanceCardOption("System", subtitle: "Follow device", mode: .system)
                    appearanceCardOption("Light", subtitle: "Bright surfaces", mode: .light)
                    appearanceCardOption("Dark", subtitle: "Low-glare", mode: .dark)
                }
            }
        }
    }

    private func premiumCard(model: ProfileViewModel) -> some View {
        cardContainer(
            tint: entitlements == .premium ? palette.cardTint : palette.premiumTint,
            padding: 22
        ) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PREMIUM")
                            .font(ShellTokens.Typography.microEyebrow)
                            .tracking(1.2)
                            .foregroundStyle(palette.tertiaryText)

                        Text(model.premiumTitle)
                            .font(ShellTokens.Typography.sectionTitle)
                            .foregroundStyle(palette.primaryText)
                    }

                    Spacer()

                    Image(systemName: "applewatch")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(palette.accent)
                }

                Text(model.premiumSubtitle)
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)

                if entitlements == .premium {
                    Text("Open the companion to check connection state, confirm setup readiness, and jump back into a live round when one is active.")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
                }

                ViewThatFits(in: .vertical) {
                    HStack(spacing: ShellTokens.Spacing.x8) {
                        premiumPill("Watch live")
                        premiumPill("Search assist")
                        premiumPill("Deeper coaching")
                    }

                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                        premiumPill("Watch live")
                        premiumPill("Search assist")
                        premiumPill("Deeper coaching")
                    }
                }

                Button(action: onWatchCompanionTapped) {
                    HStack(spacing: 10) {
                        Text(model.premiumCTA)
                            .font(.headline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(entitlements == .premium ? palette.primaryText : palette.accentForeground)
                    .padding(.horizontal, ShellTokens.Spacing.x18)
                    .padding(.vertical, ShellTokens.Spacing.x12)
                    .background(
                        entitlements == .premium ? palette.quietFill : palette.accent,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(entitlements == .premium ? palette.border : palette.premiumBorder, lineWidth: 1)
        }
    }

    private func diagnosticsSection(model: ProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            sectionHeader(
                eyebrow: "DIAGNOSTICS",
                title: model.diagnosticsTitle,
                subtitle: model.diagnosticsSubtitle
            )

            gpsModeCard(model: model)
        }
    }

    private var accountSection: some View {
        cardContainer(tint: palette.cardMutedTint, padding: 22) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
                Text("ACCOUNT")
                    .font(ShellTokens.Typography.microEyebrow)
                    .tracking(1.2)
                    .foregroundStyle(palette.tertiaryText)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Signed in")
                        .font(ShellTokens.Typography.cardTitle)
                        .foregroundStyle(palette.primaryText)
                    if let label = currentUserDisplayName, !label.isEmpty {
                        Text(label)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(palette.secondaryText)
                    }
                }

                Button {
                    onSignOut()
                } label: {
                    Text("Sign out")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(palette.accentForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ShellTokens.Spacing.x12)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func gpsModeCard(model: ProfileViewModel) -> some View {
        cardContainer(tint: palette.cardMutedTint, padding: 22) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                HStack(alignment: .top, spacing: ShellTokens.Spacing.x12) {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                        Text(model.gpsModeTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(palette.primaryText)

                        Text(model.gpsModeSubtitle)
                            .font(ShellTokens.Typography.body.weight(.medium))
                            .foregroundStyle(palette.secondaryText)
                    }

                    Spacer(minLength: 12)

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { gpsMode == .testPreview },
                            set: { isEnabled in
                                onGPSModeChanged(isEnabled ? .testPreview : .live)
                            }
                        )
                    )
                    .labelsHidden()
                    .tint(palette.accent)
                }

                HStack(spacing: ShellTokens.Spacing.x8) {
                    modePill("Live", isSelected: gpsMode == .live)
                    modePill("Test GPS", isSelected: gpsMode == .testPreview)
                }
            }
        }
    }

    private func cardContainer<Content: View>(
        tint: Color,
        padding: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        return VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(padding)
        .background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(tint)
            }
        }
        .overlay {
            shape
                .stroke(palette.border, lineWidth: 1)
                .overlay {
                    shape
                        .stroke(palette.glassHighlight, lineWidth: 1)
                        .blur(radius: 0.2)
                        .padding(1)
                }
        }
        .shadow(color: palette.shadow, radius: 18, y: 10)
    }

    private func sectionHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(ShellTokens.Typography.microEyebrow)
                .tracking(1.2)
                .foregroundStyle(palette.tertiaryText)

            Text(title)
                .font(ShellTokens.Typography.sectionTitle)
                .foregroundStyle(palette.primaryText)

            Text(subtitle)
                .font(ShellTokens.Typography.body)
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
        }
    }

    private func heroPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(palette.quietFill, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(palette.border, lineWidth: 1)
            }
    }

    private func heroOverflowPill(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            heroPill(text)
        }
        .buttonStyle(.plain)
    }

    private func identityFactCard(title: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(ShellTokens.Typography.microEyebrow)
                .tracking(1.0)
                .foregroundStyle(palette.tertiaryText)

            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(palette.primaryText)

            Text(note)
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ShellTokens.Spacing.x16)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.quietFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
    }

    private func appearanceCardOption(_ title: String, subtitle: String, mode: AppAppearanceMode) -> some View {
        let isSelected = appearanceMode == mode

        return Button {
            onAppearanceModeChanged(mode)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isSelected ? palette.accentForeground : palette.primaryText)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle((isSelected ? palette.accentForeground : palette.secondaryText).opacity(0.82))
            }
            .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
            .padding(ShellTokens.Spacing.x16)
            .background(
                isSelected
                ? LinearGradient(
                    colors: [palette.accent, ShellTokens.ColorRole.pine500],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                : LinearGradient(
                    colors: [palette.quietFill, palette.cardMutedTint],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.10) : palette.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func premiumPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(palette.quietFill, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(palette.border, lineWidth: 1)
            }
    }

    private func modePill(_ text: String, isSelected: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? palette.accentForeground : palette.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? palette.accent : palette.quietFill,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.white.opacity(0.08) : palette.border, lineWidth: 1)
            }
    }
}
