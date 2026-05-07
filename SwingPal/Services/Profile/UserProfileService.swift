import Foundation
import Supabase

/// Writable subset of `public.profiles` (full row replace on save from the profile editor).
struct UserPublicProfileUpdate: Encodable {
    var display_name: String?
    var username: String?
    var avatar_url: String?
    var bio: String?
    var show_handicap_to_followers: Bool

    enum CodingKeys: String, CodingKey {
        case display_name
        case username
        case avatar_url
        case bio
        case show_handicap_to_followers
    }
}

/// Loads and updates the signed-in user's row in `public.profiles`.
@MainActor
final class UserProfileService {
    func fetchMyProfile() async throws -> PublicProfile? {
        guard let client = SupabaseShared.client(),
              let session = try? await client.auth.session
        else {
            throw SocialGraphError.notConfigured
        }

        let rows: [PublicProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: session.user.id)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    @discardableResult
    func updateMyProfile(_ update: UserPublicProfileUpdate) async throws -> PublicProfile {
        guard let client = SupabaseShared.client(),
              let session = try? await client.auth.session
        else {
            throw SocialGraphError.notConfigured
        }

        let rows: [PublicProfile] = try await client
            .from("profiles")
            .update(update)
            .eq("id", value: session.user.id)
            .select()
            .execute()
            .value

        guard let profile = rows.first else {
            throw SocialGraphError.profileSaveFailed
        }

        return profile
    }
}
