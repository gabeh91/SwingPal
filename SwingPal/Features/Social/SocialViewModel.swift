import Foundation

struct SocialPulseStat: Equatable {
    let title: String
    let value: String
    let note: String
}

struct SocialViewModel {
    let mastheadEditionLabel: String
    let heroEyebrow: String
    let heroTitle: String
    let heroSubtitle: String
    let heroDeck: String
    let heroEditionLabel: String
    let heroHighlights: [String]
    let heroPills: [String]
    let spotlightEyebrow: String
    let spotlightDeck: String
    let spotlightActionTitle: String
    let spotlightAssetName: String
    let spotlightPresentation: EditorialStagePresentation
    let spotlightPost: SocialPost?
    let feedEyebrow: String
    let feedTitle: String
    let emptyStateTitle: String
    let emptyStateSubtitle: String
    let pulseStats: [SocialPulseStat]

    init(posts: [SocialPost]) {
        let golferCount = Self.uniqueGolfers(in: posts).count
        let courseCount = Self.uniqueCourses(in: posts).count

        mastheadEditionLabel = "Clubhouse 01"
        heroEyebrow = "SOCIAL CLUB"
        heroTitle = "Your golf circle"
        heroEditionLabel = "Edition 01"
        if posts.isEmpty {
            heroSubtitle = "No friend rounds yet. Add your golf circle and new posts will land here."
            heroDeck = "This space becomes your clean social catch-up once friends start posting rounds."
            heroHighlights = ["0 updates", "0 golfers", "0 courses"]
            heroPills = ["Friends first", "Build your circle", "Round recaps"]
            spotlightActionTitle = "Invite friends"
            pulseStats = [
                .init(title: "Updates", value: "0", note: "Fresh posts"),
                .init(title: "Golfers", value: "0", note: "Active friends"),
                .init(title: "Courses", value: "0", note: "Played recently"),
                .init(title: "Spotlight", value: "--", note: "Latest card")
            ]
        } else {
            heroSubtitle = "\(posts.count) update\(posts.count == 1 ? "" : "s") from \(golferCount) golfer\(golferCount == 1 ? "" : "s") across \(courseCount) course\(courseCount == 1 ? "" : "s")."
            heroDeck = "See who played, what stood out, and open clean round recaps without digging."
            heroHighlights = [
                "\(posts.count) update\(posts.count == 1 ? "" : "s")",
                "\(golferCount) golfer\(golferCount == 1 ? "" : "s")",
                "\(courseCount) course\(courseCount == 1 ? "" : "s")"
            ]
            heroPills = ["Friends first", "\(posts.count) update\(posts.count == 1 ? "" : "s")", "Round recaps"]
            spotlightActionTitle = posts.first?.actionTitle ?? "Open update"
            pulseStats = [
                .init(title: "Updates", value: "\(posts.count)", note: "Fresh posts"),
                .init(title: "Golfers", value: "\(golferCount)", note: "Active friends"),
                .init(title: "Courses", value: "\(courseCount)", note: "Played recently"),
                .init(title: "Spotlight", value: posts.first?.scoreSummary ?? "--", note: "Latest card")
            ]
        }
        spotlightEyebrow = "Circle Spotlight"
        spotlightDeck = "A cleaner look at the latest friend round worth opening right now."
        spotlightAssetName = "SocialSpotlightStage"
        spotlightPresentation = .editorialSpread
        spotlightPost = posts.first
        feedEyebrow = "Feed"
        feedTitle = "Recent from friends"
        emptyStateTitle = "No round posts yet"
        emptyStateSubtitle = "Finish a round, add friends, and this space becomes your clean golf catch-up."
    }

    private static func uniqueGolfers(in posts: [SocialPost]) -> Set<String> {
        Set(posts.map(\.playerName))
    }

    private static func uniqueCourses(in posts: [SocialPost]) -> Set<String> {
        Set(posts.map(\.courseName))
    }
}
