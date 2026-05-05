import Foundation

enum ClubSource: String, Equatable, Codable {
    case catalog
    case custom
}

enum ClubCatalogCategory: String, Equatable, Codable, CaseIterable {
    case driver
    case fairwayWood
    case hybrid
    case utilityIron
    case iron
    case wedge
    case putter

    var title: String {
        switch self {
        case .driver:
            return "Driver"
        case .fairwayWood:
            return "Fairway Woods"
        case .hybrid:
            return "Hybrids"
        case .utilityIron:
            return "Utility Irons"
        case .iron:
            return "Irons"
        case .wedge:
            return "Wedges"
        case .putter:
            return "Putters"
        }
    }
}

struct ClubCatalogVariant: Identifiable, Equatable, Codable, Hashable {
    let id: String
    let code: String
    let displayName: String

    private enum CodingKeys: String, CodingKey {
        case id
        case code
        case displayName
    }

    init(code: String, displayName: String? = nil) {
        self.id = code
        self.code = code
        self.displayName = displayName ?? code
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let code = try container.decode(String.self, forKey: .code)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? code
        self.code = code
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? code
    }
}

struct ClubCatalogFamily: Identifiable, Equatable, Codable {
    let id: String
    let brand: String
    let name: String
    let category: ClubCatalogCategory
    let variants: [ClubCatalogVariant]

    private enum CodingKeys: String, CodingKey {
        case id
        case brand
        case name
        case category
        case variants
    }

    init(brand: String, name: String, category: ClubCatalogCategory, variants: [ClubCatalogVariant]) {
        self.id = "\(brand)-\(name)-\(category.rawValue)"
        self.brand = brand
        self.name = name
        self.category = category
        self.variants = variants
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let brand = try container.decode(String.self, forKey: .brand)
        let name = try container.decode(String.self, forKey: .name)
        let category = try container.decode(ClubCatalogCategory.self, forKey: .category)
        let variants = try container.decode([ClubCatalogVariant].self, forKey: .variants)

        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(brand)-\(name)-\(category.rawValue)"
        self.brand = brand
        self.name = name
        self.category = category
        self.variants = variants
    }
}

struct ClubCatalogDocument: Equatable, Codable {
    let brands: [String]
    let families: [ClubCatalogFamily]

    func families(for brand: String) -> [ClubCatalogFamily] {
        families.filter { $0.brand == brand }
    }

    static func load(from data: Data?) throws -> ClubCatalogDocument {
        guard let data else {
            return fallback
        }
        return try JSONDecoder().decode(ClubCatalogDocument.self, from: data)
    }

    static var fallback: ClubCatalogDocument {
        ClubCatalogDocument(
            brands: InternalClubCatalog.brands,
            families: InternalClubCatalog.families
        )
    }
}

enum ClubCatalogLoader {
    static func loadBundled(in bundle: Bundle = .main) -> ClubCatalogDocument? {
        guard let url = bundle.url(forResource: "club_catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? ClubCatalogDocument.load(from: data)
    }
}

enum ClubCatalog {
    private static var activeDocument: ClubCatalogDocument {
        ClubCatalogLoader.loadBundled() ?? ClubCatalogDocument.fallback
    }

    static var brands: [String] {
        activeDocument.brands
    }

    static var families: [ClubCatalogFamily] {
        activeDocument.families
    }

    static func families(for brand: String) -> [ClubCatalogFamily] {
        activeDocument.families(for: brand)
    }

    static func defaultDistanceMeters(for variant: ClubCatalogVariant, category: ClubCatalogCategory) -> Int {
        InternalClubCatalog.defaultDistanceMeters(for: variant, category: category)
    }
}

enum InternalClubCatalog {
    static let brands: [String] = [
        "Titleist",
        "TaylorMade",
        "PING",
        "Callaway",
        "Cobra",
        "Mizuno",
        "Takomo",
        "PXG",
        "Wilson",
        "Cleveland",
        "Srixon",
        "Tour Edge",
        "Scotty Cameron",
        "LAB Golf",
        "Honma",
        "Miura",
        "Odyssey"
    ]

    static let families: [ClubCatalogFamily] = [
        .init(brand: "Titleist", name: "GT Metals", category: .fairwayWood, variants: woodVariants()),
        .init(brand: "Titleist", name: "T-Series", category: .iron, variants: ironVariants()),
        .init(brand: "Titleist", name: "Vokey SM10", category: .wedge, variants: wedgeVariants()),
        .init(brand: "TaylorMade", name: "Qi35", category: .driver, variants: driverVariants()),
        .init(brand: "TaylorMade", name: "Qi35 Fairway", category: .fairwayWood, variants: woodVariants()),
        .init(brand: "TaylorMade", name: "P790", category: .iron, variants: ironVariants()),
        .init(brand: "PING", name: "G440 Max", category: .driver, variants: driverVariants()),
        .init(brand: "PING", name: "G440 Fairway", category: .fairwayWood, variants: woodVariants()),
        .init(brand: "PING", name: "Blueprint", category: .iron, variants: ironVariants()),
        .init(brand: "Callaway", name: "Elyte", category: .driver, variants: driverVariants()),
        .init(brand: "Callaway", name: "Apex", category: .iron, variants: ironVariants()),
        .init(brand: "Callaway", name: "Opus", category: .wedge, variants: wedgeVariants()),
        .init(brand: "Cobra", name: "DS-Adapt", category: .driver, variants: driverVariants()),
        .init(brand: "Cobra", name: "King Tec", category: .iron, variants: ironVariants()),
        .init(brand: "Mizuno", name: "JPX 925", category: .iron, variants: ironVariants()),
        .init(brand: "Mizuno", name: "ST Fairway", category: .fairwayWood, variants: woodVariants()),
        .init(brand: "Takomo", name: "101", category: .iron, variants: ironVariants()),
        .init(brand: "PXG", name: "0311 Black Ops", category: .driver, variants: driverVariants()),
        .init(brand: "PXG", name: "0317", category: .hybrid, variants: hybridVariants()),
        .init(brand: "Wilson", name: "Dynapower", category: .driver, variants: driverVariants()),
        .init(brand: "Wilson", name: "Staff Model", category: .iron, variants: ironVariants()),
        .init(brand: "Cleveland", name: "RTX", category: .wedge, variants: wedgeVariants()),
        .init(brand: "Srixon", name: "ZX Mk II", category: .iron, variants: ironVariants()),
        .init(brand: "Srixon", name: "ZX Fairway", category: .fairwayWood, variants: woodVariants()),
        .init(brand: "Tour Edge", name: "Exotics", category: .driver, variants: driverVariants()),
        .init(brand: "Tour Edge", name: "Exotics Fairway", category: .fairwayWood, variants: woodVariants()),
        .init(brand: "Scotty Cameron", name: "Phantom", category: .putter, variants: putterVariants()),
        .init(brand: "LAB Golf", name: "Mezz", category: .putter, variants: putterVariants()),
        .init(brand: "Honma", name: "TW767", category: .iron, variants: ironVariants()),
        .init(brand: "Miura", name: "TC-202", category: .iron, variants: ironVariants()),
        .init(brand: "Odyssey", name: "Ai-ONE", category: .putter, variants: putterVariants())
    ]

    static func families(for brand: String) -> [ClubCatalogFamily] {
        families.filter { $0.brand == brand }
    }

    static func defaultDistanceMeters(for variant: ClubCatalogVariant, category: ClubCatalogCategory) -> Int {
        switch category {
        case .driver:
            return 230
        case .fairwayWood:
            switch variant.code {
            case "1W": return 230
            case "2W": return 220
            case "3W": return 210
            case "4W": return 205
            case "5W": return 195
            case "7W": return 185
            case "9W": return 175
            default: return 168
            }
        case .hybrid:
            switch variant.code {
            case "1H": return 215
            case "2H": return 205
            case "3H": return 195
            case "4H": return 185
            case "5H": return 175
            case "6H": return 168
            default: return 160
            }
        case .utilityIron:
            switch variant.code {
            case "1U": return 210
            case "2U": return 200
            case "3U": return 190
            case "4U": return 180
            case "5U": return 170
            case "6U": return 160
            default: return 150
            }
        case .iron:
            switch variant.code {
            case "1I": return 215
            case "2I": return 205
            case "3I": return 195
            case "4I": return 185
            case "5I": return 175
            case "6I": return 165
            case "7I": return 155
            case "8I": return 145
            case "9I": return 135
            case "PW": return 125
            case "AW": return 115
            case "GW": return 105
            case "SW": return 95
            case "LW": return 82
            default: return 150
            }
        case .wedge:
            switch variant.code {
            case "46°": return 120
            case "48°": return 115
            case "50°": return 110
            case "52°": return 105
            case "54°": return 98
            case "56°": return 92
            case "58°": return 85
            case "60°": return 78
            case "62°": return 70
            default: return 95
            }
        case .putter:
            return 10
        }
    }

    private static func driverVariants() -> [ClubCatalogVariant] {
        [ClubCatalogVariant(code: "1W", displayName: "Driver")]
    }

    private static func woodVariants() -> [ClubCatalogVariant] {
        ["1W", "2W", "3W", "4W", "5W", "7W", "9W", "11W"].map { ClubCatalogVariant(code: $0) }
    }

    private static func hybridVariants() -> [ClubCatalogVariant] {
        ["1H", "2H", "3H", "4H", "5H", "6H", "7H"].map { ClubCatalogVariant(code: $0) }
    }

    private static func ironVariants() -> [ClubCatalogVariant] {
        ["1I", "2I", "3I", "4I", "5I", "6I", "7I", "8I", "9I", "PW", "AW", "GW", "SW", "LW"]
            .map { ClubCatalogVariant(code: $0) }
    }

    private static func wedgeVariants() -> [ClubCatalogVariant] {
        ["46°", "48°", "50°", "52°", "54°", "56°", "58°", "60°", "62°"]
            .map { ClubCatalogVariant(code: $0) }
    }

    private static func putterVariants() -> [ClubCatalogVariant] {
        [
            ClubCatalogVariant(code: "Blade"),
            ClubCatalogVariant(code: "Mid-Mallet"),
            ClubCatalogVariant(code: "Mallet"),
            ClubCatalogVariant(code: "Counterbalanced")
        ]
    }
}

struct Club: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let typicalDistanceMeters: Int
    let brand: String?
    let family: String?
    let source: ClubSource

    var subtitle: String? {
        switch (brand, family) {
        case let (brand?, family?):
            return "\(brand) • \(family)"
        case let (brand?, nil):
            return brand
        case let (nil, family?):
            return family
        case (nil, nil):
            return nil
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        typicalDistanceMeters: Int,
        brand: String? = nil,
        family: String? = nil,
        source: ClubSource = .custom
    ) {
        self.id = id
        self.name = name
        self.typicalDistanceMeters = typicalDistanceMeters
        self.brand = brand
        self.family = family
        self.source = source
    }
}
