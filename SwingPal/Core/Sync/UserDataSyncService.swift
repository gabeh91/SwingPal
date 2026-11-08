import Foundation
import OSLog
import Supabase

/// Pulls and pushes bag, handicap, and round history via Supabase PostgREST using the
/// shared authenticated client. Local `UserDefaults` stores remain the on-device cache;
/// merges use ``RoundHistorySummary.updatedAt`` and server `updated_at`, plus push
/// timestamps to reduce overwriting offline edits.
@MainActor
final class UserDataSyncService {
    private let log = Logger(subsystem: "com.ghtech.swingpal", category: "UserDataSync")

    private let bagStore: BagStoring
    private let roundHistoryStore: RoundHistoryStoring
    private let handicapStore: HandicapIndexStoring
    private let analysisStore: RoundSummaryAnalysisStoring
    private let analysisCloudStore: RoundSummaryAnalysisCloudStore
    private let defaults: UserDefaults

    private let bagPushMetaKey = "com.ghtech.swingpal.sync.bag-last-pushed-at"
    private let handicapPushMetaKey = "com.ghtech.swingpal.sync.handicap-last-pushed-at"

    init(
        bagStore: BagStoring,
        roundHistoryStore: RoundHistoryStoring,
        handicapStore: HandicapIndexStoring,
        analysisStore: RoundSummaryAnalysisStoring = UserDefaultsRoundSummaryAnalysisStore(),
        defaults: UserDefaults = .standard
    ) {
        self.bagStore = bagStore
        self.roundHistoryStore = roundHistoryStore
        self.handicapStore = handicapStore
        self.analysisStore = analysisStore
        self.analysisCloudStore = RoundSummaryAnalysisCloudStore()
        self.defaults = defaults
    }

    // MARK: - Public API

    /// Fetches remote rows and merges into local stores (same keys as ``AppState``).
    func syncFromCloud(sessionUser: AuthSessionUser?) async {
        guard let sessionUser,
              let userId = UUID(uuidString: sessionUser.id),
              let client = SupabaseShared.client()
        else {
            return
        }

        do {
            try await pullBag(client: client, userId: userId)
            try await pullHandicap(client: client, userId: userId)
            try await pullAndMergeRounds(client: client, userId: userId)
            try await pullAnalyses()
            try await pushBag(client: client, userId: userId)
            try await pushHandicap(client: client, userId: userId)
            let merged = roundHistoryStore.loadRoundHistory()
            for summary in merged {
                try await upsertRound(client: client, userId: userId, summary: summary)
            }
            try await pushAnalyses()
        } catch {
            log.error("syncFromCloud failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func pushRoundAnalysis(_ analysis: RoundSummaryAnalysis, sessionUser: AuthSessionUser?) async {
        guard sessionUser != nil else { return }
        guard SupabaseShared.client() != nil else { return }
        do {
            try await analysisCloudStore.upsertMyAnalysis(analysis)
        } catch {
            log.error("pushRoundAnalysis failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func pushBag(sessionUser: AuthSessionUser?) async {
        guard let sessionUser,
              let userId = UUID(uuidString: sessionUser.id),
              let client = SupabaseShared.client()
        else {
            return
        }
        do {
            try await pushBag(client: client, userId: userId)
        } catch {
            log.error("pushBag failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func pushHandicap(sessionUser: AuthSessionUser?) async {
        guard let sessionUser,
              let userId = UUID(uuidString: sessionUser.id),
              let client = SupabaseShared.client()
        else {
            return
        }
        do {
            try await pushHandicap(client: client, userId: userId)
        } catch {
            log.error("pushHandicap failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func pushRound(_ summary: RoundHistorySummary, sessionUser: AuthSessionUser?) async {
        guard let sessionUser,
              let userId = UUID(uuidString: sessionUser.id),
              let client = SupabaseShared.client()
        else {
            return
        }
        do {
            try await upsertRound(client: client, userId: userId, summary: summary)
        } catch {
            log.error("pushRound failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func deleteRound(id: UUID, sessionUser: AuthSessionUser?) async {
        guard let sessionUser,
              let userId = UUID(uuidString: sessionUser.id),
              let client = SupabaseShared.client()
        else {
            return
        }
        do {
            try await client
                .from("rounds")
                .delete()
                .eq("id", value: id)
                .eq("user_id", value: userId)
                .execute()
        } catch {
            log.error("deleteRound failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Bag

    // MARK: - Round analyses

    private func pullAnalyses() async throws {
        guard SupabaseShared.client() != nil else { return }
        let remote = try await analysisCloudStore.fetchMyAnalyses(limit: 80)

        // Merge strategy: prefer newest `updatedAt` when both exist; otherwise prefer whichever exists.
        let local = analysisStore.load()
        var mergedByRound: [UUID: RoundSummaryAnalysis] = [:]

        for analysis in local {
            mergedByRound[analysis.roundID] = analysis
        }
        for analysis in remote {
            if let existing = mergedByRound[analysis.roundID] {
                let existingUpdated = existing.updatedAt ?? existing.generatedAt
                let incomingUpdated = analysis.updatedAt ?? analysis.generatedAt
                if incomingUpdated >= existingUpdated {
                    mergedByRound[analysis.roundID] = analysis
                }
            } else {
                mergedByRound[analysis.roundID] = analysis
            }
        }

        let merged = mergedByRound.values
            .sorted(by: { ($0.updatedAt ?? $0.generatedAt) > ($1.updatedAt ?? $1.generatedAt) })
        analysisStore.save(Array(merged.prefix(120)))
    }

    private func pushAnalyses() async throws {
        guard SupabaseShared.client() != nil else { return }
        for analysis in analysisStore.load().prefix(80) {
            try await analysisCloudStore.upsertMyAnalysis(analysis)
        }
    }

    private struct BagRow: Decodable {
        let user_id: UUID
        let clubs: AnyJSON
        let updated_at: Date
    }

    private struct BagUpsert: Encodable {
        let user_id: UUID
        let clubs: AnyJSON
        let updated_at: Date
    }

    private func pullBag(client: SupabaseClient, userId: UUID) async throws {
        let rows: [BagRow] = try await client
            .from("bags")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        guard let remote = rows.first else {
            return
        }

        let local = bagStore.loadBag()
        let lastPushed = defaults.object(forKey: bagPushMetaKey) as? Date
        let remoteClubs: [Club] = (try? remote.clubs.decode(as: [Club].self)) ?? []
        let remoteIsEmpty = remoteClubs.isEmpty

        if lastPushed == nil {
            if remoteIsEmpty, !local.clubs.isEmpty {
                let ts = Date()
                try await pushBagRecord(client: client, userId: userId, bag: local, timestamp: ts)
                defaults.set(ts, forKey: bagPushMetaKey)
            } else if !remoteIsEmpty {
                bagStore.saveBag(Bag(clubs: remoteClubs))
                defaults.set(remote.updated_at, forKey: bagPushMetaKey)
            }
            return
        }

        guard let previousPush = lastPushed else {
            return
        }

        guard remote.updated_at > previousPush else {
            return
        }

        if remoteIsEmpty {
            bagStore.saveBag(local)
        } else {
            bagStore.saveBag(Bag(clubs: remoteClubs))
        }
        defaults.set(remote.updated_at, forKey: bagPushMetaKey)
    }

    private func pushBag(client: SupabaseClient, userId: UUID) async throws {
        let bag = bagStore.loadBag()
        let ts = Date()
        try await pushBagRecord(client: client, userId: userId, bag: bag, timestamp: ts)
        defaults.set(ts, forKey: bagPushMetaKey)
    }

    private func pushBagRecord(client: SupabaseClient, userId: UUID, bag: Bag, timestamp: Date) async throws {
        let clubsJson = try AnyJSON(bag.clubs)
        let row = BagUpsert(user_id: userId, clubs: clubsJson, updated_at: timestamp)
        try await client
            .from("bags")
            .upsert(row, onConflict: "user_id")
            .execute()
    }

    // MARK: - Handicap

    private struct HandicapRow: Decodable {
        let user_id: UUID
        let manual_index: Double?
        let updated_at: Date
    }

    private struct HandicapUpsert: Encodable {
        let user_id: UUID
        let manual_index: Double?
        let updated_at: Date
    }

    private func pullHandicap(client: SupabaseClient, userId: UUID) async throws {
        let rows: [HandicapRow] = try await client
            .from("handicaps")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        guard let remote = rows.first else {
            return
        }

        let lastPushed = defaults.object(forKey: handicapPushMetaKey) as? Date
        if lastPushed.map({ remote.updated_at > $0 }) ?? true {
            handicapStore.saveHandicapSnapshot(HandicapIndexSnapshot(manualIndex: remote.manual_index))
            defaults.set(remote.updated_at, forKey: handicapPushMetaKey)
        }
    }

    private func pushHandicap(client: SupabaseClient, userId: UUID) async throws {
        let snap = handicapStore.loadHandicapSnapshot()
        let ts = Date()
        let row = HandicapUpsert(user_id: userId, manual_index: snap.manualIndex, updated_at: ts)
        try await client
            .from("handicaps")
            .upsert(row, onConflict: "user_id")
            .execute()
        defaults.set(ts, forKey: handicapPushMetaKey)
    }

    // MARK: - Rounds

    private struct RoundRow: Decodable {
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
        let is_shared: Bool
        let updated_at: Date
    }

    private struct RoundUpsert: Encodable {
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
        let is_shared: Bool
        let payload: AnyJSON?
        let updated_at: Date
    }

    private func pullAndMergeRounds(client: SupabaseClient, userId: UUID) async throws {
        let remoteRows: [RoundRow] = try await client
            .from("rounds")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        let remoteSummaries = remoteRows.compactMap { row -> RoundHistorySummary? in
            guard let status = RoundHistorySummary.Status(rawValue: row.status) else {
                return nil
            }
            return RoundHistorySummary(
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
        }

        let local = roundHistoryStore.loadRoundHistory()
        let merged = Self.mergeRoundHistories(local: local, remote: remoteSummaries)
        roundHistoryStore.saveRoundHistory(merged)
    }

    private static func mergeRoundHistories(
        local: [RoundHistorySummary],
        remote: [RoundHistorySummary]
    ) -> [RoundHistorySummary] {
        var byId: [UUID: RoundHistorySummary] = [:]
        for round in local {
            byId[round.id] = round
        }
        for round in remote {
            if let existing = byId[round.id] {
                byId[round.id] = round.updatedAt >= existing.updatedAt ? round : existing
            } else {
                byId[round.id] = round
            }
        }
        return byId.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func upsertRound(client: SupabaseClient, userId: UUID, summary: RoundHistorySummary) async throws {
        let row = RoundUpsert(
            id: summary.id,
            user_id: userId,
            course_name: summary.courseName,
            status: summary.status.rawValue,
            hole_number: summary.holeNumber,
            total_hole_count: summary.totalHoleCount,
            player_count: summary.playerCount,
            total_strokes: summary.totalStrokes,
            completed_hole_count: summary.completedHoleCount,
            total_putts: summary.totalPutts,
            total_penalties: summary.totalPenalties,
            is_shared: true,
            payload: nil,
            updated_at: summary.updatedAt
        )
        try await client
            .from("rounds")
            .upsert(row, onConflict: "id")
            .execute()
    }
}
