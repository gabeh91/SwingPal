import Foundation

protocol RoundSummaryAnalysisGenerating {
    func generateAnalysis(for summary: RoundHistorySummary) async throws -> RoundSummaryAnalysis
}

struct DeterministicRoundSummaryAnalysisGenerator: RoundSummaryAnalysisGenerating {
    func generateAnalysis(for summary: RoundHistorySummary) async throws -> RoundSummaryAnalysis {
        RoundSummaryAnalysis(
            roundID: summary.id,
            cacheKey: RoundSummaryAnalysis.CacheKey(summary: summary).rawValue,
            provider: .deterministic,
            summary: ProfileViewModel.legacySummary(for: summary),
            whatWentWell: ProfileViewModel.legacyStrengths(for: summary),
            needsWork: ProfileViewModel.legacyImprovements(for: summary),
            generatedAt: Date(),
            updatedAt: nil
        )
    }
}

final class RoundSummaryAnalysisService {
    enum Error: Swift.Error {
        case noAvailableGenerator
    }

    private let store: RoundSummaryAnalysisStoring
    private let generators: [RoundSummaryAnalysisGenerating]

    init(
        store: RoundSummaryAnalysisStoring = UserDefaultsRoundSummaryAnalysisStore(),
        generators: [RoundSummaryAnalysisGenerating] = [
            FoundationModelsRoundSummaryAnalyzer(),
            DeterministicRoundSummaryAnalysisGenerator()
        ]
    ) {
        self.store = store
        self.generators = generators
    }

    func cachedAnalysis(for summary: RoundHistorySummary) -> RoundSummaryAnalysis? {
        let key = RoundSummaryAnalysis.CacheKey(summary: summary).rawValue
        return store.load().first(where: { $0.roundID == summary.id && $0.cacheKey == key })
    }

    func analysis(for summary: RoundHistorySummary) async throws -> RoundSummaryAnalysis {
        if let cached = cachedAnalysis(for: summary) {
            return cached
        }

        for generator in generators {
            if let generated = try? await generator.generateAnalysis(for: summary) {
                persist(generated)
                return generated
            }
        }

        throw Error.noAvailableGenerator
    }

    private func persist(_ analysis: RoundSummaryAnalysis) {
        var analyses = store.load().filter { $0.roundID != analysis.roundID }
        analyses.insert(analysis, at: 0)
        store.save(analyses)

        // Best-effort cloud sync (no-op if Supabase/auth is unavailable).
        Task {
            guard SupabaseShared.client() != nil else { return }
            do {
                try await RoundSummaryAnalysisCloudStore().upsertMyAnalysis(analysis)
            } catch {
                // Keep local analysis even if push fails.
            }
        }
    }
}
