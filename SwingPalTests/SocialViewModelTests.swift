import XCTest
@testable import SwingPal

final class SocialViewModelTests: XCTestCase {

    func testModelProvidesHomeStyleEmptyStateWhenThereAreNoPosts() {
        let model = SocialViewModel(posts: [])

        XCTAssertEqual(model.emptyStateTitle, "No round posts yet")
    }

}
