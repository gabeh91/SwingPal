import Foundation

enum SocialFeedBuilder {
    static func makeRoundSummary(
        playerName: String,
        courseName: String,
        ownership: SocialPostOwnership,
        scoreSummary: String
    ) -> SocialPost {
        SocialPost(
            playerName: playerName,
            courseName: courseName,
            ownership: ownership,
            subtitle: "Shared a completed round recap with the circle.",
            scoreSummary: scoreSummary,
            kindLabel: "Round recap",
            highlight: "Finished \(scoreSummary) and posted the scorecard.",
            metadataPills: ["Friends first", "Scorecard ready", "Completed round"],
            actionTitle: ownership == .currentUser ? "Open analysis" : "Open scorecard",
            symbolName: "scoreboard",
            destinationKind: ownership == .currentUser ? .analysis : .scorecard,
            roundSummary: makeRoundSummary(
                courseName: courseName,
                totalStrokes: ownership == .currentUser ? 76 : 78,
                totalPutts: ownership == .currentUser ? 31 : 32,
                totalPenalties: ownership == .currentUser ? 1 : 0
            )
        )
    }

    static func makeMilestone(
        playerName: String,
        courseName: String,
        ownership: SocialPostOwnership,
        milestone: String,
        scoreSummary: String
    ) -> SocialPost {
        SocialPost(
            playerName: playerName,
            courseName: courseName,
            ownership: ownership,
            subtitle: "Dropped a personal milestone into the clubhouse feed.",
            scoreSummary: scoreSummary,
            kindLabel: "Milestone",
            highlight: "\(milestone) at \(courseName) and shared the card.",
            metadataPills: ["Personal best", "Milestone day", "Clubhouse update"],
            actionTitle: "View milestone round",
            symbolName: "star.circle",
            destinationKind: ownership == .currentUser ? .analysis : .scorecard,
            roundSummary: makeRoundSummary(
                courseName: courseName,
                totalStrokes: 79,
                totalPutts: 30,
                totalPenalties: 0
            )
        )
    }

    static func makeMatchResult(
        playerName: String,
        courseName: String,
        ownership: SocialPostOwnership,
        result: String,
        scoreSummary: String
    ) -> SocialPost {
        SocialPost(
            playerName: playerName,
            courseName: courseName,
            ownership: ownership,
            subtitle: "Posted a head-to-head result from the weekend match.",
            scoreSummary: scoreSummary,
            kindLabel: "Match result",
            highlight: "\(result) and closed the match early.",
            metadataPills: ["Match play", "Weekend game", "Result posted"],
            actionTitle: "Open match summary",
            symbolName: "flag.checkered",
            destinationKind: ownership == .currentUser ? .analysis : .scorecard,
            roundSummary: makeRoundSummary(
                courseName: courseName,
                totalStrokes: 70,
                totalPutts: 29,
                totalPenalties: 0
            )
        )
    }

    private static func makeRoundSummary(
        courseName: String,
        totalStrokes: Int,
        totalPutts: Int,
        totalPenalties: Int
    ) -> RoundHistorySummary {
        RoundHistorySummary(
            id: UUID(),
            courseName: courseName,
            status: .finished,
            holeNumber: 18,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: totalStrokes,
            completedHoleCount: 18,
            totalPutts: totalPutts,
            totalPenalties: totalPenalties,
            updatedAt: Date()
        )
    }
}
