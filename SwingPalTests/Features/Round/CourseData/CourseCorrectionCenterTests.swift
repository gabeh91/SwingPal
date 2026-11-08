import XCTest
@testable import SwingPal

final class CourseCorrectionCenterTests: XCTestCase {
    func testSubmittingDraftStoresCourseScopedReportAsSubmitted() {
        let store = StubCourseCorrectionStore()
        let center = CourseCorrectionCenter(store: store)
        let course = SwingPalCourse.test(name: "Royal Melbourne", distanceKilometers: 3.2)
        let draft = CourseCorrectionDraft(
            courseID: course.id,
            courseName: course.name,
            kind: .greenShape,
            holeNumber: 7,
            detail: "Back-left green edge is shorter than shown.",
            evidences: [.init(kind: .note, value: "Observed on today's round")]
        )

        center.submit(draft)

        XCTAssertEqual(center.corrections(for: course.id).count, 1)
        XCTAssertEqual(center.corrections(for: course.id).first?.status, .submitted)
        XCTAssertEqual(center.corrections(for: course.id).first?.summaryTitle, "Hole 7 green update")
        XCTAssertEqual(store.savedCorrections.count, 1)
        XCTAssertEqual(store.savedCorrections.first?.status, .submitted)
    }

    func testCorrectionsAreReturnedForSpecificCourseOnly() {
        let center = CourseCorrectionCenter(store: StubCourseCorrectionStore())
        let firstCourse = SwingPalCourse.test(name: "Royal Melbourne", distanceKilometers: 3.2)
        let secondCourse = SwingPalCourse.test(name: "Kingston Heath", distanceKilometers: 7.4)

        center.submit(
            CourseCorrectionDraft(
                courseID: firstCourse.id,
                courseName: firstCourse.name,
                kind: .hazardPlacement,
                holeNumber: 3,
                detail: "Creek crossing is missing from the layup view.",
                evidences: [.init(kind: .note, value: "Marked while walking the hole")]
            )
        )
        center.submit(
            CourseCorrectionDraft(
                courseID: secondCourse.id,
                courseName: secondCourse.name,
                kind: .teeMetadata,
                detail: "Member tees are listed 15 yards long.",
                evidences: [.init(kind: .note, value: "Compared against scorecard")]
            )
        )

        XCTAssertEqual(center.corrections(for: firstCourse.id).count, 1)
        XCTAssertEqual(center.corrections(for: secondCourse.id).count, 1)
        XCTAssertEqual(center.corrections(for: firstCourse.id).first?.courseName, "Royal Melbourne")
    }

    func testCenterRestoresPersistedCorrectionsOnInit() {
        let course = SwingPalCourse.test(name: "Royal Melbourne", distanceKilometers: 3.2)
        let persisted = CourseCorrectionDraft(
            courseID: course.id,
            courseName: course.name,
            kind: .teeMetadata,
            detail: "Member tee yardage should be reduced by 12 yards.",
            evidences: [.init(kind: .note, value: "Compared against clubhouse card")],
            status: .underReview
        )
        let store = StubCourseCorrectionStore(loadedCorrections: [persisted])

        let center = CourseCorrectionCenter(store: store)

        XCTAssertEqual(center.corrections(for: course.id).count, 1)
        XCTAssertEqual(center.corrections(for: course.id).first?.status, .underReview)
    }

    func testModerationSummaryReflectsPersistedStatuses() {
        let course = SwingPalCourse.test(name: "Royal Melbourne", distanceKilometers: 3.2)
        let store = StubCourseCorrectionStore(loadedCorrections: [
            CourseCorrectionDraft(
                courseID: course.id,
                courseName: course.name,
                kind: .routing,
                detail: "Hole routing line drifts left near the bunker.",
                evidences: [.init(kind: .note, value: "Walked the line")],
                status: .underReview
            ),
            CourseCorrectionDraft(
                courseID: course.id,
                courseName: course.name,
                kind: .bunkerShape,
                holeNumber: 2,
                detail: "Front bunker is deeper than shown.",
                evidences: [.init(kind: .note, value: "Noted during round")],
                status: .submitted
            )
        ])

        let center = CourseCorrectionCenter(store: store)
        let summary = center.moderationSummary(for: course.id)

        XCTAssertEqual(summary.headline, "1 under review")
        XCTAssertEqual(summary.detail, "1 newly submitted • 1 in moderation")
    }

    func testRecentActivityReturnsNewestItemsForCourseOnly() {
        let course = SwingPalCourse.test(name: "Royal Melbourne", distanceKilometers: 3.2)
        let otherCourse = SwingPalCourse.test(name: "Kingston Heath", distanceKilometers: 7.4)
        let store = StubCourseCorrectionStore(loadedCorrections: [
            CourseCorrectionDraft(
                courseID: otherCourse.id,
                courseName: otherCourse.name,
                kind: .generalNote,
                detail: "This should be filtered out.",
                evidences: [.init(kind: .note, value: "Other course")],
                status: .submitted
            ),
            CourseCorrectionDraft(
                courseID: course.id,
                courseName: course.name,
                kind: .routing,
                detail: "Fairway guide should hold the safer right-center line.",
                evidences: [.init(kind: .note, value: "Walked the hole")],
                status: .applied
            ),
            CourseCorrectionDraft(
                courseID: course.id,
                courseName: course.name,
                kind: .teeMetadata,
                detail: "Member tee card is 8 yards short.",
                evidences: [.init(kind: .note, value: "Checked against scorecard")],
                status: .underReview
            ),
            CourseCorrectionDraft(
                courseID: course.id,
                courseName: course.name,
                kind: .greenShape,
                holeNumber: 7,
                detail: "Back-left shoulder is flatter than shown.",
                evidences: [.init(kind: .note, value: "Observed during round")],
                status: .submitted
            )
        ])

        let center = CourseCorrectionCenter(store: store)
        let activity = center.recentActivity(for: course.id)

        XCTAssertEqual(activity.count, 3)
        XCTAssertEqual(activity[0].title, "Royal Melbourne routing update")
        XCTAssertEqual(activity[0].statusLabel, "Applied locally")
        XCTAssertEqual(activity[1].statusLabel, "In moderation")
        XCTAssertEqual(activity[2].statusLabel, "Pending sync")
    }
}

private final class StubCourseCorrectionStore: CourseCorrectionStoring {
    let loadedCorrections: [CourseCorrectionDraft]
    private(set) var savedCorrections: [CourseCorrectionDraft] = []

    init(loadedCorrections: [CourseCorrectionDraft] = []) {
        self.loadedCorrections = loadedCorrections
    }

    func loadCorrections() -> [CourseCorrectionDraft] {
        loadedCorrections
    }

    func saveCorrections(_ corrections: [CourseCorrectionDraft]) {
        savedCorrections = corrections
    }
}
