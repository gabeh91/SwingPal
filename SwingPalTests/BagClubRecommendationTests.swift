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
            "Your 6i average is 158m and this shot plays like 160m."
        )
    }
}
