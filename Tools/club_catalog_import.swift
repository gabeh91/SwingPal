import Foundation

/// Offline compiler for reviewed manufacturer facts. No inferred club ranges or network fallback.
enum ImportCategory: String, Codable { case driver, fairwayWood, hybrid, utilityIron, iron, wedge, putter }
struct CatalogSource: Codable {
    let id: String
    let url: String
    let checkedAt: String
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
    let sourceIDs: [String]
}
struct SourceDocument: Codable {
    let schemaVersion: Int
    let sources: [CatalogSource]
    let families: [ImportFamily]
}
struct ImportDocument: Codable {
    let schemaVersion: Int
    let brands: [String]
    let sources: [CatalogSource]
    let families: [ImportFamily]
}
struct ImportError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct ClubCatalogImportTool {
    static func run() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--help"] {
            print("swift Tools/club_catalog_import.swift --source Tools/club_catalog_sources.json --output SwingPal/Resources/club_catalog.json [--check]")
            return
        }
        var options: [String: String] = [:]
        var check = false
        var index = 0
        while index < arguments.count {
            let flag = arguments[index]
            if flag == "--check", !check { check = true; index += 1; continue }
            guard ["--source", "--output"].contains(flag), options[flag] == nil,
                  index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") else {
                throw ImportError(message: "Unknown, repeated or incomplete argument: \(flag)")
            }
            options[flag] = arguments[index + 1]
            index += 2
        }
        guard let sourcePath = options["--source"], let outputPath = options["--output"] else {
            throw ImportError(message: "Both --source and --output are required. Use --help for usage.")
        }
        let sourceURL = URL(fileURLWithPath: sourcePath).standardizedFileURL
        let outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL
        guard sourceURL.resolvingSymlinksInPath() != outputURL.resolvingSymlinksInPath() else {
            throw ImportError(message: "Source and output must be different files.")
        }
        let source = try JSONDecoder().decode(SourceDocument.self, from: Data(contentsOf: sourceURL))
        try validate(source)
        let families = source.families.sorted {
            [$0.brand, $0.name, $0.category.rawValue].lexicographicallyPrecedes([$1.brand, $1.name, $1.category.rawValue])
        }
        let document = ImportDocument(schemaVersion: source.schemaVersion,
                                      brands: Array(Set(families.map(\.brand))).sorted(),
                                      sources: source.sources.sorted { $0.id < $1.id }, families: families)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(document)
        data.append(0x0A)
        if check {
            guard (try? Data(contentsOf: outputURL)) == data else {
                throw ImportError(message: "Catalog is stale or missing. Regenerate without --check.")
            }
            print("Catalog is up to date (\(families.count) models, \(document.brands.count) brands).")
        } else {
            try data.write(to: outputURL, options: .atomic)
            print("Wrote \(families.count) models across \(document.brands.count) brands to \(outputPath)")
        }
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
    private static func requireText(_ value: String, _ label: String) throws {
        guard !value.isEmpty, value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              value.rangeOfCharacter(from: .controlCharacters) == nil else {
            throw ImportError(message: "\(label) must be nonempty text without surrounding whitespace or control characters.")
        }
    }
    private static func validate(_ document: SourceDocument) throws {
        guard document.schemaVersion == 1, !document.families.isEmpty, !document.sources.isEmpty else {
            throw ImportError(message: "Expected schemaVersion 1 and nonempty families and sources.")
        }
        let date = DateFormatter()
        date.locale = Locale(identifier: "en_US_POSIX")
        date.timeZone = TimeZone(secondsFromGMT: 0)
        date.dateFormat = "yyyy-MM-dd"
        date.isLenient = false
        var sourceIDs = Set<String>()
        for source in document.sources {
            try requireText(source.id, "Source ID")
            guard sourceIDs.insert(source.id).inserted,
                  let url = URLComponents(string: source.url), url.scheme == "https",
                  let host = url.host, host.contains("."), url.user == nil, url.password == nil,
                  let parsed = date.date(from: source.checkedAt), date.string(from: parsed) == source.checkedAt else {
                throw ImportError(message: "Invalid/duplicate source \(source.id): use an HTTPS URL and real YYYY-MM-DD date.")
            }
        }
        var keys = Set<[String]>()
        var savedClubIdentities = Set<[String]>()
        var brandSpellings: [String: String] = [:]
        for family in document.families {
            try requireText(family.brand, "Brand")
            try requireText(family.name, "Model")
            let brandKey = normalized(family.brand)
            if let spelling = brandSpellings[brandKey], spelling != family.brand {
                throw ImportError(message: "Inconsistent brand spelling: \(family.brand) / \(spelling)")
            }
            brandSpellings[brandKey] = family.brand
            guard keys.insert([brandKey, normalized(family.name), family.category.rawValue]).inserted else {
                throw ImportError(message: "Duplicate model: \(family.brand) \(family.name)")
            }
            guard !family.sourceIDs.isEmpty, Set(family.sourceIDs).count == family.sourceIDs.count,
                  family.sourceIDs.allSatisfy(sourceIDs.contains) else {
                throw ImportError(message: "Missing or unknown source for \(family.brand) \(family.name)")
            }
            guard !family.variants.isEmpty else { throw ImportError(message: "No variants for \(family.name)") }
            var codes = Set<String>()
            var names = Set<String>()
            for variant in family.variants {
                try requireText(variant.code, "Variant code")
                try requireText(variant.displayName, "Variant name")
                guard codes.insert(normalized(variant.code)).inserted,
                      names.insert(normalized(variant.displayName)).inserted,
                      savedClubIdentities.insert([brandKey, normalized(family.name), normalized(variant.displayName)]).inserted else {
                    throw ImportError(message: "Duplicate variant in \(family.name): \(variant.code)")
                }
            }
        }
    }
}

do { try ClubCatalogImportTool.run() }
catch {
    FileHandle.standardError.write(Data("Catalog import failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
