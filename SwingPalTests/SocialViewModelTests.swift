import XCTest
@testable import SwingPal

final class SocialViewModelTests: XCTestCase {
    func testModelBuildsHomeStyleCircleSummaryForActiveFeed() {
        let posts = [
            SocialPost(
                playerName: "Gabe",
                courseName: "Royal Melbourne",
                ownership: .currentUser,
                subtitle: "Shared a completed round recap with the circle.",
                scoreSummary: "+2",
                kindLabel: "Round recap",
                highlight: "Finished +2 and posted the scorecard.",
                metadataPills: ["Friends first", "Scorecard ready", "Completed round"],
                actionTitle: "Open analysis",
                symbolName: "scoreboard",
                destinationKind: .analysis,
                roundSummary: .init(
                    id: UUID(),
                    courseName: "Royal Melbourne",
                    status: .finished,
                    holeNumber: 18,
                    totalHoleCount: 18,
                    playerCount: 1,
                    totalStrokes: 74,
                    completedHoleCount: 18,
                    totalPutts: 29,
                    totalPenalties: 0,
                    updatedAt: Date(timeIntervalSince1970: 100)
                )
            ),
            SocialPost(
                playerName: "Ben",
                courseName: "Kingston Heath",
                ownership: .friend,
                subtitle: "Turned a steady even-par round into a clubhouse update.",
                scoreSummary: "E",
                kindLabel: "Milestone round",
                highlight: "Even par with a strong finish on the closing holes.",
                metadataPills: ["Even par", "Back-nine push", "Completed round"],
                actionTitle: "View milestone round",
                symbolName: "star.circle",
                destinationKind: .scorecard,
                roundSummary: .init(
                    id: UUID(),
                    courseName: "Kingston Heath",
                    status: .finished,
                    holeNumber: 18,
                    totalHoleCount: 18,
                    playerCount: 1,
                    totalStrokes: 72,
                    completedHoleCount: 18,
                    totalPutts: 30,
                    totalPenalties: 0,
                    updatedAt: Date(timeIntervalSince1970: 110)
                )
            )
        ]

        let model = SocialViewModel(posts: posts)

        XCTAssertEqual(model.mastheadEditionLabel, "Clubhouse 01")
        XCTAssertEqual(model.heroEyebrow, "SOCIAL CLUB")
        XCTAssertEqual(model.heroTitle, "Your golf circle")
        XCTAssertEqual(model.heroSubtitle, "2 updates from 2 golfers across 2 courses.")
        XCTAssertEqual(model.heroDeck, "See who played, what stood out, and open clean round recaps without digging.")
        XCTAssertEqual(model.heroHighlights, ["2 updates", "2 golfers", "2 courses"])
        XCTAssertEqual(model.spotlightPost, posts.first)
        XCTAssertEqual(model.spotlightActionTitle, "Open analysis")
        XCTAssertEqual(model.feedTitle, "Recent from friends")
        XCTAssertEqual(model.spotlightEyebrow, "Circle Spotlight")
        XCTAssertEqual(model.spotlightDeck, "A cleaner look at the latest friend round worth opening right now.")
        XCTAssertEqual(model.feedEyebrow, "Feed")
        XCTAssertEqual(
            model.pulseStats,
            [
                .init(title: "Updates", value: "2", note: "Fresh posts"),
                .init(title: "Golfers", value: "2", note: "Active friends"),
                .init(title: "Courses", value: "2", note: "Played recently"),
                .init(title: "Spotlight", value: "+2", note: "Latest card")
            ]
        )
    }

    func testModelProvidesHomeStyleEmptyStateWhenThereAreNoPosts() {
        let model = SocialViewModel(posts: [])

        XCTAssertEqual(model.mastheadEditionLabel, "Clubhouse 01")
        XCTAssertEqual(model.heroTitle, "Your golf circle")
        XCTAssertEqual(model.heroSubtitle, "No friend rounds yet. Add your golf circle and new posts will land here.")
        XCTAssertEqual(model.heroDeck, "This space becomes your clean social catch-up once friends start posting rounds.")
        XCTAssertNil(model.spotlightPost)
        XCTAssertEqual(model.spotlightActionTitle, "Invite friends")
        XCTAssertEqual(model.emptyStateTitle, "No round posts yet")
        XCTAssertEqual(model.feedEyebrow, "Feed")
        XCTAssertEqual(
            model.pulseStats,
            [
                .init(title: "Updates", value: "0", note: "Fresh posts"),
                .init(title: "Golfers", value: "0", note: "Active friends"),
                .init(title: "Courses", value: "0", note: "Played recently"),
                .init(title: "Spotlight", value: "--", note: "Latest card")
            ]
        )
    }

    func testModelCountsGolfersAndCoursesFromStructuredPostFields() {
        let posts = [
            SocialPost(
                playerName: "Gabe",
                courseName: "Royal Melbourne",
                ownership: .currentUser,
                subtitle: "Shared a completed round recap with the circle.",
                scoreSummary: "+1",
                kindLabel: "Round recap",
                highlight: "Posted a clean card after a tidy finish.",
                metadataPills: ["Completed round"],
                actionTitle: "Open analysis",
                symbolName: "scoreboard",
                destinationKind: .analysis,
                roundSummary: .init(
                    id: UUID(),
                    courseName: "Royal Melbourne",
                    status: .finished,
                    holeNumber: 18,
                    totalHoleCount: 18,
                    playerCount: 1,
                    totalStrokes: 73,
                    completedHoleCount: 18,
                    totalPutts: 28,
                    totalPenalties: 0,
                    updatedAt: Date(timeIntervalSince1970: 100)
                )
            ),
            SocialPost(
                playerName: "Gabe",
                courseName: "Kingston Heath",
                ownership: .currentUser,
                subtitle: "Shared another completed round recap with the circle.",
                scoreSummary: "+4",
                kindLabel: "Round recap",
                highlight: "A second post from a different course.",
                metadataPills: ["Completed round"],
                actionTitle: "Open analysis",
                symbolName: "scoreboard",
                destinationKind: .analysis,
                roundSummary: .init(
                    id: UUID(),
                    courseName: "Kingston Heath",
                    status: .finished,
                    holeNumber: 18,
                    totalHoleCount: 18,
                    playerCount: 1,
                    totalStrokes: 77,
                    completedHoleCount: 18,
                    totalPutts: 31,
                    totalPenalties: 1,
                    updatedAt: Date(timeIntervalSince1970: 110)
                )
            )
        ]

        let model = SocialViewModel(posts: posts)

        XCTAssertEqual(model.heroSubtitle, "2 updates from 1 golfer across 2 courses.")
        XCTAssertEqual(
            model.pulseStats,
            [
                .init(title: "Updates", value: "2", note: "Fresh posts"),
                .init(title: "Golfers", value: "1", note: "Active friends"),
                .init(title: "Courses", value: "2", note: "Played recently"),
                .init(title: "Spotlight", value: "+1", note: "Latest card")
            ]
        )
    }
}
