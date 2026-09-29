import Foundation

/// Guests and signed-in golfers use the same public catalog. Credentials never enter this request.
@MainActor
final class ClubCatalogStore {
    static let shared = ClubCatalogStore(
        endpoint: SupabaseConfig.loadFromEnvironment()?.url
            .appendingPathComponent("storage/v1/object/public/club-catalog/v1/catalog.json"),
        cacheURL: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("SwingPal/club-catalog-v1.json"),
        fallback: ClubCatalog.document
    )

    private struct Cache: Codable {
        let endpoint: URL
        let fetchedAt: Date
        let data: Data
    }
    private enum CatalogError: Error { case invalidDocument, invalidResponse }
    private(set) var document: ClubCatalogDocument
    private let endpoint: URL?
    private let cacheURL: URL?
    private let now: () -> Date
    private let fetch: (URL) async throws -> (Data, URLResponse)
    private var fetchedAt: Date?
    private var retryAfter: Date?
    private var refresh: Task<Void, Never>?

    init(endpoint: URL?, cacheURL: URL?, fallback: ClubCatalogDocument,
         now: @escaping () -> Date = Date.init,
         fetch: @escaping (URL) async throws -> (Data, URLResponse) = ClubCatalogStore.download) {
        self.endpoint = endpoint
        self.cacheURL = cacheURL
        self.now = now
        self.fetch = fetch
        document = fallback
        if let cacheURL, let bytes = try? Data(contentsOf: cacheURL), bytes.count <= 3_000_000,
           let cache = try? JSONDecoder().decode(Cache.self, from: bytes), cache.endpoint == endpoint,
           let cached = try? Self.validate(cache.data) {
            document = cached
            // A clock correction must not prevent future refreshes.
            fetchedAt = min(cache.fetchedAt, now())
        }
    }

    func refreshIfNeeded() async {
        if let refresh { await refresh.value; return }
        guard let endpoint, endpoint.scheme == "https",
              fetchedAt.map({ now().timeIntervalSince($0) >= 86_400 }) ?? true,
              retryAfter.map({ now() >= $0 }) ?? true else { return }
        let task = Task { @MainActor in
            do {
                let (data, response) = try await fetch(endpoint)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw CatalogError.invalidResponse }
                let validated = try Self.validate(data)
                let date = now()
                // An unwritable cache must not prevent this session using validated data.
                if let cacheURL {
                    try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if let bytes = try? JSONEncoder().encode(Cache(endpoint: endpoint, fetchedAt: date, data: data)) {
                        try? bytes.write(to: cacheURL, options: .atomic)
                    }
                }
                document = validated
                fetchedAt = date
                retryAfter = nil
            } catch {
                retryAfter = now().addingTimeInterval(300)
                // Keep the last good cache or bundled seed; custom entry also remains available.
            }
        }
        refresh = task
        await task.value
        refresh = nil
    }

    nonisolated private static func download(_ url: URL) async throws -> (Data, URLResponse) {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        let (stream, response) = try await URLSession.shared.bytes(for: request)
        guard response.expectedContentLength <= 2_000_000 else { throw CatalogError.invalidResponse }
        var data = Data()
        for try await byte in stream {
            guard data.count < 2_000_000 else { throw CatalogError.invalidResponse }
            data.append(byte)
        }
        return (data, response)
    }

    /// Validate externally supplied data before it can become a cache or a picker snapshot.
    nonisolated static func validate(_ data: Data) throws -> ClubCatalogDocument {
        guard data.count <= 2_000_000,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["schemaVersion"] as? NSNumber,
              CFGetTypeID(version) != CFBooleanGetTypeID(), version.doubleValue == 1 else {
            throw CatalogError.invalidDocument
        }
        let document = try ClubCatalogDocument.load(from: data)
        func valid(_ value: String) -> Bool {
            !value.isEmpty && value.count <= 160 && value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
                value.rangeOfCharacter(from: .controlCharacters) == nil
        }
        func key(_ value: String) -> String { value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
        guard !document.families.isEmpty, document.families.count <= 10_000,
              document.brands.allSatisfy(valid), Set(document.brands.map(key)).count == document.brands.count,
              Set(document.brands) == Set(document.families.map(\.brand)) else { throw CatalogError.invalidDocument }
        var familyIDs = Set<String>(), families = Set<[String]>(), clubs = Set<[String]>()
        for family in document.families {
            guard [family.id, family.brand, family.name].allSatisfy(valid), familyIDs.insert(family.id).inserted,
                  families.insert([key(family.brand), key(family.name), family.category.rawValue]).inserted,
                  !family.variants.isEmpty, family.variants.count <= 100 else { throw CatalogError.invalidDocument }
            var ids = Set<String>(), codes = Set<String>()
            for variant in family.variants {
                guard [variant.id, variant.code, variant.displayName].allSatisfy(valid),
                      ids.insert(variant.id).inserted, codes.insert(key(variant.code)).inserted,
                      clubs.insert([key(family.brand), key(family.name), key(variant.displayName)]).inserted else {
                    throw CatalogError.invalidDocument
                }
            }
        }
        return document
    }
}
