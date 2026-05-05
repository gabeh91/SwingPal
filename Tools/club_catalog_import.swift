import Foundation

enum ImportCategory: String, Codable {
    case driver
    case fairwayWood
    case hybrid
    case utilityIron
    case iron
    case wedge
    case putter
}

struct ImportVariant: Codable {
    let code: String
    let displayName: String
}

struct ImportFamily: Codable {
    let brand: String
    let name: String
    let category: ImportCategory
    let variants: [ImportVariant]
}

struct ImportDocument: Codable {
    let brands: [String]
    let families: [ImportFamily]
}

struct BrandSeed {
    let brand: String
    let name: String
    let category: ImportCategory
}

struct ClubCatalogImportTool {
    private static let browserUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    static func run() throws {
        let outputURL = try outputURLFromArguments()
        let document = try buildDocument()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: outputURL, options: .atomic)
        FileHandle.standardOutput.write(Data("wrote \(document.families.count) families to \(outputURL.path)\n".utf8))
    }

    private static func outputURLFromArguments() throws -> URL {
        let arguments = CommandLine.arguments
        guard let outputIndex = arguments.firstIndex(of: "--output"), arguments.indices.contains(outputIndex + 1) else {
            throw NSError(domain: "ClubCatalogImportTool", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing --output /path/to/club_catalog.json"])
        }
        return URL(fileURLWithPath: arguments[outputIndex + 1])
    }

    private static func buildDocument() throws -> ImportDocument {
        var families = manualFamilies()
        families.append(contentsOf: scrapePingFamilies())

        let dedupedFamilies = Dictionary(grouping: families, by: familyKey)
            .values
            .compactMap { $0.first }
            .sorted {
                if $0.brand == $1.brand {
                    return $0.name < $1.name
                }
                return $0.brand < $1.brand
            }

        let brands = Array(Set(dedupedFamilies.map(\.brand))).sorted()
        return ImportDocument(brands: brands, families: dedupedFamilies)
    }

    private static func familyKey(_ family: ImportFamily) -> String {
        "\(family.brand)|\(family.name)|\(family.category.rawValue)"
    }

    private static func manualFamilies() -> [ImportFamily] {
        manualSeeds.map { seed in
            ImportFamily(
                brand: seed.brand,
                name: seed.name,
                category: seed.category,
                variants: variants(for: seed.category)
            )
        }
    }

    private static func scrapePingFamilies() -> [ImportFamily] {
        guard let url = URL(string: "https://ping.com/en-us/clubs/search"),
              let html = try? fetchHTML(from: url) else {
            return []
        }

        let candidates: [(needle: String, brand: String, name: String, category: ImportCategory)] = [
            ("G440 DRIVER", "PING", "G440 Drivers", .driver),
            ("G440 FAIRWAY/HYBRID SOLE WEIGHT", "PING", "G440 Fairway Woods", .fairwayWood),
            ("G440 HYBRID", "PING", "G440 Hybrids", .hybrid),
            ("BLUEPRINT", "PING", "Blueprint Irons", .iron),
            ("G740", "PING", "G740 Irons", .iron),
            ("I530", "PING", "i530 Irons", .iron),
            ("IDI", "PING", "iDi Utility Irons", .utilityIron),
            ("BUNKR", "PING", "BunkR Wedges", .wedge),
            ("SCOTTSDALE TEC", "PING", "Scottsdale TEC Putters", .putter),
            ("PLD", "PING", "PLD Putters", .putter)
        ]

        let uppercasedHTML = html.uppercased()
        return candidates.compactMap { candidate in
            guard uppercasedHTML.contains(candidate.needle) else { return nil }
            return ImportFamily(
                brand: candidate.brand,
                name: candidate.name,
                category: candidate.category,
                variants: variants(for: candidate.category)
            )
        }
    }

    private static func fetchHTML(from url: URL) throws -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<String, Error>!

        var request = URLRequest(url: url)
        request.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, error in
            defer { semaphore.signal() }
            if let error {
                result = .failure(error)
                return
            }
            guard let data, let html = String(data: data, encoding: .utf8), !html.isEmpty else {
                result = .failure(NSError(domain: "ClubCatalogImportTool", code: 2, userInfo: [NSLocalizedDescriptionKey: "Empty response for \(url.absoluteString)"]))
                return
            }
            result = .success(html)
        }.resume()

        semaphore.wait()
        return try result.get()
    }

    private static func variants(for category: ImportCategory) -> [ImportVariant] {
        switch category {
        case .driver:
            return [ImportVariant(code: "1W", displayName: "Driver")]
        case .fairwayWood:
            return ["1W", "2W", "3W", "4W", "5W", "7W", "9W", "11W"].map { ImportVariant(code: $0, displayName: $0) }
        case .hybrid:
            return ["1H", "2H", "3H", "4H", "5H", "6H", "7H"].map { ImportVariant(code: $0, displayName: $0) }
        case .utilityIron:
            return ["1U", "2U", "3U", "4U", "5U", "6U"].map { ImportVariant(code: $0, displayName: $0) }
        case .iron:
            return ["1I", "2I", "3I", "4I", "5I", "6I", "7I", "8I", "9I", "PW", "AW", "GW", "SW", "LW"]
                .map { ImportVariant(code: $0, displayName: $0) }
        case .wedge:
            return ["46°", "48°", "50°", "52°", "54°", "56°", "58°", "60°", "62°"]
                .map { ImportVariant(code: $0, displayName: $0) }
        case .putter:
            return ["Blade", "Mid-Mallet", "Mallet", "Counterbalanced"].map { ImportVariant(code: $0, displayName: $0) }
        }
    }

    private static let manualSeeds: [BrandSeed] = [
        .init(brand: "Titleist", name: "GT Drivers", category: .driver),
        .init(brand: "Titleist", name: "GT Fairway Woods", category: .fairwayWood),
        .init(brand: "Titleist", name: "GT Hybrids", category: .hybrid),
        .init(brand: "Titleist", name: "T-Series Irons", category: .iron),
        .init(brand: "Titleist", name: "Vokey SM11 Wedges", category: .wedge),
        .init(brand: "Scotty Cameron", name: "Phantom Putters", category: .putter),
        .init(brand: "Scotty Cameron", name: "Studio Style Putters", category: .putter),

        .init(brand: "TaylorMade", name: "Qi4D Drivers", category: .driver),
        .init(brand: "TaylorMade", name: "Qi4D Fairway Woods", category: .fairwayWood),
        .init(brand: "TaylorMade", name: "Qi4D Rescue", category: .hybrid),
        .init(brand: "TaylorMade", name: "Qi Max Irons", category: .iron),
        .init(brand: "TaylorMade", name: "MG5 Wedges", category: .wedge),
        .init(brand: "TaylorMade", name: "Spider ZT Putters", category: .putter),

        .init(brand: "Callaway", name: "Quantum Drivers", category: .driver),
        .init(brand: "Callaway", name: "Quantum Fairway Woods", category: .fairwayWood),
        .init(brand: "Callaway", name: "Quantum Hybrids", category: .hybrid),
        .init(brand: "Callaway", name: "Quantum Irons", category: .iron),
        .init(brand: "Callaway", name: "Opus Wedges", category: .wedge),
        .init(brand: "Odyssey", name: "Ai-ONE Putters", category: .putter),

        .init(brand: "Cobra", name: "DS-ADAPT Drivers", category: .driver),
        .init(brand: "Cobra", name: "DS-ADAPT Fairway Woods", category: .fairwayWood),
        .init(brand: "Cobra", name: "DS-ADAPT Hybrids", category: .hybrid),
        .init(brand: "Cobra", name: "DS-ADAPT Irons", category: .iron),

        .init(brand: "Mizuno", name: "ST Drivers", category: .driver),
        .init(brand: "Mizuno", name: "ST Fairway Woods", category: .fairwayWood),
        .init(brand: "Mizuno", name: "JPX 925 Irons", category: .iron),
        .init(brand: "Mizuno", name: "Pro T-1 Wedges", category: .wedge),

        .init(brand: "Takomo", name: "101 Irons", category: .iron),
        .init(brand: "Takomo", name: "101T Irons", category: .iron),
        .init(brand: "Takomo", name: "301 Irons", category: .iron),

        .init(brand: "PXG", name: "Black Ops Drivers", category: .driver),
        .init(brand: "PXG", name: "Black Ops Fairway Woods", category: .fairwayWood),
        .init(brand: "PXG", name: "Black Ops Hybrids", category: .hybrid),
        .init(brand: "PXG", name: "0311 GEN8 Irons", category: .iron),
        .init(brand: "PXG", name: "Sugar Daddy III Wedges", category: .wedge),
        .init(brand: "PXG", name: "Hot Rod ZT Putters", category: .putter),

        .init(brand: "Wilson", name: "DYNAPWR Max+ Drivers", category: .driver),
        .init(brand: "Wilson", name: "DYNAPWR Fairway Woods", category: .fairwayWood),
        .init(brand: "Wilson", name: "DYNAPWR Hybrids", category: .hybrid),
        .init(brand: "Wilson", name: "DYNAPWR Forged Irons", category: .iron),
        .init(brand: "Wilson", name: "Staff Model CB Irons", category: .iron),
        .init(brand: "Wilson", name: "Staff Model XB Irons", category: .iron),

        .init(brand: "Cleveland", name: "RTZ Wedges", category: .wedge),
        .init(brand: "Cleveland", name: "CBX 4 ZipCore Wedges", category: .wedge),

        .init(brand: "Srixon", name: "ZXi Drivers", category: .driver),
        .init(brand: "Srixon", name: "ZXi Fairway Woods", category: .fairwayWood),
        .init(brand: "Srixon", name: "ZXi Hybrids", category: .hybrid),
        .init(brand: "Srixon", name: "ZXi Irons", category: .iron),

        .init(brand: "Tour Edge", name: "Exotics Max Drivers", category: .driver),
        .init(brand: "Tour Edge", name: "Exotics Max Fairway Woods", category: .fairwayWood),
        .init(brand: "Tour Edge", name: "Exotics Max Hybrids", category: .hybrid),
        .init(brand: "Tour Edge", name: "Exotics Max Irons", category: .iron),
        .init(brand: "Tour Edge", name: "725 Series Irons", category: .iron),
        .init(brand: "Tour Edge", name: "Hot Launch Max Wedges", category: .wedge),

        .init(brand: "LAB Golf", name: "LINK.2 Putters", category: .putter),
        .init(brand: "LAB Golf", name: "DF3 Putters", category: .putter),
        .init(brand: "LAB Golf", name: "MEZZ.1 Putters", category: .putter),
        .init(brand: "LAB Golf", name: "OZ.1 Putters", category: .putter),

        .init(brand: "Honma", name: "TW767 Drivers", category: .driver),
        .init(brand: "Honma", name: "TW767 Fairway Woods", category: .fairwayWood),
        .init(brand: "Honma", name: "TW767 Hybrids", category: .hybrid),
        .init(brand: "Honma", name: "TW777 PCB MAX Irons", category: .iron),

        .init(brand: "Miura", name: "TC-202 Irons", category: .iron),
        .init(brand: "Miura", name: "CB-302 Irons", category: .iron),
        .init(brand: "Miura", name: "MC-502 Irons", category: .iron),
        .init(brand: "Miura", name: "IC-602 Irons", category: .iron),
        .init(brand: "Miura", name: "KM-700 Irons", category: .iron),
        .init(brand: "Miura", name: "Forged Wedge Series", category: .wedge)
    ]
}

try ClubCatalogImportTool.run()
