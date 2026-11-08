import XCTest
@testable import SwingPal

final class BagClubRecommendationTests: XCTestCase {
    func testRecommendationExplainsSuggestionUsingBagDistance() {
        let bag = Bag(clubs: [
            .init(name: "7i", typicalDistanceMeters: 145),
            .init(name: "6i", typicalDistanceMeters: 158)
        ])

        let recommendation = BagClubRecommendation.make(
            bag: bag,
            playsLikeDistanceMeters: 160
        )

        XCTAssertEqual(recommendation.clubName, "6i")
        XCTAssertEqual(
            recommendation.reason,
            "Your bag lists 6i at 158m; this shot plays like 160m."
        )
    }

    func testEmptyBagDoesNotInventAnUnknownClubWithZeroCarry() {
        let recommendation = BagClubRecommendation.make(bag: Bag(clubs: []), playsLikeDistanceMeters: 160)
        XCTAssertEqual(recommendation.clubName, "No recommendation")
        XCTAssertEqual(recommendation.reason, "Add a club with a typical distance to get a suggestion.")
    }

    func testInvalidCarryDistancesAreExcludedFromRecommendations() {
        let bag = Bag(clubs: [.init(name: "Unknown carry", typicalDistanceMeters: 0), .init(name: "7i", typicalDistanceMeters: 145)])
        XCTAssertEqual(BagClubRecommendation.make(bag: bag, playsLikeDistanceMeters: 30).clubName, "7i")
    }

    func testMissingTargetDoesNotProduceAClubSuggestion() {
        let recommendation = BagClubRecommendation.make(bag: .starter, playsLikeDistanceMeters: 0)
        XCTAssertEqual(recommendation.clubName, "No recommendation")
        XCTAssertEqual(recommendation.reason, "A target distance is needed before suggesting a club.")
    }
}
