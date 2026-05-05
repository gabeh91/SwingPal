import XCTest
@testable import SwingPal

final class SwingPalTests: XCTestCase {
    func testDisplayNameMatchesAppBrand() {
        XCTAssertEqual(AppIdentity.displayName, "SwingPal")
    }

    func testCompactPillPresentationCollapsesAndExpandsOverflow() {
        let texts = ["Pick a course", "Clear yardages", "Fast setup", "Set handicap"]

        let collapsed = ShellTokens.PillLayout.compactPresentation(from: texts, isExpanded: false)
        XCTAssertEqual(collapsed.visibleTexts, ["Pick a course", "Clear yardages", "Fast setup"])
        XCTAssertEqual(collapsed.overflowCount, 1)
        XCTAssertFalse(collapsed.showsCollapseControl)

        let expanded = ShellTokens.PillLayout.compactPresentation(from: texts, isExpanded: true)
        XCTAssertEqual(expanded.visibleTexts, texts)
        XCTAssertEqual(expanded.overflowCount, 1)
        XCTAssertTrue(expanded.showsCollapseControl)
    }
}
