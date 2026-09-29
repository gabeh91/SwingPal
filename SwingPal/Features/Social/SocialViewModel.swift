import Foundation

struct SocialViewModel {
    let emptyStateTitle: String
    let emptyStateSubtitle: String

    init(posts: [SocialPost]) {
        emptyStateTitle = "No round posts yet"
        emptyStateSubtitle = "Finish a round, add friends, and this space becomes your clean golf catch-up."
    }

}
