import XCTest
@testable import SwingPal

final class GatedActionResolverTests: XCTestCase {
    func testGuestSavingRoundRequiresAuth() {
        let resolver = GatedActionResolver(
            authState: .guest,
            entitlements: .free
        )

        XCTAssertEqual(resolver.requirement(for: .saveRound), .signIn)
    }

    func testFreeUserOpeningWatchCompanionRequiresPremium() {
        let resolver = GatedActionResolver(
            authState: .authenticated,
            entitlements: .free
        )

        XCTAssertEqual(resolver.requirement(for: .openWatchCompanion), .premium)
    }
}
