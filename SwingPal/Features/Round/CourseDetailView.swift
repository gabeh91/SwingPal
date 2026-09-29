import SwiftUI

struct CourseDetailViewModel {
    let heroEyebrow: String
    let heroTitle: String
    let heroDistanceLabel: String
    let heroSubtitle: String
    let stageAssetName: String
    let briefingEyebrow: String
    let selectionDeck: String
    let teeBadgeText: String
    let expectationHighlights: [String]
    let dataDisclosureTitle: String
    let reportActionTitle: String
    let expectations: [String]
    let stagePresentation: EditorialStagePresentation

    init(course: SwingPalCourse, selectedTee: SwingPalCourse.Tee?, distanceUnit: DistanceUnit) {
        heroEyebrow = "Course Lock"
        heroTitle = course.name
        heroDistanceLabel = course.proximityLabel(distanceUnit: distanceUnit)
        heroSubtitle = "Lock the tee context, take one clean read on the course, and move into players with confidence."
        stageAssetName = "CourseDetailStage"
        briefingEyebrow = "Course briefing"
        selectionDeck = "Pick the tee that matches today’s round and move straight into players."
        stagePresentation = .stackedShowcase
        if let selectedTee {
            switch distanceUnit {
            case .meters:
                let meters = Int((Double(selectedTee.yards) * 0.9144).rounded())
                teeBadgeText = "\(selectedTee.name) • \(meters)m"
            case .yards:
                teeBadgeText = "\(selectedTee.name) • \(selectedTee.yards)yd"
            }
        } else {
            teeBadgeText = "Select a tee"
        }
        expectationHighlights = [
            "Par \(course.par)",
            "\(course.holeCount) holes",
            course.quality.readinessLabel
        ]
        dataDisclosureTitle = "Course data and community"
        reportActionTitle = "Report course data"
        expectations = [
            "Yardages ready for live-round targeting",
            "Bag-based club recommendation available mid-hole",
            "Guest players and attestation in the next step"
        ]
    }

    init(course: SwingPalCourse, selectedTee: SwingPalCourse.Tee?) {
        self.init(course: course, selectedTee: selectedTee, distanceUnit: .meters)
    }
}
