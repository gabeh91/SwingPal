import Foundation
import Supabase

/// Builds the Social tab feed from `public.rounds` (RLS: own rounds + followed golfers’ shared rounds).
@MainActor
final class SocialFeedService {
    private struct RoundFeedRow: Decodable {
        let id: UUID
        let user_id: UUID
        let course_name: String
        let status: String
        let hole_number: Int
        let total_hole_count: Int
        let player_count: Int
        let total_strokes: Int
        let completed_hole_count: Int
        let total_putts: Int
        let total_penalties: Int
        let updated_at: Date
    }

    func loadFeedPosts(currentUserId: UUID) async throws -> [SocialPost] {
        guard let client = SupabaseShared.client() else {
            throw SocialGraphError.notConfigured
        }

        let rounds: [RoundFeedRow] = try await client
            .from("rounds")
            .select()
            .eq("status", value: "finished")
            .order("updated_at", ascending: false)
            .limit(80)
            .execute()
            .value

        let authorIds = Array(Set(rounds.map(\.user_id)))
        var profilesById: [UUID: PublicProfile] = [:]

        if !authorIds.isEmpty {
            let idsForQuery: [any PostgrestFilterValue] = authorIds.map { $0 as any PostgrestFilterValue }
            let profiles: [PublicProfile] = try await client
                .from("profiles")
                .select()
                .in("id", values: idsForQuery)
                .execute()
                .value
            for profile in profiles {
                profilesById[profile.id] = profile
            }
        }

        return rounds.compactMap { row in
            mapRow(row, profilesById: profilesById, currentUserId: currentUserId)
        }
    }

    private func mapRow(
        _ row: RoundFeedRow,
        profilesById: [UUID: PublicProfile],
        currentUserId: UUID
    ) -> SocialPost? {
        guard let status = RoundHistorySummary.Status(rawValue: row.status) else {
            return nil
        }

        let summary = RoundHistorySummary(
            id: row.id,
            courseName: row.course_name,
            status: status,
            holeNumber: row.hole_number,
            totalHoleCount: row.total_hole_count,
            playerCount: row.player_count,
            totalStrokes: row.total_strokes,
            completedHoleCount: row.completed_hole_count,
            totalPutts: row.total_putts,
            totalPenalties: row.total_penalties,
            updatedAt: row.updated_at
        )

        let ownership: SocialPostOwnership = row.user_id == currentUserId ? .currentUser : .friend
        let playerName = profilesById[row.user_id]?.presentationName ?? "Golfer"
        let scoreSummary = Self.scoreSummaryDisplay(for: summary)

        let subtitle: String
        if ownership == .currentUser {
            subtitle = "Your finished round is synced for your circle."
        } else {
            subtitle = "\(playerName) shared a finished round recap."
        }

        let highlight = "Posted \(scoreSummary) at \(row.course_name)."

        return SocialPost(
            id: row.id,
            playerName: playerName,
            courseName: row.course_name,
            ownership: ownership,
            subtitle: subtitle,
            scoreSummary: scoreSummary,
            kindLabel: "Round recap",
            highlight: highlight,
            metadataPills: [
                ownership == .currentUser ? "Your round" : "Friend round",
                "\(row.total_hole_count) holes",
                "Finished"
            ],
            actionTitle: ownership == .currentUser ? "Open analysis" : "Open scorecard",
            symbolName: "scoreboard",
            destinationKind: ownership == .currentUser ? .analysis : .scorecard,
            roundSummary: summary
        )
    }

    /// Rough score vs par baseline (36 for 9, 72 for 18) for display parity with the mock feed.
    private static func scoreSummaryDisplay(for summary: RoundHistorySummary) -> String {
        let baseline = parBaseline(holes: summary.totalHoleCount)
        let diff = summary.totalStrokes - baseline
        if diff > 0 {
            return "+\(diff)"
        }
        if diff < 0 {
            return "\(diff)"
        }
        return "E"
    }

    private static func parBaseline(holes: Int) -> Int {
        max(1, holes) * 4
    }
}
