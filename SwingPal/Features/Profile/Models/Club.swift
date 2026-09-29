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
        // A missing resource must not reintroduce unverified equipment. Custom entry still works.
        ClubCatalogDocument(brands: [], families: [])
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
    static let document = ClubCatalogLoader.loadBundled() ?? ClubCatalogDocument.fallback

    private static var activeDocument: ClubCatalogDocument { document }

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
        ClubCarryEstimates.defaultDistanceMeters(for: variant, category: category)
    }
}

/// Starting points only; these are not manufacturer specifications or measured player carries.
enum ClubCarryEstimates {
    static func defaultDistanceMeters(for variant: ClubCatalogVariant, category: ClubCatalogCategory) -> Int {
        // Some manufacturers identify heads by loft instead of a club number. Set wedges
        // retain the iron category, but should receive wedge-sized starting carries.
        let loftLabel = variant.code.split(separator: "-").last.map(String.init) ?? variant.code
        if loftLabel.hasSuffix("°"), let loft = Double(loftLabel.dropLast()), loft.isFinite {
            switch category {
            case .fairwayWood:
                return estimate(loft: loft, anchors: [(13.5, 220), (15, 210), (16.5, 205), (18, 195), (21, 185), (24, 175), (27, 168)])
            case .hybrid:
                return estimate(loft: loft, anchors: [(17, 205), (20, 195), (23, 185), (26, 175), (30, 168), (34, 160)])
            case .utilityIron:
                return estimate(loft: loft, anchors: [(16, 210), (18, 200), (21, 190), (24, 180), (27, 170)])
            case .iron, .wedge:
                return estimate(loft: loft, anchors: [(44, 125), (46, 120), (48, 115), (50, 110), (52, 105), (54, 98), (56, 92), (58, 85), (60, 78), (62, 70), (64, 64)])
            default: break
            }
        }
        switch category {
        case .driver:
            return 230
        case .fairwayWood:
            switch variant.code {
            case "1W": return 230
            case "2W": return 220
            case "3W", "3T": return 210
            case "3HL", "3HF": return 205
            case "Heavenwood": return 190
            case "4W": return 205
            case "5W": return 195
            case "7W": return 185
            case "9W": return 175
            default: return 168
            }
        case .hybrid:
            switch variant.code {
            case "1H", "1U": return 215
            case "2H", "2U": return 205
            case "3H", "3U": return 195
            case "4H", "4U": return 185
            case "5H", "5U": return 175
            case "6H", "6U": return 168
            case "7H", "7U": return 160
            case "8H", "8U": return 153
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
            case "10I", "PW", "W": return 125
            case "11I", "AW", "UW", "U": return 115
            case "GW": return 105
            case "SW": return 95
            case "LW": return 82
            default: return 150
            }
        case .wedge:
            return 95
        case .putter:
            return 10
        }
    }

    private static func estimate(loft: Double, anchors: [(Double, Int)]) -> Int {
        guard let first = anchors.first, let last = anchors.last else { return 150 }
        if loft <= first.0 { return first.1 }
        for (lower, upper) in zip(anchors, anchors.dropFirst()) where loft <= upper.0 {
            let fraction = (loft - lower.0) / (upper.0 - lower.0)
            return Int((Double(lower.1) + fraction * Double(upper.1 - lower.1)).rounded())
        }
        return last.1
    }
}

struct Club: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let typicalDistanceMeters: Int
    let brand: String?
    let family: String?
    let source: ClubSource
    let category: ClubCatalogCategory?

    var isPutter: Bool {
        if let category { return category == .putter }
        return name.localizedCaseInsensitiveContains("putter") ||
            ["blade", "mallet", "mid-mallet", "counterbalanced"].contains(name.lowercased())
    }

    var liveRoundName: String {
        isPutter && !name.localizedCaseInsensitiveContains("putter") ? "\(name) Putter" : name
    }

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
        source: ClubSource = .custom,
        category: ClubCatalogCategory? = nil
    ) {
        self.id = id
        self.name = name
        self.typicalDistanceMeters = typicalDistanceMeters
        self.brand = brand
        self.family = family
        self.source = source
        self.category = category
    }
}
