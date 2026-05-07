import Foundation

/// Row from `public.profiles` used for search and follow prompts.
struct PublicProfile: Identifiable, Equatable, Hashable, Decodable {
    let id: UUID
    let username: String?
    let displayName: String?
    let avatarURL: String?
    let bio: String?
    let showHandicapToFollowers: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case bio
        case showHandicapToFollowers = "show_handicap_to_followers"
    }

    var presentationName: String {
        let trimmedUser = username?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplay = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedUser, !trimmedUser.isEmpty {
            return "@\(trimmedUser)"
        }
        if let trimmedDisplay, !trimmedDisplay.isEmpty {
            return trimmedDisplay
        }
        return "Golfer"
    }
}
