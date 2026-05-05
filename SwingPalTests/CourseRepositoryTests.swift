import XCTest
@testable import SwingPal

final class CourseRepositoryTests: XCTestCase {
    func testSeededRepositoryReturnsCoursesSortedByDistance() {
        let repository = SeededCourseRepository()

        let courses = repository.nearbyCourses()

        XCTAssertEqual(courses.map(\.name), [
            "Medway Golf Club",
            "Royal Melbourne"
        ])
    }

    func testSeededRepositoryProvidesNormalizedCourseDetailsForRoyalMelbourne() throws {
        let repository = SeededCourseRepository()

        let course = try XCTUnwrap(repository.nearbyCourses().first(where: { $0.name == "Royal Melbourne" }))

        // Royal Melbourne West (the bundled course): real OSM-derived geometry
        // for all 18 holes plus our 4W/11W par-5 overrides sums to par 72.
        XCTAssertEqual(course.par, 72)
        XCTAssertEqual(course.holeCount, 18)
        XCTAssertEqual(course.tees.map(\.name), ["Championship", "Member", "Forward"])
        XCTAssertEqual(course.holes.count, 18)
        XCTAssertFalse(course.holes[0].features.isEmpty)
    }

    func testSeededRepositoryProvidesNormalizedCourseDetailsForMedway() throws {
        let repository = SeededCourseRepository()

        let course = try XCTUnwrap(repository.nearbyCourses().first(where: { $0.name == "Medway Golf Club" }))

        XCTAssertEqual(course.par, 70)
        XCTAssertEqual(course.holeCount, 18)
        XCTAssertEqual(course.tees.map(\.name), ["Championship", "Member", "Forward"])
        XCTAssertEqual(course.holes.count, 18)
        XCTAssertFalse(course.holes[0].features.isEmpty)
    }

    func testMedwayHasExactlyOneGreenPerHoleAfterCleanup() throws {
        // Earlier the bundled course JSON shipped a stray duplicate
        // green polygon on H10/H13 (and on Royal Melbourne H1/H2/H5/
        // H15). The duplicate sat near the tee box, which threw off
        // the green-extrema math — Front collapsed to `0 m` while
        // Pin/Back remained correct. After the
        // `clean_course_green_polygons.py` pass each hole must have
        // exactly one green feature with a sane vertex count.
        let repository = SeededCourseRepository()
        let medway = try XCTUnwrap(repository.nearbyCourses().first(where: { $0.name == "Medway Golf Club" }))
        for hole in medway.holes {
            let greens = hole.features.filter { $0.kind == .green }
            XCTAssertEqual(greens.count, 1, "Medway H\(hole.number) must have exactly 1 green feature, found \(greens.count)")
            if let only = greens.first {
                XCTAssertGreaterThanOrEqual(only.coordinates.count, 4, "Medway H\(hole.number) green polygon must have ≥4 vertices to be usable")
            }
        }
    }

    func testRoyalMelbourneHasExactlyOneGreenPerHoleAfterCleanup() throws {
        let repository = SeededCourseRepository()
        let course = try XCTUnwrap(repository.nearbyCourses().first(where: { $0.name == "Royal Melbourne" }))
        for hole in course.holes {
            let greens = hole.features.filter { $0.kind == .green }
            XCTAssertEqual(greens.count, 1, "Royal Melbourne H\(hole.number) must have exactly 1 green feature, found \(greens.count)")
            if let only = greens.first {
                XCTAssertGreaterThanOrEqual(only.coordinates.count, 4, "Royal Melbourne H\(hole.number) green polygon must have ≥4 vertices to be usable")
            }
        }
    }

    func testMedwayHole13InspectionFrontPinBackBracketTightlyAroundPin() throws {
        // Real-bug guard: H13 reported Front=0m / Pin=225m / Back=236m
        // in the simulator while inspecting the hole. Front=0 implied
        // a wildly negative offset, which only happens when the green
        // polygon contains stray vertices far from the actual surface.
        // After cleaning the JSON we expect Front to land within ~30m
        // of Pin and the front/pin/back trio to be strictly ordered.
        try assertInspectionFrontPinBackBracketsArePhysicallyPlausible(
            courseName: "Medway Golf Club",
            holeNumber: 13
        )
    }

    func testMedwayHole10InspectionFrontPinBackBracketTightlyAroundPin() throws {
        try assertInspectionFrontPinBackBracketsArePhysicallyPlausible(
            courseName: "Medway Golf Club",
            holeNumber: 10
        )
    }

    func testRoyalMelbourneHole1InspectionFrontPinBackBracketTightlyAroundPin() throws {
        try assertInspectionFrontPinBackBracketsArePhysicallyPlausible(
            courseName: "Royal Melbourne",
            holeNumber: 1
        )
    }

    private func assertInspectionFrontPinBackBracketsArePhysicallyPlausible(
        courseName: String,
        holeNumber: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let repository = SeededCourseRepository()
        let course = try XCTUnwrap(
            repository.nearbyCourses().first(where: { $0.name == courseName }),
            "Course \(courseName) must be present in the bundled repository",
            file: file,
            line: line
        )

        // Start the round on hole 1 (live), then inspect the target
        // hole — the same flow the user takes by tapping the chevrons
        // in the top bar.
        let firstHole = try XCTUnwrap(course.holes.first, file: file, line: line)
        let state = LiveRoundState(
            hole: HoleSession(number: firstHole.number, par: firstHole.par),
            courseName: course.name,
            courseCoordinate: .init(
                latitude: course.coordinate.latitude,
                longitude: course.coordinate.longitude
            ),
            courseHoles: course.holes,
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        guard let inspectionIndex = course.holes.firstIndex(where: { $0.number == holeNumber }) else {
            XCTFail("Course \(courseName) is missing hole \(holeNumber)", file: file, line: line)
            return
        }
        state.inspectHole(at: inspectionIndex)

        let front = state.displayedFrontDistanceMeters
        let pin = state.displayedPinDistanceMeters
        let back = state.displayedBackDistanceMeters

        XCTAssertGreaterThan(front, 0, "\(courseName) H\(holeNumber): Front must not collapse to 0", file: file, line: line)
        XCTAssertGreaterThan(pin, 0, "\(courseName) H\(holeNumber): Pin must not collapse to 0", file: file, line: line)
        XCTAssertLessThanOrEqual(front, pin, "\(courseName) H\(holeNumber): Front must be ≤ Pin", file: file, line: line)
        XCTAssertGreaterThanOrEqual(back, pin, "\(courseName) H\(holeNumber): Back must be ≥ Pin", file: file, line: line)
        XCTAssertLessThanOrEqual(pin - front, 40, "\(courseName) H\(holeNumber): Front-of-green is ~10–25 m short of pin; >40 m means a stray vertex slipped through", file: file, line: line)
        XCTAssertLessThanOrEqual(back - pin, 40, "\(courseName) H\(holeNumber): Back-of-green is ~10–25 m past pin; >40 m means a stray vertex slipped through", file: file, line: line)
    }

    func testSeededRepositoryProvidesFeatureGeometryForLiveRoundMap() throws {
        let repository = SeededCourseRepository()

        let course = try XCTUnwrap(repository.nearbyCourses().first(where: { $0.name == "Royal Melbourne" }))
        let firstHole = try XCTUnwrap(course.holes.first)
        let fairway = try XCTUnwrap(firstHole.features.first(where: { $0.kind == .fairway }))
        let green = try XCTUnwrap(firstHole.features.first(where: { $0.kind == .green }))

        XCTAssertGreaterThanOrEqual(fairway.coordinates.count, 4)
        XCTAssertGreaterThanOrEqual(green.coordinates.count, 4)
    }

    func testSeededRepositoryProvidesSourceMetadataAndMapContext() throws {
        let repository = SeededCourseRepository()

        let course = try XCTUnwrap(repository.nearbyCourses().first(where: { $0.name == "Royal Melbourne" }))

        // Royal Melbourne is now backed by a hand-traced/OSM-derived bundled JSON,
        // so its source references reflect the true ingestion path (OSM only) and
        // its coordinate is the geometric centroid of all hole features rather
        // than the curated club-marker coordinate.
        XCTAssertEqual(course.sourceReferences.map(\.kind), [.openStreetMap])
        XCTAssertEqual(course.quality.overallConfidence, .reviewed)
        XCTAssertEqual(course.quality.readinessLabel, "Round-ready")
        XCTAssertEqual(course.community.access, .open)
        XCTAssertEqual(course.coordinate.latitude, -37.971, accuracy: 0.005)
        XCTAssertEqual(course.coordinate.longitude, 145.029, accuracy: 0.005)
    }

    func testCourseDiscoveryBuildsFeaturedHeroFromNearestCourse() {
        let repository = SeededCourseRepository()

        let model = CourseDiscoveryViewModel(courses: repository.nearbyCourses())

        XCTAssertEqual(model.heroEyebrow, "Near Brighton, VIC")
        XCTAssertEqual(model.heroTitle, "Pick your opening tee shot")
        XCTAssertEqual(model.featuredCourse?.name, "Medway Golf Club")
        XCTAssertEqual(model.featuredDistanceLabel, "2.6 km away")
        XCTAssertEqual(model.featuredDeck, "Closest first, then move straight into tee and player setup.")
        XCTAssertEqual(model.collectionEyebrow, "Ranked nearby")
        XCTAssertEqual(model.stagePresentation, .stackedShowcase)
        XCTAssertEqual(model.stageAssetName, "RoundDiscoveryStage")
    }

    func testCourseDiscoveryUsesFallbackMessagingWhenNoCoursesExist() {
        let model = CourseDiscoveryViewModel(courses: [])

        XCTAssertNil(model.featuredCourse)
        XCTAssertEqual(model.featuredDistanceLabel, "No course loaded")
        XCTAssertEqual(model.collectionTitle, "Nearby Courses")
        XCTAssertEqual(model.collectionEyebrow, "Ranked nearby")
        XCTAssertEqual(model.stagePresentation, .stackedShowcase)
        XCTAssertEqual(model.stageAssetName, "RoundDiscoveryStage")
    }

    func testCourseDetailBuildsPrimaryCommitmentPresentation() throws {
        let repository = SeededCourseRepository()
        let course = try XCTUnwrap(repository.nearbyCourses().first(where: { $0.name == "Royal Melbourne" }))
        let selectedTee = try XCTUnwrap(course.tees.first(where: { $0.name == "Member" }))

        let model = CourseDetailViewModel(course: course, selectedTee: selectedTee, distanceUnit: .meters)

        XCTAssertEqual(model.heroEyebrow, "Course Lock")
        XCTAssertEqual(model.heroTitle, "Royal Melbourne")
        XCTAssertEqual(model.heroDistanceLabel, "3.2 km away")
        let memberTeeMeters = Int((Double(selectedTee.yards) * 0.9144).rounded())
        XCTAssertEqual(model.teeBadgeText, "Member • \(memberTeeMeters)m")
        XCTAssertEqual(model.briefingEyebrow, "Course briefing")
        XCTAssertEqual(model.selectionDeck, "Pick the tee that matches today’s round and move straight into players.")
        XCTAssertEqual(model.stagePresentation, .stackedShowcase)
        XCTAssertEqual(model.stageAssetName, "CourseDetailStage")
    }

    func testCourseDetailBuildsSecondaryDataDisclosure() throws {
        let repository = SeededCourseRepository()
        let course = try XCTUnwrap(repository.nearbyCourses().first(where: { $0.name == "Royal Melbourne" }))

        let model = CourseDetailViewModel(course: course, selectedTee: nil)

        XCTAssertEqual(model.dataDisclosureTitle, "Course data and community")
        XCTAssertEqual(model.reportActionTitle, "Report course data")
        XCTAssertEqual(model.expectations.count, 3)
    }

    func testCorrectionDraftBuildsSubmissionSummaryFromHoleAndKind() {
        let course = SwingPalCourse.test(name: "Royal Melbourne", distanceKilometers: 3.2)
        let draft = CourseCorrectionDraft(
            courseID: course.id,
            courseName: course.name,
            kind: .bunkerShape,
            holeNumber: 4,
            detail: "Front-right bunker sits closer to the green edge than shown.",
            evidences: [
                .init(kind: .note, value: "Verified during April round")
            ]
        )

        XCTAssertEqual(draft.status, .draft)
        XCTAssertEqual(draft.summaryTitle, "Hole 4 bunker update")
        XCTAssertEqual(draft.summaryCaption, "1 piece of evidence attached")
        XCTAssertTrue(draft.canSubmit)
    }
}
