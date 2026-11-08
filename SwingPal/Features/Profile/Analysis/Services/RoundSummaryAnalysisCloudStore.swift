import Foundation
import Supabase

@MainActor
final class RoundSummaryAnalysisCloudStore {
    private struct AnalysisRow: Decodable {
        let round_id: UUID
        let cache_key: String
        let provider: String
        let summary: String
        let what_went_well: [String]
        let needs_work: [String]
        let generated_at: Date
        let updated_at: Date
    }

    private struct AnalysisUpsert: Encodable {
        let round_id: UUID
        let user_id: UUID
        let cache_key: String
        let provider: String
        let summary: String
        let what_went_well: [String]
        let needs_work: [String]
        let generated_at: Date
    }

    func fetchMyAnalyses(limit: Int = 50) async throws -> [RoundSummaryAnalysis] {
        guard let client = SupabaseShared.client(),
              let session = try? await client.auth.session
        else {
            throw SocialGraphError.notConfigured
        }

        let rows: [AnalysisRow] = try await client
            .from("round_analyses")
            .select()
            .eq("user_id", value: session.user.id)
            .order("updated_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows.compactMap { row in
            guard let provider = RoundSummaryAnalysis.Provider(rawValue: row.provider) else { return nil }
            return RoundSummaryAnalysis(
                roundID: row.round_id,
                cacheKey: row.cache_key,
                provider: provider,
                summary: row.summary,
                whatWentWell: row.what_went_well,
                needsWork: row.needs_work,
                generatedAt: row.generated_at,
                updatedAt: row.updated_at
            )
        }
    }

    func upsertMyAnalysis(_ analysis: RoundSummaryAnalysis) async throws {
        guard let client = SupabaseShared.client(),
              let session = try? await client.auth.session
        else {
            throw SocialGraphError.notConfigured
        }

        let row = AnalysisUpsert(
            round_id: analysis.roundID,
            user_id: session.user.id,
            cache_key: analysis.cacheKey,
            provider: analysis.provider.rawValue,
            summary: analysis.summary,
            what_went_well: analysis.whatWentWell,
            needs_work: analysis.needsWork,
            generated_at: analysis.generatedAt
        )

        try await client
            .from("round_analyses")
            .upsert(row, onConflict: "round_id")
            .execute()
    }
}

