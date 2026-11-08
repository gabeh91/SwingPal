import Foundation
import Supabase

/// Search and follow actions against Supabase `profiles` / `follows`.
@MainActor
final class SocialGraphService {
    struct FollowInsert: Encodable {
        let follower_id: UUID
        let followee_id: UUID
    }

    struct SearchRPCParams: Encodable {
        let search_query: String
        let result_limit: Int
    }

    struct FollowEdge: Decodable {
        let followee_id: UUID
    }

    func searchProfiles(query: String) async throws -> [PublicProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            return []
        }

        guard let client = SupabaseShared.client() else {
            throw SocialGraphError.notConfigured
        }

        let rows: [PublicProfile] = try await client
            .rpc("search_profiles", params: SearchRPCParams(search_query: trimmed, result_limit: 24))
            .execute()
            .value

        return rows
    }

    func fetchProfile(userId: UUID) async throws -> PublicProfile? {
        guard let client = SupabaseShared.client(),
              (try? await client.auth.session) != nil
        else {
            throw SocialGraphError.notConfigured
        }

        let rows: [PublicProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func followingIds() async throws -> Set<UUID> {
        guard let client = SupabaseShared.client(),
              let session = try? await client.auth.session
        else {
            throw SocialGraphError.notConfigured
        }

        let followerId = session.user.id
        let edges: [FollowEdge] = try await client
            .from("follows")
            .select("followee_id")
            .eq("follower_id", value: followerId)
            .execute()
            .value

        return Set(edges.map(\.followee_id))
    }

    func follow(followeeId: UUID) async throws {
        guard let client = SupabaseShared.client(),
              let session = try? await client.auth.session
        else {
            throw SocialGraphError.notConfigured
        }

        let followerId = session.user.id
        guard followerId != followeeId else {
            throw SocialGraphError.cannotFollowSelf
        }

        let row = FollowInsert(follower_id: followerId, followee_id: followeeId)
        try await client
            .from("follows")
            .insert(row)
            .execute()
    }
}

enum SocialGraphError: LocalizedError {
    case notConfigured
    case cannotFollowSelf
    case missingInvite
    case profileSaveFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Sign in to use social features."
        case .cannotFollowSelf:
            return "You can’t follow yourself."
        case .missingInvite:
            return "No follow request is active."
        case .profileSaveFailed:
            return "Couldn’t save your profile. Try again."
        }
    }
}
