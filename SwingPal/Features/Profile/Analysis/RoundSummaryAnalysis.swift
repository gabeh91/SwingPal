import Foundation

struct RoundSummaryAnalysis: Equatable, Codable, Identifiable {
    enum Provider: String, Equatable, Codable {
        case foundationModels
        case kimi
        case deterministic
    }

    struct CacheKey: Equatable, Codable {
        let rawValue: String

        init(summary: RoundHistorySummary) {
            rawValue = [
                summary.id.uuidString,
                summary.status.rawValue,
                "\(summary.holeNumber)",
                "\(summary.totalHoleCount)",
                "\(summary.playerCount)",
                "\(summary.totalStrokes)",
                "\(summary.completedHoleCount)",
                "\(summary.totalPutts)",
                "\(summary.totalPenalties)",
                "\(summary.updatedAt.timeIntervalSince1970)"
            ].joined(separator: "|")
        }
    }

    let roundID: UUID
    let cacheKey: String
    let provider: Provider
    let summary: String
    let whatWentWell: [String]
    let needsWork: [String]
    let generatedAt: Date

    var id: String { "\(roundID.uuidString)|\(cacheKey)" }
}

protocol RoundSummaryAnalysisStoring {
    func load() -> [RoundSummaryAnalysis]
    func save(_ analyses: [RoundSummaryAnalysis])
}

struct UserDefaultsRoundSummaryAnalysisStore: RoundSummaryAnalysisStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "com.ghtech.swingpal.round-summary-analysis"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [RoundSummaryAnalysis] {
        guard let data = defaults.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([RoundSummaryAnalysis].self, from: data)) ?? []
    }

    func save(_ analyses: [RoundSummaryAnalysis]) {
        guard let data = try? JSONEncoder().encode(analyses) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}
