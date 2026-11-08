import SwiftUI

struct CourseDiscoveryViewModel {
    let heroEyebrow: String
    let heroTitle: String
    let heroSubtitle: String
    let featuredCourse: SwingPalCourse?
    let featuredDistanceLabel: String
    let featuredDeck: String
    let stageAssetName: String
    let collectionEyebrow: String
    let collectionTitle: String
    let featuredHighlights: [String]
    let stagePresentation: EditorialStagePresentation

    init(courses: [SwingPalCourse], distanceUnit: DistanceUnit) {
        heroEyebrow = "Available courses"
        heroTitle = "Pick your opening tee shot"
        heroSubtitle = "Choose the course that feels right today, lock the tee context, and move into the round without losing momentum."
        featuredCourse = courses.first
        featuredDistanceLabel = Self.makeFeaturedDistanceLabel(for: courses.first, distanceUnit: distanceUnit)
        featuredDeck = "Choose a saved course, then select tees and players."
        stageAssetName = "RoundDiscoveryStage"
        collectionEyebrow = "Saved courses"
        collectionTitle = "Available Courses"
        stagePresentation = .stackedShowcase
        if let featuredCourse = courses.first {
            featuredHighlights = [
                "\(featuredCourse.holeCount) holes",
                "Par \(featuredCourse.par)",
                featuredCourse.quality.readinessLabel
            ]
        } else {
            featuredHighlights = ["No course loaded", "Try again", "Location needed"]
        }
    }

    init(courses: [SwingPalCourse]) {
        self.init(courses: courses, distanceUnit: .meters)
    }

    private static func makeFeaturedDistanceLabel(for course: SwingPalCourse?, distanceUnit: DistanceUnit) -> String {
        guard let course else {
            return "No course loaded"
        }

        return course.proximityLabel(distanceUnit: distanceUnit)
    }
}
