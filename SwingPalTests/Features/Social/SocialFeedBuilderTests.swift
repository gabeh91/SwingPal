import XCTest
@testable import SwingPal

final class SocialFeedBuilderTests: XCTestCase {
    func testBuildRoundSummaryProducesStructuredClubhousePost() {
        let post = SocialFeedBuilder.makeRoundSummary(
            playerName: "Gabe",
            courseName: "Royal Melbourne",
            ownership: .currentUser,
            scoreSummary: "+6"
        )

        XCTAssertEqual(post.playerName, "Gabe")
        XCTAssertEqual(post.courseName, "Royal Melbourne")
        XCTAssertEqual(post.title, "Gabe played Royal Melbourne")
        XCTAssertEqual(post.scoreSummary, "+6")
        XCTAssertEqual(post.subtitle, "Shared a completed round recap with the circle.")
        XCTAssertEqual(post.kindLabel, "Round recap")
        XCTAssertEqual(post.highlight, "Finished +6 and posted the scorecard.")
        XCTAssertEqual(post.metadataPills, ["Friends first", "Scorecard ready", "Completed round"])
        XCTAssertEqual(post.ownership, .currentUser)
        XCTAssertEqual(post.destinationKind, .analysis)
        XCTAssertEqual(post.actionTitle, "Open analysis")
        XCTAssertEqual(post.symbolName, "scoreboard")
        XCTAssertEqual(post.roundSummary.courseName, "Royal Melbourne")
        XCTAssertEqual(post.roundSummary.status, .finished)
    }

    func testBuildMilestoneProducesDistinctClubhouseTone() {
        let post = SocialFeedBuilder.makeMilestone(
            playerName: "Alex",
            courseName: "Kingston Heath",
            ownership: .friend,
            milestone: "Broke 80",
            scoreSummary: "+7"
        )

        XCTAssertEqual(post.playerName, "Alex")
        XCTAssertEqual(post.courseName, "Kingston Heath")
        XCTAssertEqual(post.scoreSummary, "+7")
        XCTAssertEqual(post.kindLabel, "Milestone")
        XCTAssertEqual(post.subtitle, "Dropped a personal milestone into the clubhouse feed.")
        XCTAssertEqual(post.highlight, "Broke 80 at Kingston Heath and shared the card.")
        XCTAssertEqual(post.metadataPills, ["Personal best", "Milestone day", "Clubhouse update"])
        XCTAssertEqual(post.ownership, .friend)
        XCTAssertEqual(post.destinationKind, .scorecard)
        XCTAssertEqual(post.actionTitle, "View milestone round")
        XCTAssertEqual(post.symbolName, "star.circle")
    }

    func testBuildMatchResultProducesCompetitiveFeedEntry() {
        let post = SocialFeedBuilder.makeMatchResult(
            playerName: "Mia",
            courseName: "The National",
            ownership: .friend,
            result: "Won 3&2",
            scoreSummary: "3&2"
        )

        XCTAssertEqual(post.playerName, "Mia")
        XCTAssertEqual(post.courseName, "The National")
        XCTAssertEqual(post.scoreSummary, "3&2")
        XCTAssertEqual(post.kindLabel, "Match result")
        XCTAssertEqual(post.subtitle, "Posted a head-to-head result from the weekend match.")
        XCTAssertEqual(post.highlight, "Won 3&2 and closed the match early.")
        XCTAssertEqual(post.metadataPills, ["Match play", "Weekend game", "Result posted"])
        XCTAssertEqual(post.destinationKind, .scorecard)
        XCTAssertEqual(post.actionTitle, "Open match summary")
        XCTAssertEqual(post.symbolName, "flag.checkered")
    }
}
