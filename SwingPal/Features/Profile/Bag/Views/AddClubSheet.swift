import SwiftUI

/// A single draft survives browsing, searching and custom entry until the golfer commits it.
struct AddClubSheet: View {
    private enum Destination: Hashable {
        case brand(String)
        case modelRange(brand: String, name: String)
        case model(String)
        case custom
        case review
    }

    let distanceUnit: DistanceUnit
    let onAddClubs: ([Club]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selection: AddClubSelection
    @State private var catalogDocument = ClubCatalogStore.shared.document
    @State private var path: [Destination] = []
    @State private var query = ""
    @State private var category: ClubCatalogCategory?
    @State private var custom = AddCustomClubForm()
    @State private var customError: String?
    @State private var showsDiscard = false
    @State private var showsUnfinishedCustom = false

    init(existingClubs: [Club], distanceUnit: DistanceUnit, onAddClubs: @escaping ([Club]) -> Void) {
        self.distanceUnit = distanceUnit
        self.onAddClubs = onAddClubs
        _selection = State(initialValue: AddClubSelection(existingClubs: existingClubs))
    }

    private var results: [ClubCatalogFamily] {
        catalogDocument.search(query: query, category: category)
    }

    private var customHasChanges: Bool { custom.hasChanges }

    private var hasChanges: Bool { selection.hasChanges || customHasChanges }
    private var isReview: Bool { path.last == .review }
    private var bagCount: Int { selection.existingClubs.count + selection.drafts.count }
    private var primaryAction: AddClubPrimaryAction {
        .resolve(isReview: isReview, isCustomPage: path.last == .custom, hasCustomChanges: customHasChanges)
    }

    var body: some View {
        NavigationStack(path: $path) {
            catalog
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
                .navigationTitle("Add clubs")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Maker, model or club · e.g. PING 7 iron")
                .autocorrectionDisabled()
                .toolbar { closeToolbar }
                .navigationDestination(for: Destination.self) { destination in
                    Group {
                        switch destination {
                        case .brand(let brand):
                            brandPage(brand)
                                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search \(brand) models")
                                .autocorrectionDisabled()
                        case .modelRange(let brand, let name):
                            if let model = ClubCatalogModelGroup.grouped(catalogDocument.search(query: query, category: category, brand: brand))
                                .first(where: { $0.name == name }) {
                                modelVersionsPage(model)
                            }
                        case .model(let id):
                            if let family = catalogDocument.families.first(where: { $0.id == id }) {
                                modelPage(family)
                            }
                        case .custom: customPage
                        case .review: reviewPage
                        }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
                    .toolbar { closeToolbar }
                    .navigationBarTitleDisplayMode(.inline)
                }
        }
        .tint(Book.stamp)
        .presentationDetents([.large])
        .interactiveDismissDisabled(hasChanges)
        .task {
            await ClubCatalogStore.shared.refreshIfNeeded()
            // Never change a model or a selection underneath an active editing session.
            if path.isEmpty && !hasChanges && query.isEmpty && category == nil {
                catalogDocument = ClubCatalogStore.shared.document
            }
        }
        .confirmationDialog("Discard your selected clubs?", isPresented: $showsDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your selections and unfinished custom club will be lost. Your saved bag will stay as it is.")
        }
        .confirmationDialog("Add selected clubs without the custom draft?", isPresented: $showsUnfinishedCustom, titleVisibility: .visible) {
            Button("Add selected clubs and discard draft", action: commitSelectedClubs)
            Button("Keep editing the custom club") { path.append(.custom) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your selected clubs are ready. The unfinished custom club hasn’t been selected and won’t be added.")
        }
    }

    @ToolbarContentBuilder
    private var closeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Close") {
                if hasChanges { showsDiscard = true } else { dismiss() }
            }
        }
    }

    private var catalog: some View {
        let matches = results
        let sections = ClubCatalogBrandSection.alphabetical(matches)
        let brands = sections.flatMap(\.brands)
        return ScrollViewReader { proxy in
            List {
                Section {
                    Text("Choose a brand").font(Book.Typeface.heading)
                    Text("Choose your brand, model and version, then the club number or loft you play.")
                        .font(.subheadline).foregroundStyle(Book.pencil)
                    catalogFilters
                    Text("\(brands.count) brands · \(matches.count) versions")
                        .font(.subheadline).foregroundStyle(Book.pencil)
                }.listRowBackground(Color.clear)
                customEntrySection
                if matches.isEmpty { emptyCatalogSection }
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.brands) { brand in
                            NavigationLink(value: Destination.brand(brand.name)) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(brand.name).font(.headline)
                                    let modelCount = ClubCatalogModelGroup.grouped(brand.families).count
                                    Text("\(modelCount) model\(modelCount == 1 ? "" : "s")")
                                        .font(.subheadline).foregroundStyle(Book.pencil)
                                    let count = selection.drafts.filter { $0.brand == brand.name }.count
                                    if count > 0 {
                                        Text("\(count) selected").font(.caption.weight(.semibold)).foregroundStyle(Book.stamp)
                                    }
                                }.padding(.vertical, 4)
                            }
                        }
                    }
                    .id(section.id)
                    .listRowBackground(Book.leaf)
                }
            }
            .bookList()
            .contentMargins(.trailing, sections.count > 1 ? 44 : 20, for: .scrollContent)
            .hideSystemCatalogIndex()
            .overlay(alignment: .trailing) {
                if sections.count > 1 {
                    ClubCatalogLetterIndex(letters: sections.map(\.title), label: "Brand index") { letter in
                        proxy.scrollTo(letter, anchor: .top)
                    }
                    .frame(width: 44)
                }
            }
        }
    }

    private var catalogFilters: some View {
        HStack {
            Menu {
                Button("All types") { category = nil }
                ForEach(ClubCatalogCategory.allCases, id: \.self) { value in
                    Button(value.title) { category = value }
                }
            } label: { Label(category?.title ?? "All types", systemImage: "line.3.horizontal.decrease") }
            Spacer()
            if category != nil || !query.isEmpty {
                Button("Clear filters") { query = ""; category = nil }
            }
        }
        .font(.subheadline.weight(.semibold))
    }

    private var customEntrySection: some View {
        Section {
            Button { path.append(.custom) } label: {
                Label("Add a custom club", systemImage: "plus")
            }
        } footer: {
            Text("Missing a model or an older club? Enter its details yourself.")
        }
        .listRowBackground(Book.leaf)
    }

    private var emptyCatalogSection: some View {
        Section {
            ContentUnavailableView {
                Label("No matching clubs", systemImage: "magnifyingglass")
            } description: {
                Text("Try a model name, a maker, or a club number. You can also clear the filters or add a custom club.")
            } actions: {
                Button("Add a custom club") { path.append(.custom) }
            }
        }.listRowBackground(Book.leaf)
    }

    private func brandPage(_ brand: String) -> some View {
        let matches = catalogDocument.search(query: query, category: category, brand: brand)
        let sections = ClubCatalogSection.alphabetical(matches)
        return ScrollViewReader { proxy in
            catalogList(matches: matches, sections: sections, proxy: proxy)
                .overlay(alignment: .trailing) {
                    if sections.count > 1 {
                        ClubCatalogLetterIndex(letters: sections.map(\.title), label: "Model index") { letter in
                            proxy.scrollTo(letter, anchor: .top)
                        }
                        .frame(width: 44)
                    }
                }
        }
        .navigationTitle(brand)
    }

    private func catalogList(matches: [ClubCatalogFamily], sections: [ClubCatalogSection], proxy: ScrollViewProxy) -> some View {
        let modelCount = sections.flatMap(\.models).count
        return List {
            Section {
                Text("Choose a model")
                    .font(Book.Typeface.heading)
                Text("Choose a model range, then find your version and club options.")
                    .font(.subheadline).foregroundStyle(Book.pencil)
                catalogFilters
                HStack {
                    Text("\(modelCount) model\(modelCount == 1 ? "" : "s") · A–Z")
                        .font(.subheadline).foregroundStyle(Book.pencil)
                    Spacer()
                    if sections.count > 1 {
                        Menu("Jump to letter") {
                            ForEach(sections) { section in
                                Button(section.title) { proxy.scrollTo(section.id, anchor: .top) }
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .listRowBackground(Color.clear)

            if matches.isEmpty { emptyCatalogSection }
            ForEach(sections) { section in
                Section {
                    ForEach(section.models) { model in
                        NavigationLink(value: model.families.count == 1
                                       ? Destination.model(model.families[0].id)
                                       : Destination.modelRange(brand: model.brand, name: model.name)) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(model.name).font(.headline)
                                Text(ClubCatalogCategory.allCases.filter { type in model.families.contains { $0.category == type } }
                                    .map(\.title).joined(separator: " · "))
                                    .font(.subheadline).foregroundStyle(Book.pencil)
                                let names = Set(model.families.map(\.name))
                                let count = selection.drafts.filter { $0.brand == model.brand && names.contains($0.family ?? "") }.count
                                if count > 0 {
                                    Text("\(count) selected").font(.caption.weight(.semibold)).foregroundStyle(Book.stamp)
                                }
                            }.padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text(section.title)
                        .font(.headline)
                        .accessibilityLabel(section.title == "#" ? "Numbered models" : "Models beginning with \(section.title)")
                }
                .id(section.id)
                .listRowBackground(Book.leaf)
            }
        }
        .bookList()
        .contentMargins(.trailing, sections.count > 1 ? 44 : 20, for: .scrollContent)
        .hideSystemCatalogIndex()
    }

    private func modelVersionsPage(_ model: ClubCatalogModelGroup) -> some View {
        List {
            Section {
                Text(model.brand).font(.subheadline).foregroundStyle(Book.pencil)
                Text("Choose your \(model.name)").font(Book.Typeface.heading)
                Text("Choose the version on your club, then select its number or loft.")
                    .font(.subheadline).foregroundStyle(Book.pencil)
            }.listRowBackground(Color.clear)
            ForEach(ClubCatalogCategory.allCases, id: \.self) { type in
                let versions = model.families.filter { $0.category == type }
                if !versions.isEmpty {
                    Section(type.title) {
                        ForEach(versions) { family in
                            NavigationLink(value: Destination.model(family.id)) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(model.versionName(family)).font(.headline)
                                    Text(family.name).font(.subheadline).foregroundStyle(Book.pencil)
                                    let count = family.variants.filter { selection.isSelected(family: family, variant: $0) }.count
                                    if count > 0 {
                                        Text("\(count) selected").font(.caption.weight(.semibold)).foregroundStyle(Book.stamp)
                                    }
                                }.padding(.vertical, 4)
                            }
                        }
                    }.listRowBackground(Book.leaf)
                }
            }
        }
        .bookList()
        .navigationTitle(model.name)
    }

    private func modelPage(_ family: ClubCatalogFamily) -> some View {
        List {
            Section {
                Text(family.brand).font(.subheadline).foregroundStyle(Book.pencil)
                Text(family.name).font(Book.Typeface.heading)
                Text(family.category == .putter
                     ? "Select this putter, then keep browsing to add other clubs."
                     : "Choose the markings on your clubs. You can keep browsing other models after selecting.")
                    .font(.subheadline).foregroundStyle(Book.pencil)
            }.listRowBackground(Color.clear)
            Section(family.category == .putter ? "Select putter" : "Club number / loft") {
                ForEach(family.variants) { variant in
                    let owned = selection.isOwned(family: family, variant: variant)
                    let selected = selection.isSelected(family: family, variant: variant)
                    Button {
                        selection.toggle(family: family, variant: variant, unit: distanceUnit)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: owned ? "checkmark.seal" : selected ? "checkmark.circle.fill" : "circle")
                                .font(.title3).foregroundStyle(owned ? Book.pencil : Book.stamp)
                            Text(variant.displayName).font(.headline).foregroundStyle(Book.ink)
                            Spacer()
                            if owned { Text("In your bag").font(.caption).foregroundStyle(Book.pencil) }
                        }.padding(.vertical, 8)
                    }
                    .disabled(owned)
                    .accessibilityLabel("\(variant.displayName), \(owned ? "already in your bag" : selected ? "selected" : "not selected")")
                    .accessibilityHint(owned ? "Edit this club from My bag" : "Toggle selection")
                }
            }.listRowBackground(Book.leaf)
            Section {
                Button("Enter a different club from this maker") {
                    custom.suggest(family)
                    path.append(.custom)
                }
            } footer: {
                Text("Catalog options are a starting list. Use custom entry if your exact model or marking isn’t listed.")
            }.listRowBackground(Book.leaf)
        }
        .bookList()
        .navigationTitle(family.category.title)
    }

    private var customPage: some View {
        Form {
            Section {
                Text("Your club, your details.").font(Book.Typeface.heading)
                Text("Give it the name you want to see in your bag and during a round.")
                    .font(.subheadline).foregroundStyle(Book.pencil)
            }.listRowBackground(Color.clear)
            Section("Club") {
                TextField("Club name · e.g. 7I or 54°", text: $custom.name)
                    .accessibilityLabel("Club name")
                Picker("Type", selection: $custom.category) {
                    ForEach(ClubCatalogCategory.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                TextField("Maker (optional)", text: $custom.maker)
                TextField("Model (optional)", text: $custom.model)
            }.listRowBackground(Book.leaf)
            if custom.category != .putter {
                Section {
                    HStack {
                        Text("Carry (\(distanceUnit.shortSuffix))")
                        TextField("Distance", text: $custom.carry)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .accessibilityLabel("Custom club carry in \(distanceUnit.shortSuffix)")
                    }
                    if !custom.carry.isEmpty && ClubCarryInput.meters(from: custom.carry, unit: distanceUnit) == nil {
                        carryError
                    }
                } header: { Text("Your usual carry") }
                footer: { Text("Distance through the air, before the ball rolls. You can adjust it later.") }
                .listRowBackground(Book.leaf)
            } else {
                Section { Text("Putters don’t need a full-swing carry distance.").foregroundStyle(Book.pencil) }
                    .listRowBackground(Book.leaf)
            }
            Section {
                Button("Add to selected clubs", action: stageCustomClub)
                .disabled(!canAddCustom)
                if let customError { Text(customError).font(.subheadline).foregroundStyle(Book.flag) }
                if customHasChanges {
                    Button("Clear custom details", role: .destructive, action: clearCustom)
                }
            }.listRowBackground(Book.leaf)
        }
        .bookList()
        .navigationTitle("Custom club")
        .onChange(of: custom.name) { _, _ in customError = nil }
        .onChange(of: custom.maker) { _, _ in customError = nil }
        .onChange(of: custom.model) { _, _ in customError = nil }
    }

    private func clearCustom() {
        custom.clear()
        customError = nil
    }

    private func stageCustomClub() {
        if selection.addCustom(name: custom.name, brand: custom.maker, model: custom.model,
            category: custom.category, distanceText: custom.carry, unit: distanceUnit) {
            clearCustom()
            path.removeLast()
        } else {
            customError = "This club is already in your bag or your selections. Edit its carry there."
        }
    }

    private var canAddCustom: Bool {
        !custom.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (custom.category == .putter || ClubCarryInput.meters(from: custom.carry, unit: distanceUnit) != nil)
    }

    private var reviewPage: some View {
        List {
            Section {
                Text("Make the numbers yours.").font(Book.Typeface.heading)
                Text("Catalog carries are starting estimates, not measured distances for these models. Change them to match your game.")
                    .font(.subheadline).foregroundStyle(Book.pencil)
                if bagCount > 14 {
                    Text("Your bag will contain \(bagCount) clubs. Choose the clubs you’ll take before your next round.")
                        .font(.subheadline).foregroundStyle(Book.pencil)
                }
            }.listRowBackground(Color.clear)
            ForEach($selection.drafts) { $draft in
                Section {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.name).font(.headline)
                            Text([draft.brand, draft.family].compactMap { $0 }.joined(separator: " · "))
                                .font(.subheadline).foregroundStyle(Book.pencil)
                        }
                        Spacer()
                        Button(role: .destructive) { selection.drafts.removeAll { $0.id == draft.id } } label: {
                            Image(systemName: "minus.circle")
                        }
                        .accessibilityLabel("Remove \(draft.name) from selected clubs")
                    }
                    if draft.isPutter {
                        Text("Putter · no carry needed").font(.subheadline).foregroundStyle(Book.pencil)
                    } else {
                        HStack {
                            Text("Carry (\(distanceUnit.shortSuffix))")
                            TextField("Distance", text: $draft.distanceText)
                                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                                .accessibilityLabel("\(draft.name) carry in \(distanceUnit.shortSuffix)")
                        }
                        if draft.club == nil { carryError }
                    }
                } footer: {
                    if !draft.isPutter {
                        Text(draft.source == .catalog ? "Starting estimate · adjust to your usual carry." : "Your carry · editable before adding.")
                    }
                }
                .listRowBackground(Book.leaf)
            }
            if selection.drafts.isEmpty {
                ContentUnavailableView("No clubs selected", systemImage: "figure.golf", description: Text("Go back to choose clubs from the catalog or add your own."))
                    .listRowBackground(Color.clear)
            }
        }
        .bookList()
        .navigationTitle("Review \(selection.drafts.count) club\(selection.drafts.count == 1 ? "" : "s")")
    }

    private var carryError: some View {
        Text("Enter a whole number from 1 to \(distanceUnit.scalarValue(fromMeters: ClubCarryInput.maximumMeters)) \(distanceUnit.shortSuffix).")
            .font(.caption).foregroundStyle(Book.flag)
    }

    private var primaryActionTitle: String {
        switch primaryAction {
        case .stageCustom: return "Add custom to selected"
        case .addSelected: return "Add \(selection.drafts.count) to my bag"
        case .review: return "Review \(selection.drafts.count) selected club\(selection.drafts.count == 1 ? "" : "s")"
        }
    }

    private func commitSelectedClubs() {
        guard let clubs = selection.clubs else { return }
        onAddClubs(clubs)
        dismiss()
    }

    @ViewBuilder
    private var bottomBar: some View {
        if !selection.drafts.isEmpty {
            VStack(spacing: 12) {
                if !isReview {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(selection.drafts) { draft in
                                Button { selection.drafts.removeAll { $0.id == draft.id } } label: {
                                    HStack(spacing: 8) {
                                        Text("\(draft.name)\(draft.brand.map { " · \($0)" } ?? "")")
                                        Image(systemName: "xmark").font(.caption)
                                    }
                                    .font(.subheadline).padding(.horizontal, 12).padding(.vertical, 10)
                                    .background(Book.wash, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(draft.name), \(draft.brand ?? "custom club")")
                            }
                        }
                    }.scrollIndicators(.hidden)
                }
                if customHasChanges && path.last != .custom {
                    HStack {
                        Text("Unfinished custom club").foregroundStyle(Book.pencil)
                        Spacer()
                        Button("Edit") { path.append(.custom) }
                        Button("Discard", role: .destructive, action: clearCustom)
                    }
                    .font(.caption)
                }
                Button {
                    switch primaryAction {
                    case .stageCustom: stageCustomClub()
                    case .review: path.append(.review)
                    case .addSelected:
                        if customHasChanges { showsUnfinishedCustom = true }
                        else { commitSelectedClubs() }
                    }
                } label: {
                    Text(primaryActionTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BookStampButtonStyle())
                .disabled((isReview && selection.clubs == nil) || (primaryAction == .stageCustom && !canAddCustom))
                .opacity(isReview && selection.clubs == nil ? 0.5 : 1)
            }
            .padding(16)
            .background(Book.paper)
            .overlay(alignment: .top) { Book.rule.frame(height: 1) }
        }
    }
}

/// The hit area stays still while the glyphs grow and move inward around the finger or pointer.
private struct ClubCatalogLetterIndex: View {
    let letters: [String]
    let label: String
    let onSelect: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var hoverPosition: CGFloat?
    @State private var dragPosition: CGFloat?
    @State private var lastDragSelection: String?
    @State private var lastSelection: String?

    private var position: CGFloat? { dragPosition ?? hoverPosition }

    var body: some View {
        GeometryReader { geometry in
            let rowHeight = min(16, geometry.size.height / CGFloat(max(letters.count, 1)))
            VStack(spacing: 0) {
                ForEach(Array(letters.enumerated()), id: \.element) { index, letter in
                    letterView(letter, index: index, rowHeight: rowHeight)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let next = indexPosition(at: value.location.y, rowHeight: rowHeight)
                        dragPosition = next
                        let letter = letters[Int(next.rounded())]
                        if letter != lastDragSelection {
                            lastDragSelection = letter
                            select(letter)
                        }
                    }
                    .onEnded { _ in
                        dragPosition = nil
                        lastDragSelection = nil
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoverPosition = indexPosition(at: location.y, rowHeight: rowHeight)
                case .ended:
                    hoverPosition = nil
                }
            }
            .animation(reduceMotion ? nil : .interactiveSpring(response: 0.24, dampingFraction: 0.8), value: position)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(lastSelection ?? letters.first ?? "")
            .accessibilityHint("Swipe up or down to jump to an alphabetical section")
            .accessibilityAdjustableAction { direction in
                let current = letters.firstIndex(of: lastSelection ?? "") ?? 0
                switch direction {
                case .increment: select(letters[min(current + 1, letters.count - 1)])
                case .decrement: select(letters[max(current - 1, 0)])
                @unknown default: break
                }
            }
            .frame(maxHeight: .infinity)
        }
        .onChange(of: letters) { _, _ in
            hoverPosition = nil
            dragPosition = nil
            lastDragSelection = nil
            lastSelection = nil
        }
    }

    private func letterView(_ letter: String, index: Int, rowHeight: CGFloat) -> some View {
        let distance = CGFloat(index) - (position ?? CGFloat(index))
        let proximity: CGFloat = position == nil ? 0 : max(0, 1 - abs(distance) / 2.5)
        let influence = proximity * proximity
        let active = position.map { Int($0.rounded()) == index } ?? false
        let horizontal: CGFloat = (layoutDirection == .rightToLeft ? 1 : -1) * 22 * influence
        let vertical = distance * proximity * 12

        return Text(letter)
            .font(.system(size: 11, weight: active ? .heavy : .semibold, design: .rounded))
            .foregroundStyle(active ? Book.stamp : Book.pencil)
            .scaleEffect(reduceMotion ? 1 : 1 + 1.3 * influence)
            .offset(x: reduceMotion ? 0 : horizontal, y: reduceMotion ? 0 : vertical)
            .frame(width: 44, height: rowHeight)
            .allowsHitTesting(false)
            .zIndex(Double(influence))
    }

    private func indexPosition(at y: CGFloat, rowHeight: CGFloat) -> CGFloat {
        min(CGFloat(letters.count - 1), max(0, y / max(rowHeight, 1) - 0.5))
    }

    private func select(_ letter: String) {
        lastSelection = letter
        onSelect(letter)
    }
}

private extension View {
    @ViewBuilder
    func hideSystemCatalogIndex() -> some View {
        if #available(iOS 26.0, *) {
            self.listSectionIndexVisibility(.hidden)
        } else {
            self
        }
    }

    func bookList() -> some View {
        self.scrollContentBackground(.hidden)
            .background(Book.paper)
            .foregroundStyle(Book.ink)
            .scrollDismissesKeyboard(.interactively)
    }
}

#if DEBUG
/// Interactive sample bag; changes stay in memory and cannot reach saved rounds or sync.
struct AddClubReviewFixture: View {
    let distanceUnit: DistanceUnit
    @State private var clubs = Bag.starter.clubs
    @State private var showsAddClubs = true

    var body: some View {
        NavigationStack {
            List(clubs) { club in
                VStack(alignment: .leading, spacing: 6) {
                    Text(club.name).font(.headline)
                    Text(club.subtitle ?? "Custom club").font(.subheadline)
                    Text(club.isPutter ? "Putter" : distanceUnit.shortLabel(forMeters: club.typicalDistanceMeters))
                }
            }
            .navigationTitle("Sample bag")
            .toolbar { Button("Add clubs") { showsAddClubs = true } }
            .sheet(isPresented: $showsAddClubs) {
                AddClubSheet(existingClubs: clubs, distanceUnit: distanceUnit) { clubs.append(contentsOf: $0) }
            }
        }
    }
}
#endif
