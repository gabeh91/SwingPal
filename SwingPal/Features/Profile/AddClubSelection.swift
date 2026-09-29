import Foundation

struct AddCustomClubForm {
    var name = ""
    var maker = ""
    var model = ""
    var category: ClubCatalogCategory = .iron
    var carry = ""
    private var suggestedMaker = ""
    private var suggestedModel = ""
    private var suggestedCategory: ClubCatalogCategory = .iron

    var hasChanges: Bool {
        !name.isEmpty || !carry.isEmpty || maker != suggestedMaker ||
        model != suggestedModel || category != suggestedCategory
    }

    mutating func suggest(_ family: ClubCatalogFamily) {
        guard !hasChanges else { return }
        maker = family.brand
        model = family.name
        category = family.category
        suggestedMaker = maker
        suggestedModel = model
        suggestedCategory = category
    }

    mutating func clear() { self = Self() }
}

enum AddClubPrimaryAction: Equatable {
    case review, addSelected, stageCustom

    static func resolve(isReview: Bool, isCustomPage: Bool, hasCustomChanges: Bool) -> Self {
        if isCustomPage && hasCustomChanges { return .stageCustom }
        return isReview ? .addSelected : .review
    }
}

/// Browse groups are display-only: the original family IDs and saved club names stay intact.
struct ClubCatalogModelGroup: Identifiable {
    let brand: String
    let name: String
    let families: [ClubCatalogFamily]
    var id: String { "\(brand) / \(name)" }

    static func grouped(_ families: [ClubCatalogFamily]) -> [Self] {
        Dictionary(grouping: families) { [$0.brand, modelName($0)] }.map { key, values in
            Self(brand: key[0], name: key[1], families: values.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            })
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func versionName(_ family: ClubCatalogFamily) -> String {
        let base = Self.withoutClubType(family)
        guard let range = base.range(of: name, options: .caseInsensitive),
              range.upperBound == base.endIndex || !base[range.upperBound].isLetter else { return base }
        let remainder = base.replacingCharacters(in: range, with: "")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return remainder.isEmpty ? "Standard" : remainder
    }

    private static func withoutClubType(_ family: ClubCatalogFamily) -> String {
        let suffix: String
        switch family.category {
        case .driver: suffix = "Drivers?"
        case .fairwayWood: suffix = "Fairway(?: Woods?)?"
        case .hybrid: suffix = "Hybrids?|Rescue"
        case .iron: suffix = "Irons?"
        case .utilityIron: suffix = "Utility(?: Irons?)?"
        case .wedge: suffix = "Wedges?"
        case .putter: suffix = "Putters?"
        }
        let name = family.name.replacingOccurrences(of: "(?i)\\s+(?:\(suffix))$", with: "", options: .regularExpression)
        return name.isEmpty ? family.name : name
    }

    private static func modelName(_ family: ClubCatalogFamily) -> String {
        let name = withoutClubType(family).replacingOccurrences(
            of: #"(?i)^(?:Women's |Women’s |Ladies |Junior )"#, with: "", options: .regularExpression)
        guard let pattern = modelPatterns[family.brand],
              let match = name.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            // Unrecognized names stay distinct instead of guessing that different models are related.
            return withoutClubType(family)
        }
        return String(name[match]).replacingOccurrences(of: #"(?i)^COBRA "#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "V-Series", with: "V Series")
    }

    // These prefixes describe established ranges in the catalog, never club specifications.
    // Generation numbers and meaningful line names are retained; unknown imports use their full names.
    private static let modelPatterns: [String: String] = [
        "Bettinardi": #"^(?:Antidote|Queen B|Junior Series)\b|^BB(?=\d|\s)"#,
        "Callaway": #"^(?:Elyte|Quantum|Paradym Ai Smoke|REVA RISE)\b"#,
        "Cleveland": #"^(?:HB SOFT 2|HB SOFT Milled|CBX 4 ZipCore|CBX Full-Face 2|CBZ|RTZ)\b"#,
        "Cobra": #"^(?:COBRA )?(?:3DP(?: TOUR)?|DARKSPEED|DS-ADAPT|OPTM|BAFFLER|KING-X|KING(?: TEC(?:-X)?| Tour| CB/MB)?|MIM|LIMIT3D)\b"#,
        "Evnroll": #"^(?:ORIGIN|ZERO|V[ -]Series|EZPZ)\b"#,
        "Honma": #"^(?:BERES \d+|TW\d+|T//WORLD|Honma Sakata Lab|Honma x Bugatti)\b"#,
        "LAB Golf": #"^(?:MEZZ\.1|OZ\.1|DF3)(?=\b|i)|^LINK\.2(?=\.)"#,
        "Miura": #"^Forged Wedge Series\b"#,
        "Mizuno": #"^(?:JPX ONE|JPX\d+|M\.Craft(?: X)?|Mizuno Pro)\b"#,
        "New Level": #"^(?:480|702|SPN)(?=[\s-])"#,
        "Odyssey": #"^Ai-ONE(?: Square 2 Square)?\b"#,
        "PING": #"^(?:G Le\d+|G\d+|Blueprint|SCOTTSDALE(?: TEC)?|PLD MILLED(?: SE)?)\b"#,
        "PXG": #"^0311(?: Black Ops)?\b"#,
        "Scotty Cameron": #"^(?:Phantom|Studio Style)\b"#,
        "Srixon": #"^(?:ZXi RKT|ZXi)(?=\b|[45R])"#,
        "Takomo": #"^(?:101T?|201T?|301|Ignis D2|Skyforger)\b"#,
        "TaylorMade": #"^(?:Qi4D|Qi35|Qi Max|Spider Tour|Spider ZT|P\d+|MG\d+)\b"#,
        "Titleist": #"^(?:GTS\d+|GT\d+|T\d+|620|Vokey SM\d+|U•\d+)\b"#,
        "Tour Edge": #"^(?:Exotics (?:[CEX]\d+|EXS Pro|Wingman)|Exotics|HP Series|Hot Launch (?:[CE]\d+|Max)|Hot Launch|Bazooka Pro|Zero T|Template)\b"#,
        "Wilson": #"^(?:DYNAPWR|Staff Model)\b"#,
        "XXIO": #"^\d+\+?(?=\s|$)"#
    ]
}

struct ClubCatalogSection: Identifiable {
    let title: String
    let models: [ClubCatalogModelGroup]
    var id: String { title }

    static func alphabetical(_ families: [ClubCatalogFamily]) -> [Self] {
        let grouped = Dictionary(grouping: ClubCatalogModelGroup.grouped(families)) { model in
            let name = model.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            guard let first = name.uppercased().first, first.isLetter else { return "#" }
            return String(first)
        }
        return grouped.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { title in
            Self(title: title, models: grouped[title, default: []].sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            })
        }
    }
}

struct ClubCatalogBrandGroup: Identifiable {
    let name: String
    let families: [ClubCatalogFamily]
    var id: String { name }
}

struct ClubCatalogBrandSection: Identifiable {
    let title: String
    let brands: [ClubCatalogBrandGroup]
    var id: String { title }

    static func alphabetical(_ families: [ClubCatalogFamily]) -> [Self] {
        let brands = Dictionary(grouping: families, by: \.brand).map { name, families in
            ClubCatalogBrandGroup(name: name, families: families)
        }
        let sections = Dictionary(grouping: brands) { String($0.name.prefix(1)).uppercased() }
        return sections.keys.sorted().map { title in
            Self(title: title, brands: sections[title, default: []].sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            })
        }
    }
}

extension ClubCatalogDocument {
    /// All terms may match across maker, model, type and the markings on a club.
    func search(query: String, category: ClubCatalogCategory? = nil, brand: String? = nil) -> [ClubCatalogFamily] {
        let terms = Self.searchText(query).split(separator: " ").map(String.init)
        return families.filter { family in
            guard category == nil || family.category == category,
                  brand == nil || family.brand == brand else { return false }
            let markings = family.variants.map { variant in
                let code = variant.code.uppercased()
                let number = code.filter(\.isNumber)
                let kind: String
                switch family.category {
                case .iron, .utilityIron: kind = "iron"
                case .fairwayWood: kind = "wood"
                case .hybrid: kind = "hybrid"
                default: kind = family.category.title
                }
                return "\(code) \(variant.displayName) \(number) \(kind)"
            }.joined(separator: " ")
            let text = Self.searchText("\(family.brand) \(family.name) \(family.category.title) \(markings)")
            let compact = text.replacingOccurrences(of: " ", with: "")
            return terms.allSatisfy { text.contains($0) || compact.contains($0) }
        }.sorted {
            let left = "\($0.brand) \($0.name)"
            let right = "\($1.brand) \($1.name)"
            return left.localizedStandardCompare(right) == .orderedAscending
        }
    }

    private static func searchText(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }
}

enum ClubCarryInput {
    static let maximumMeters = 500

    static func text(meters: Int, unit: DistanceUnit) -> String {
        String(unit.scalarValue(fromMeters: meters))
    }

    static func meters(from text: String, unit: DistanceUnit) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int(trimmed), value > 0,
              value <= unit.scalarValue(fromMeters: maximumMeters) else { return nil }
        let meters = unit == .yards ? Int((Double(value) / 1.0936133).rounded()) : value
        return (1...maximumMeters).contains(meters) ? meters : nil
    }
}

extension Club {
    /// Identity deliberately excludes carry and source, so re-adding cannot reset a measured carry.
    var bagIdentity: [String] {
        [name, brand ?? "", family ?? ""].map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        }
    }
}

struct AddClubDraft: Identifiable, Equatable {
    let id: UUID
    let name: String
    let brand: String?
    let family: String?
    let source: ClubSource
    let category: ClubCatalogCategory?
    let unit: DistanceUnit
    var distanceText: String

    var isPutter: Bool { category == .putter }

    var club: Club? {
        // The live-round engine uses a small putter range internally, not a full-swing carry.
        guard let meters = isPutter ? 10 : ClubCarryInput.meters(from: distanceText, unit: unit) else { return nil }
        return Club(id: id, name: name, typicalDistanceMeters: meters, brand: brand, family: family,
                    source: source, category: category)
    }

    static func catalog(family: ClubCatalogFamily, variant: ClubCatalogVariant, unit: DistanceUnit) -> Self {
        .init(id: UUID(), name: variant.displayName, brand: family.brand, family: family.name,
              source: .catalog, category: family.category, unit: unit,
              distanceText: ClubCarryInput.text(meters: ClubCatalog.defaultDistanceMeters(for: variant, category: family.category), unit: unit))
    }

    var identity: [String] {
        Club(name: name, typicalDistanceMeters: 1, brand: brand, family: family).bagIdentity
    }
}

struct AddClubSelection {
    let existingClubs: [Club]
    var drafts: [AddClubDraft] = []
    var hasChanges: Bool { !drafts.isEmpty }

    /// An invalid row blocks the whole batch; no silent partial additions.
    var clubs: [Club]? {
        guard !drafts.isEmpty else { return nil }
        let resolved = drafts.compactMap(\.club)
        return resolved.count == drafts.count ? resolved : nil
    }

    func isOwned(family: ClubCatalogFamily, variant: ClubCatalogVariant) -> Bool {
        let identity = AddClubDraft.catalog(family: family, variant: variant, unit: .meters).identity
        return existingClubs.contains { $0.bagIdentity == identity }
    }

    func isSelected(family: ClubCatalogFamily, variant: ClubCatalogVariant) -> Bool {
        let identity = AddClubDraft.catalog(family: family, variant: variant, unit: .meters).identity
        return drafts.contains { $0.identity == identity }
    }

    mutating func toggle(family: ClubCatalogFamily, variant: ClubCatalogVariant, unit: DistanceUnit) {
        let draft = AddClubDraft.catalog(family: family, variant: variant, unit: unit)
        if let index = drafts.firstIndex(where: { $0.identity == draft.identity }) {
            drafts.remove(at: index)
        } else if !isOwned(family: family, variant: variant) {
            drafts.append(draft)
        }
    }

    @discardableResult
    mutating func addCustom(name: String, brand: String, model: String, category: ClubCatalogCategory, distanceText: String, unit: DistanceUnit) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        let draft = AddClubDraft(id: UUID(), name: name, brand: brand.isEmpty ? nil : brand,
            family: model.isEmpty ? nil : model, source: .custom, category: category, unit: unit, distanceText: distanceText)
        guard draft.club != nil, !drafts.contains(where: { $0.identity == draft.identity }),
              !existingClubs.contains(where: { $0.bagIdentity == draft.identity }) else { return false }
        drafts.append(draft)
        return true
    }
}
