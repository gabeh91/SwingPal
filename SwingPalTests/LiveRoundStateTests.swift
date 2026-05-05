import XCTest
import CoreGraphics
import CoreLocation
import SwiftUI
@testable import SwingPal

final class LiveRoundStateTests: XCTestCase {
    func testLongOpeningShotStartsInTeeShotPhase() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertEqual(state.shotPhase, .teeShot)
        XCTAssertEqual(state.shotPhaseTitle, "Tee shot")
        XCTAssertEqual(state.shotFocus, "Pick a confident starting line.")
    }

    func testPlaysLikeCalculatorAddsHeadWindAndCoolerAirAdjustments() {
        // 150m shot due north, 20 km/h wind from due north (a head wind),
        // and 10°C ambient (10°C below the 20°C baseline). Each effect adds
        // distance: head wind pushes the number up via
        //   150 * 0.004 * 20 = 12m
        // cooler air adds via
        //   150 * 0.002 * 10 = 3m
        // ...for a plays-like of ~165m.
        let weather = RoundWeatherSnapshot(
            temperatureCelsius: 10,
            apparentTemperatureCelsius: 8,
            conditionDescription: "Cool & windy",
            symbolName: "wind",
            windSpeedKilometersPerHour: 20,
            windCompassDirection: "N",
            windDirectionDegrees: 0,
            attributionText: nil
        )

        let result = PlaysLikeCalculator.adjustedMeters(
            baseMeters: 150,
            shotBearingDegrees: 0,
            weather: weather
        )

        XCTAssertEqual(result, 165)
    }

    func testPlaysLikeCalculatorSubtractsTailWind() {
        // 150m shot due north, 20 km/h wind from due south = pure tail wind.
        // 150 * 0.004 * -20 = -12m, so plays-like ~138m at 20°C baseline.
        let weather = RoundWeatherSnapshot(
            temperatureCelsius: 20,
            apparentTemperatureCelsius: 20,
            conditionDescription: "Mild",
            symbolName: "sun.max",
            windSpeedKilometersPerHour: 20,
            windCompassDirection: "S",
            windDirectionDegrees: 180,
            attributionText: nil
        )

        let result = PlaysLikeCalculator.adjustedMeters(
            baseMeters: 150,
            shotBearingDegrees: 0,
            weather: weather
        )

        XCTAssertEqual(result, 138)
    }

    func testPlaysLikeCalculatorIgnoresPureCrossWind() {
        // Wind blowing perpendicular to the shot direction shouldn't change
        // distance, only direction (which we don't model).
        let weather = RoundWeatherSnapshot(
            temperatureCelsius: 20,
            apparentTemperatureCelsius: 20,
            conditionDescription: "Cross wind",
            symbolName: "wind",
            windSpeedKilometersPerHour: 30,
            windCompassDirection: "E",
            windDirectionDegrees: 90,
            attributionText: nil
        )

        let result = PlaysLikeCalculator.adjustedMeters(
            baseMeters: 150,
            shotBearingDegrees: 0,
            weather: weather
        )

        XCTAssertEqual(result, 150)
    }

    func testDerivedFairwayInRegulationReturnsNilForPar3Holes() {
        let par3 = HoleSession(
            number: 1,
            par: 3,
            shots: [
                ShotEvent(clubName: "8i", distanceToTargetMeters: 152, strokeNumber: 1, surface: .tee, shotType: .teeShot),
                ShotEvent(clubName: "PW", distanceToTargetMeters: 5, strokeNumber: 2, surface: .green, shotType: .putt)
            ]
        )

        XCTAssertNil(LiveRoundState.derivedFairwayInRegulation(for: par3))
    }

    func testDerivedFairwayInRegulationFlagsFairwayLandingOnPar4() {
        let hit = HoleSession(
            number: 2,
            par: 4,
            shots: [
                ShotEvent(clubName: "Driver", distanceToTargetMeters: 380, strokeNumber: 1, surface: .tee, shotType: .teeShot),
                ShotEvent(clubName: "8i", distanceToTargetMeters: 152, strokeNumber: 2, surface: .fairway, shotType: .approach)
            ]
        )
        let miss = HoleSession(
            number: 3,
            par: 4,
            shots: [
                ShotEvent(clubName: "Driver", distanceToTargetMeters: 380, strokeNumber: 1, surface: .tee, shotType: .teeShot),
                ShotEvent(clubName: "9i", distanceToTargetMeters: 130, strokeNumber: 2, surface: .rough, shotType: .approach)
            ]
        )

        XCTAssertEqual(LiveRoundState.derivedFairwayInRegulation(for: hit), true)
        XCTAssertEqual(LiveRoundState.derivedFairwayInRegulation(for: miss), false)
    }

    func testDerivedGreenInRegulationFlagsParMinusTwoApproach() {
        // Par 4: GIR achieved if a putt happens at stroke <= par - 1 = 3.
        // The first putt below is at stroke 3, so the previous shot (stroke 2)
        // must have been on the green - GIR achieved.
        let gir = HoleSession(
            number: 4,
            par: 4,
            shots: [
                ShotEvent(clubName: "Driver", distanceToTargetMeters: 380, strokeNumber: 1, surface: .tee, shotType: .teeShot),
                ShotEvent(clubName: "8i", distanceToTargetMeters: 152, strokeNumber: 2, surface: .fairway, shotType: .approach),
                ShotEvent(clubName: "Putter", distanceToTargetMeters: 4, strokeNumber: 3, surface: .green, shotType: .putt)
            ]
        )
        let nonGir = HoleSession(
            number: 5,
            par: 4,
            shots: [
                ShotEvent(clubName: "Driver", distanceToTargetMeters: 380, strokeNumber: 1, surface: .tee, shotType: .teeShot),
                ShotEvent(clubName: "8i", distanceToTargetMeters: 152, strokeNumber: 2, surface: .rough, shotType: .approach),
                ShotEvent(clubName: "PW", distanceToTargetMeters: 30, strokeNumber: 3, surface: .rough, shotType: .chip),
                ShotEvent(clubName: "Putter", distanceToTargetMeters: 3, strokeNumber: 4, surface: .green, shotType: .putt)
            ]
        )

        XCTAssertEqual(LiveRoundState.derivedGreenInRegulation(for: gir), true)
        XCTAssertEqual(LiveRoundState.derivedGreenInRegulation(for: nonGir), false)
    }

    func testRoundScoreToParAggregatesConfirmedHolesOnly() {
        let state = makeStateWithThreeHoles(activeHoleNumber: 1)

        // Hole 1 (par 4): confirmed score 5 = +1.
        // `confirmCurrentHole` automatically advances to the next hole, so we
        // don't need a manual `advanceToNextHole()` between confirms.
        state.presentHoleConfirmation()
        state.setPendingHoleScore(5)
        state.setPendingHolePutts(2)
        state.setPendingHolePenaltyCount(0)
        state.setPendingHoleDropCount(0)
        XCTAssertTrue(state.confirmCurrentHole())
        XCTAssertEqual(state.roundConfirmedHoleCount, 1)
        XCTAssertEqual(state.roundScoreToPar, 1)

        // Hole 2 (par 4): confirmed score 3 = -1.
        state.presentHoleConfirmation()
        state.setPendingHoleScore(3)
        state.setPendingHolePutts(1)
        state.setPendingHolePenaltyCount(0)
        state.setPendingHoleDropCount(0)
        XCTAssertTrue(state.confirmCurrentHole())

        // Aggregate is +1 + (-1) = 0 => "E", thru 2 confirmed holes.
        XCTAssertEqual(state.roundConfirmedHoleCount, 2)
        XCTAssertEqual(state.roundScoreToPar, 0)
        XCTAssertEqual(state.roundScoreToParDisplay, "E")
    }

    func testPlaysLikeDistanceFallsBackToBasePinDistanceWhenWeatherIsUnavailable() {
        // Without a `weatherSnapshot` we have no wind direction or temperature
        // to feed into `PlaysLikeCalculator`, so plays-like degrades to the
        // raw GPS pin distance. (The legacy implementation just added a
        // hardcoded +6m placeholder regardless of conditions, which produced
        // a misleading "plays like" reading on weather-less previews.)
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.distanceToPinMeters = 146

        XCTAssertEqual(state.playsLikeDistanceMeters, 146)
    }

    func testShortDistanceMovesStateIntoScoringPhase() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.distanceToPinMeters = 84

        XCTAssertEqual(state.shotPhase, .scoring)
        XCTAssertEqual(state.shotPhaseTitle, "Scoring zone")
        XCTAssertEqual(state.shotFocus, "Favor control over raw distance.")
    }

    func testTargetLabelDescribesThePin() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertEqual(state.targetLabel, "Pin")
    }

    func testAvailableClubNamesIncludeBagStyleRoundOptions() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertEqual(Array(state.availableClubNames.prefix(5)), ["Driver", "3W", "5W", "4i", "5i"])
        XCTAssertEqual(Array(state.availableClubNames.suffix(2)), ["SW", "Putter"])
    }

    func testSelectingClubUpdatesCurrentSelection() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.selectClub(named: "5W")

        XCTAssertEqual(state.selectedClubName, "5W")
    }

    func testShotLoggingSummaryReflectsCurrentSelection() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.selectClub(named: "8i")
        state.presentShotLogger()

        let expectedDistance = state.shortDistanceLabel(forMeters: state.displayedPinDistanceMeters)
        XCTAssertEqual(state.shotLoggingTitle, "8i • \(expectedDistance) to pin")
        // Subtitle adapts to context — stroke 1 always presents the tee form.
        XCTAssertEqual(state.shotLoggingSubtitle, "Pick the club, tag the outcome, log the tee shot.")
    }

    func testShotLoggingSubtitleSwapsToPuttCopyOnTheGreen() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.presentShotLogger()
        state.selectShotSurface(.green)

        XCTAssertEqual(state.shotLoggingSubtitle, "Mark holed or missed — tap to log it.")
    }

    func testPresentClubWheelMarksClubSelectionUIActive() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentClubWheel()

        XCTAssertTrue(state.isShowingClubWheel)
    }

    func testSelectingClubPublishesRoundCompanionSnapshot() {
        let sync = RecordingRoundCompanionSync()
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            roundCompanionSync: sync
        )

        state.selectClub(named: "5i")

        XCTAssertEqual(sync.lastSnapshot?.selectedClubName, "5i")
        XCTAssertEqual(sync.lastSnapshot?.holeNumber, 1)
        XCTAssertEqual(sync.lastSnapshot?.loggedShotCount, 0)
    }

    func testCompanionSnapshotCarriesBagDrivenClubOptions() {
        let sync = RecordingRoundCompanionSync()
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            clubCarryMetersByClubName: [
                "7I": 150,
                "5W": 205,
                "Putter": 10,
                "Driving Iron": 198
            ],
            roundCompanionSync: sync
        )

        XCTAssertEqual(sync.lastSnapshot?.availableClubNames, ["5W", "7i", "Putter", "Driving Iron", "Driver"])
    }

    func testPreviewCorridorBoundsIgnoreWideHazardOutliers() throws {
        let hole = SwingPalCourse.Hole(
            number: 1,
            par: 4,
            features: [
                .init(
                    kind: .tee,
                    label: "Tee",
                    coordinates: [
                        .init(latitude: -37.9000, longitude: 145.0000),
                        .init(latitude: -37.9001, longitude: 145.0001),
                    ]
                ),
                .init(
                    kind: .fairway,
                    label: "Fairway",
                    coordinates: [
                        .init(latitude: -37.8994, longitude: 145.0002),
                        .init(latitude: -37.8988, longitude: 145.0005),
                        .init(latitude: -37.8980, longitude: 145.0007),
                    ]
                ),
                .init(
                    kind: .green,
                    label: "Green",
                    coordinates: [
                        .init(latitude: -37.8973, longitude: 145.0006),
                        .init(latitude: -37.8972, longitude: 145.0008),
                    ]
                ),
                .init(
                    kind: .bunker,
                    label: "Far bunker",
                    coordinates: [
                        .init(latitude: -37.8983, longitude: 145.0038),
                        .init(latitude: -37.8981, longitude: 145.0040),
                    ]
                ),
            ]
        )

        let fullBounds = try XCTUnwrap(hole.bounds)
        let previewBounds = try XCTUnwrap(RoundCompanionPreviewCorridorBounds.resolve(for: hole))

        XCTAssertLessThan(previewBounds.maxLongitude, fullBounds.maxLongitude)
        let previewLongitudeDelta = previewBounds.maxLongitude - previewBounds.minLongitude
        XCTAssertLessThan(previewLongitudeDelta, fullBounds.longitudeDelta)
    }

    func testLoggingShotPublishesUpdatedCompanionSnapshot() {
        let sync = RecordingRoundCompanionSync()
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            roundCompanionSync: sync
        )

        state.presentShotLogger()
        state.selectShotDirection(.hit)
        state.selectShotDistance(.onNumber)
        state.confirmPendingShot()

        XCTAssertEqual(sync.lastSnapshot?.loggedShotCount, 1)
        XCTAssertEqual(sync.lastSnapshot?.holeNumber, 1)
        XCTAssertFalse(sync.lastSnapshot?.isInspectingHole ?? true)
    }

    func testCompanionSnapshotIncludesFrontPinAndBackYardages() {
        let sync = RecordingRoundCompanionSync()
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            roundCompanionSync: sync
        )

        state.distanceToPinMeters = 144

        XCTAssertEqual(sync.lastSnapshot?.frontDistanceMeters, state.displayedFrontDistanceMeters)
        XCTAssertEqual(sync.lastSnapshot?.distanceToTargetMeters, 144)
        XCTAssertEqual(sync.lastSnapshot?.backDistanceMeters, state.displayedBackDistanceMeters)
    }

    func testCompanionSnapshotReflectsHoleScoringAndShotCounts() {
        let sync = RecordingRoundCompanionSync()
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            roundCompanionSync: sync
        )

        state.logShot(
            clubName: "SW",
            distanceToTargetMeters: 12,
            penaltyCount: 1,
            surface: .green,
            shotType: .putt,
            puttDetail: .init(puttCount: 1, firstPuttDistanceMeters: 3)
        )

        XCTAssertEqual(sync.lastSnapshot?.shotNumber, 2)
        XCTAssertEqual(sync.lastSnapshot?.puttCount, 1)
        XCTAssertEqual(sync.lastSnapshot?.penaltyCount, 1)
        XCTAssertEqual(sync.lastSnapshot?.holeScore, 2)
        XCTAssertEqual(sync.lastSnapshot?.currentSurface, ShotEvent.Surface.green.rawValue)
    }

    func testPresentingHoleConfirmationPublishesFinishHoleReadiness() {
        let sync = RecordingRoundCompanionSync()
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            roundCompanionSync: sync
        )

        state.logShot(clubName: "7i", distanceToTargetMeters: 152)
        XCTAssertFalse(sync.lastSnapshot?.canFinishHole ?? true)

        state.presentHoleConfirmation()

        XCTAssertTrue(sync.lastSnapshot?.canFinishHole ?? false)
    }

    func testWatchIntentCanChangeSelectedClub() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.applyCompanionAction(.changeClub(name: "7i"), source: .watch)

        XCTAssertEqual(state.selectedClubName, "7i")
    }

    func testWatchIntentCanAddPuttWithoutOpeningPhoneLogger() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.applyCompanionAction(.addPutt, source: .watch)

        XCTAssertEqual(state.currentPlayerTotalPutts, 1)
        XCTAssertFalse(state.isShowingShotLogger)
    }

    func testInspectingPreviousHolePublishesInspectionCompanionSnapshot() {
        let sync = RecordingRoundCompanionSync()
        let state = LiveRoundState(
            hole: HoleSession(number: 2, par: 4),
            courseHoles: [
                .init(number: 1, par: 4, features: []),
                .init(number: 2, par: 4, features: []),
                .init(number: 3, par: 3, features: [])
            ],
            players: [.init(name: "You", kind: .selfPlayer)],
            roundCompanionSync: sync
        )

        state.inspectPreviousHole()

        XCTAssertEqual(sync.lastSnapshot?.holeNumber, 1)
        XCTAssertTrue(sync.lastSnapshot?.isInspectingHole ?? false)
    }

    func testRestoringFromSnapshotPublishesOnlyFinalCompanionSnapshot() {
        let baseState = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        baseState.selectClub(named: "6i")
        let sync = RecordingRoundCompanionSync()

        _ = LiveRoundState(
            snapshot: baseState.snapshot,
            roundCompanionSync: sync
        )

        XCTAssertEqual(sync.publishedSnapshots.count, 1)
        XCTAssertEqual(sync.lastSnapshot?.selectedClubName, "6i")
        XCTAssertEqual(sync.lastSnapshot?.holeNumber, 1)
    }

    func testSelectingClubFromWheelUpdatesCurrentSelectionAndDismissesWheel() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentClubWheel()
        state.selectClubFromWheel(named: "5W")

        XCTAssertEqual(state.selectedClubName, "5W")
        XCTAssertFalse(state.isShowingClubWheel)
    }

    func testInspectionModeIgnoresClubWheelSelectionMutation() {
        let state = makeStateWithThreeHoles(activeHoleNumber: 2)

        state.selectClub(named: "7i")
        state.inspectHole(at: 0)
        state.selectClubFromWheel(named: "5W")

        XCTAssertEqual(state.selectedClubName, "7i")
        XCTAssertFalse(state.isShowingClubWheel)
    }

    func testClubWheelFallsBackToAmateurBaselineWhenNoCarryDataExists() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        let club = state.clubWheelEntries.first { $0.clubName == "7i" }

        XCTAssertEqual(club?.displayCarryMeters, 128)
    }

    func testClubWheelUsesPlayerCarryWhenCarryDataExists() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            clubCarryMetersByClubName: ["7i": 144]
        )

        let club = state.clubWheelEntries.first { $0.clubName == "7i" }

        XCTAssertEqual(club?.displayCarryMeters, 144)
    }

    func testClubWheelEntryFlagsLoggedVsBaselineCarrySource() {
        // Without a bag, every club on the wheel falls back to the amateur
        // baseline so we should see `.baseline` everywhere.
        let baselineOnly = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        let baselineSeven = baselineOnly.clubWheelEntries.first { $0.clubName == "7i" }
        XCTAssertEqual(baselineSeven?.carrySource, .baseline)

        // Once the player has logged a carry for a club, that entry should
        // flip to `.logged` so the wheel can render the "your data" source dot.
        let logged = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            clubCarryMetersByClubName: ["7i": 144]
        )
        let loggedSeven = logged.clubWheelEntries.first { $0.clubName == "7i" }
        XCTAssertEqual(loggedSeven?.carrySource, .logged)
    }

    func testRecommendedClubMatchesPlaysLikeDistanceWithUpwardTieBreak() {
        // Plays-like = pin (no weather) = 130 m. Closest baseline carries are
        // 7i (128 m, gap -2) and 6i (141 m, gap +11). Both have a 2 / 11 gap;
        // we want the closest absolute - 7i. But we also need to verify the
        // upward tie-break: bump distance to 134.5 → 7i (128, gap -6.5) and
        // 6i (141, gap +6.5) tie absolutely; 6i should win.
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.distanceToPinMeters = 130
        XCTAssertEqual(state.recommendedClubName, "7i")

        state.distanceToPinMeters = 135 // 7i: -7, 6i: +6 → 6i wins on absolute
        XCTAssertEqual(state.recommendedClubName, "6i")
    }

    func testRecommendedClubExcludesPutterFromFullSwingRecommendations() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.distanceToPinMeters = 100 // Inside SW (73) and PW (96) range
        XCTAssertEqual(state.recommendedClubName, "PW")
    }

    func testRecommendedClubExcludesMalletStyleNameFromFullSwing() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            clubCarryMetersByClubName: [
                "Driver": 220,
                "Mid-Mallet": 10,
                "7i": 145
            ]
        )

        state.distanceToPinMeters = 130
        XCTAssertEqual(state.recommendedClubName, "7i")
    }

    func testAutoClubWheelHidesPutterLikeClubsOnTee() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            clubCarryMetersByClubName: [
                "Driver": 220,
                "7i": 145,
                "Mid-Mallet": 10
            ]
        )

        state.distanceToPinMeters = 380
        XCTAssertFalse(state.clubWheelDisplayedClubNames.contains(where: { $0.lowercased().contains("mallet") }))
        XCTAssertTrue(state.clubWheelDisplayedClubNames.contains("Driver"))
    }

    func testAutoClubWheelHidesPutterLikeOnApproachUnlessChipRange() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            clubCarryMetersByClubName: [
                "Driver": 220,
                "7i": 145,
                "Mid-Mallet": 10
            ]
        )

        state.setPendingShotStrokeNumber(2)
        state.distanceToPinMeters = 100
        XCTAssertFalse(state.clubWheelDisplayedClubNames.contains(where: { $0.lowercased().contains("mallet") }))

        state.distanceToPinMeters = 30
        XCTAssertTrue(state.clubWheelDisplayedClubNames.contains(where: { $0.lowercased().contains("mallet") }))
    }

    func testClubWheelEntryGapAndRelevanceSurfaceInOrOutOfRange() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.distanceToPinMeters = 130

        XCTAssertFalse(state.clubWheelEntries.isEmpty)
        XCTAssertNotNil(state.clubWheelEntries.first { $0.relevance == .tooLong })
        XCTAssertNotNil(state.clubWheelEntries.first { $0.relevance == .tooShort })
        XCTAssertNotNil(state.clubWheelEntries.first { $0.relevance == .viable })
    }

    func testClubWheelEntersPutterModeWhenDistanceIsVeryShort() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.distanceToPinMeters = 12

        XCTAssertTrue(state.isClubWheelInPutterMode)
        XCTAssertEqual(state.recommendedClubName, "Putter")

        let putter = state.clubWheelEntries.first { $0.clubName == "Putter" }
        let driverEntry = state.clubWheelEntries.first { $0.clubName == "Driver" }

        XCTAssertEqual(putter?.relevance, .viable)
        XCTAssertEqual(driverEntry?.relevance, .mutedByPutterMode)
        XCTAssertTrue(putter?.isRecommended ?? false)
    }

    func testRelevanceHelperIsExposedForUnitTesting() {
        XCTAssertEqual(
            LiveRoundState.relevance(forClub: "7i", gapToTarget: 0, isPutterMode: false),
            .viable
        )
        XCTAssertEqual(
            LiveRoundState.relevance(forClub: "7i", gapToTarget: 18, isPutterMode: false),
            .tooLong
        )
        XCTAssertEqual(
            LiveRoundState.relevance(forClub: "7i", gapToTarget: -18, isPutterMode: false),
            .tooShort
        )
        XCTAssertEqual(
            LiveRoundState.relevance(forClub: "7i", gapToTarget: -2, isPutterMode: true),
            .mutedByPutterMode
        )
        XCTAssertEqual(
            LiveRoundState.relevance(forClub: "Putter", gapToTarget: -2, isPutterMode: true),
            .viable
        )
        XCTAssertEqual(
            LiveRoundState.relevance(forClub: "Mid-Mallet", gapToTarget: -2, isPutterMode: true),
            .viable
        )
    }

    func testRelevanceHelperShortCircuitsToViableWhenAutoRecommendationIsDisabled() {
        // Even an obviously-out-of-range carry should be `.viable` in
        // manual mode - the wheel must let the player pick anything
        // without dimming non-recommended clubs.
        XCTAssertEqual(
            LiveRoundState.relevance(
                forClub: "Driver",
                gapToTarget: 70,
                isPutterMode: false,
                isAutoRecommendationEnabled: false
            ),
            .viable
        )
        // Putter mode is itself a recommendation, so it must be
        // suppressed in manual mode.
        XCTAssertEqual(
            LiveRoundState.relevance(
                forClub: "7i",
                gapToTarget: -2,
                isPutterMode: true,
                isAutoRecommendationEnabled: false
            ),
            .viable
        )
    }

    func testToggleClubAutoRecommendationFlipsTheFlagAndFiresPersistenceCallback() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertTrue(state.isClubAutoRecommendationEnabled)

        var observedValues: [Bool] = []
        state.onClubAutoRecommendationPreferenceChanged = { observedValues.append($0) }

        state.toggleClubAutoRecommendation()
        XCTAssertFalse(state.isClubAutoRecommendationEnabled)
        XCTAssertEqual(observedValues, [false])

        state.toggleClubAutoRecommendation()
        XCTAssertTrue(state.isClubAutoRecommendationEnabled)
        XCTAssertEqual(observedValues, [false, true])

        // Setting to the same value is a no-op (no extra callback fire),
        // so the persistence layer doesn't get spammed during view updates.
        state.setClubAutoRecommendationEnabled(true)
        XCTAssertEqual(observedValues, [false, true])
    }

    func testManualModeDropsRecommendationAndKeepsAllEntriesAtFullVisibility() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.distanceToPinMeters = 130

        // Sanity check: in auto mode the recommendation is wired up.
        XCTAssertEqual(state.recommendedClubName, "7i")

        state.setClubAutoRecommendationEnabled(false)

        // Manual mode: no recommendation, no putter-mode auto-trigger.
        XCTAssertNil(state.recommendedClubName)

        // Every entry should be `.viable` and unflagged - the wheel becomes
        // a flat picker.
        for entry in state.clubWheelEntries {
            XCTAssertEqual(entry.relevance, .viable, "Manual mode must not mute \(entry.clubName)")
            XCTAssertFalse(entry.isRecommended, "Manual mode must not mark \(entry.clubName) as recommended")
        }
    }

    func testEnablingAutoClubSelectsRecommendedClub() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.distanceToPinMeters = 130
        state.setClubAutoRecommendationEnabled(false)
        state.selectClub(named: "Driver")

        XCTAssertEqual(state.selectedClubName, "Driver")

        state.setClubAutoRecommendationEnabled(true)

        XCTAssertEqual(state.recommendedClubName, "7i")
        XCTAssertEqual(state.selectedClubName, "7i")
    }

    func testManualModeDoesNotEnterPutterMode() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.distanceToPinMeters = 12 // would normally trigger putter mode
        XCTAssertTrue(state.isClubWheelInPutterMode)

        state.setClubAutoRecommendationEnabled(false)
        XCTAssertFalse(state.isClubWheelInPutterMode)
        XCTAssertNil(state.recommendedClubName)
    }

    func testInitialAutoRecommendationFlagPropagatesFromAppPreference() {
        let liveState = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            clubAutoRecommendationEnabled: false
        )

        XCTAssertFalse(liveState.isClubAutoRecommendationEnabled)
        XCTAssertNil(liveState.recommendedClubName)
    }

    func testManualModeExposesFullStandardCatalogEvenWhenBagIsSparse() {
        // Sparse bag: only three clubs. In auto mode the wheel filters to
        // those three (the recommendation engine should only consider what
        // the player carries). In manual mode we widen to the full
        // standard catalog so the player can pick any club for trick or
        // emergency shots.
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            clubCarryMetersByClubName: [
                "Driver": 220,
                "7I": 145,
                "Putter": 10
            ]
        )

        // Auto mode: wheel sticks to the bag, but tee-shot UX hides putter-like clubs.
        XCTAssertTrue(state.isClubAutoRecommendationEnabled)
        XCTAssertEqual(state.availableClubNames, ["Driver", "7i", "Putter"])
        XCTAssertEqual(
            Set(state.clubWheelDisplayedClubNames),
            Set(["Driver", "7i"])
        )

        state.setClubAutoRecommendationEnabled(false)

        // Manual mode: full 12-club catalog appears, in canonical order.
        XCTAssertEqual(state.clubWheelDisplayedClubNames, LiveRoundState.defaultClubNames)
        XCTAssertEqual(state.clubWheelEntries.count, 12)
        XCTAssertTrue(state.clubWheelEntries.contains(where: { $0.clubName == "8i" }))
        XCTAssertTrue(state.clubWheelEntries.contains(where: { $0.clubName == "PW" }))
    }

    func testManualModePreservesCustomBagClubsAlongsideStandardCatalog() {
        // Custom-named bag clubs (e.g. "Driving Iron") should stack onto
        // the standard 12 in manual mode so the player keeps access to
        // both their personal kit and the broader picker.
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            clubCarryMetersByClubName: [
                "Driver": 220,
                "Driving Iron": 198,
                "7I": 145,
                "Putter": 10
            ]
        )

        state.setClubAutoRecommendationEnabled(false)

        let displayed = state.clubWheelDisplayedClubNames
        // Standard clubs come first, in canonical order.
        XCTAssertEqual(Array(displayed.prefix(LiveRoundState.defaultClubNames.count)), LiveRoundState.defaultClubNames)
        // Custom names come after.
        XCTAssertEqual(displayed.last, "Driving Iron")
        XCTAssertEqual(displayed.count, LiveRoundState.defaultClubNames.count + 1)
    }

    func testSelectingNonBagStandardClubFromWheelInManualModePersists() {
        // Bag has only Driver + 7i + Putter, but in manual mode the player
        // should still be able to pick "8i" from the wheel and have it
        // stick (downstream views expect the canonical name and a non-zero
        // baseline carry to render the spoke).
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            clubCarryMetersByClubName: [
                "Driver": 220,
                "7I": 145,
                "Putter": 10
            ]
        )
        state.setClubAutoRecommendationEnabled(false)

        XCTAssertNotEqual(state.selectedClubName, "8i")
        state.selectClubFromWheel(named: "8i")
        XCTAssertEqual(state.selectedClubName, "8i")
        // After selection the canonical name flows into `availableClubNames`
        // via the "selected club fallback" path so downstream APIs still
        // see it as in-scope.
        XCTAssertTrue(state.availableClubNames.contains("8i"))
        XCTAssertGreaterThan(state.selectedClubWheelEntry.displayCarryMeters, 0)
    }

    func testSelectingClubFromWheelStillRejectsUnknownNames() {
        // Even in manual mode the wheel must refuse names that aren't on
        // any displayed list — we don't want a buggy caller writing
        // junk into `selectedClubName`.
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.setClubAutoRecommendationEnabled(false)

        let originalSelection = state.selectedClubName
        state.selectClubFromWheel(named: "Hammer")
        XCTAssertEqual(state.selectedClubName, originalSelection)
    }

    func testRestoringCaseMismatchedSelectedClubCanonicalizesForKnownBagClub() {
        let baseState = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        let baseSnapshot = baseState.snapshot
        let restored = LiveRoundState(
            snapshot: .init(
                hole: baseSnapshot.hole,
                holeSessions: baseSnapshot.holeSessions,
                activeHoleIndex: baseSnapshot.activeHoleIndex,
                displayedHoleIndex: baseSnapshot.displayedHoleIndex,
                courseName: baseSnapshot.courseName,
                courseCoordinate: baseSnapshot.courseCoordinate,
                courseHoles: baseSnapshot.courseHoles,
                players: baseSnapshot.players,
                selectedClubName: "pw",
                distanceToPinMeters: baseSnapshot.distanceToPinMeters,
                mapRotationDegrees: baseSnapshot.mapRotationDegrees,
                mapPanOffset: baseSnapshot.mapPanOffset,
                planningTargetCoordinate: baseSnapshot.planningTargetCoordinate,
                reviewPlayers: baseSnapshot.reviewPlayers,
                playerLocation: baseSnapshot.playerLocation,
                ballMarkState: baseSnapshot.ballMarkState,
                lastLoggedShotOriginCoordinate: baseSnapshot.lastLoggedShotOriginCoordinate,
                lastLoggedShotOriginSource: baseSnapshot.lastLoggedShotOriginSource,
                lastLoggedShotTargetCoordinate: baseSnapshot.lastLoggedShotTargetCoordinate,
                lastLoggedShotTargetLabel: baseSnapshot.lastLoggedShotTargetLabel,
                ballMarkSuggestionBaselineCoordinate: baseSnapshot.ballMarkSuggestionBaselineCoordinate
            )
        )

        XCTAssertEqual(restored.selectedClubName, "PW")
        XCTAssertTrue(restored.availableClubNames.contains("PW"))
        XCTAssertGreaterThan(restored.selectedClubWheelEntry.displayCarryMeters, 0)
    }

    func testRestoringUnknownSelectedClubKeepsItAvailableAndUsesFallbackCarry() {
        let baseState = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        let baseSnapshot = baseState.snapshot
        let restored = LiveRoundState(
            snapshot: .init(
                hole: baseSnapshot.hole,
                holeSessions: baseSnapshot.holeSessions,
                activeHoleIndex: baseSnapshot.activeHoleIndex,
                displayedHoleIndex: baseSnapshot.displayedHoleIndex,
                courseName: baseSnapshot.courseName,
                courseCoordinate: baseSnapshot.courseCoordinate,
                courseHoles: baseSnapshot.courseHoles,
                players: baseSnapshot.players,
                selectedClubName: "Driving Iron",
                distanceToPinMeters: baseSnapshot.distanceToPinMeters,
                mapRotationDegrees: baseSnapshot.mapRotationDegrees,
                mapPanOffset: baseSnapshot.mapPanOffset,
                planningTargetCoordinate: baseSnapshot.planningTargetCoordinate,
                reviewPlayers: baseSnapshot.reviewPlayers,
                playerLocation: baseSnapshot.playerLocation,
                ballMarkState: baseSnapshot.ballMarkState,
                lastLoggedShotOriginCoordinate: baseSnapshot.lastLoggedShotOriginCoordinate,
                lastLoggedShotOriginSource: baseSnapshot.lastLoggedShotOriginSource,
                lastLoggedShotTargetCoordinate: baseSnapshot.lastLoggedShotTargetCoordinate,
                lastLoggedShotTargetLabel: baseSnapshot.lastLoggedShotTargetLabel,
                ballMarkSuggestionBaselineCoordinate: baseSnapshot.ballMarkSuggestionBaselineCoordinate
            )
        )

        XCTAssertEqual(restored.selectedClubName, "Driving Iron")
        XCTAssertTrue(restored.availableClubNames.contains("Driving Iron"))
        XCTAssertEqual(restored.selectedClubWheelEntry.displayCarryMeters, 128)
    }

    func testClubWheelHoverSelectionIncludesVisiblePillCorner() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        let center = CGPoint(x: 200, y: 200)
        let segmentDistance: CGFloat = 116
        let entrySize = CGSize(width: 72, height: 58)
        let index = 1
        let angleStep = (2 * Double.pi) / Double(max(state.clubWheelEntries.count, 1))
        let angle = (-Double.pi / 2) + (angleStep * Double(index))
        let entryCenter = CGPoint(
            x: center.x + (CGFloat(cos(angle)) * segmentDistance),
            y: center.y + (CGFloat(sin(angle)) * segmentDistance)
        )
        let visibleCorner = CGPoint(
            x: entryCenter.x + (entrySize.width / 2),
            y: entryCenter.y - (entrySize.height / 2)
        )

        let hoveredClub = FreshLiveRoundClubWheelGeometry.hoveredClubName(
            for: visibleCorner,
            center: center,
            clubNames: state.clubWheelEntries.map(\.clubName),
            segmentDistance: segmentDistance,
            entrySize: entrySize,
            innerSelectionRadius: 56
        )

        XCTAssertEqual(hoveredClub, state.clubWheelEntries[index].clubName)
    }

    func testClubWheelHoverSelectionRotatesWithSelectedIndex() {
        // After the player picks a club mid-round the wheel rotates so
        // the picked entry sits at the top. The hover-hit math has to
        // rotate with it — otherwise touching a visible spoke commits a
        // *different* club (the bug surfaced as "selecting in reverse"
        // once the bag was big enough that selectedIndex was non-zero).
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        // 12-club default catalog → selectedIndex 5 puts "6i" at top.
        let clubNames = state.clubWheelEntries.map(\.clubName)
        let count = clubNames.count
        XCTAssertGreaterThanOrEqual(count, 8)
        let selectedIndex = 5
        let center = CGPoint(x: 200, y: 200)
        let segmentDistance: CGFloat = 116
        let entrySize = CGSize(width: 72, height: 58)
        let angleStep = (2 * Double.pi) / Double(count)

        // Walk every visible spoke position and assert the geometry
        // returns the corresponding *post-rotation* entry.
        for entryIndex in clubNames.indices {
            let relative = entryIndex - selectedIndex
            let angle = (-Double.pi / 2) + (angleStep * Double(relative))
            let touchPoint = CGPoint(
                x: center.x + (CGFloat(cos(angle)) * segmentDistance),
                y: center.y + (CGFloat(sin(angle)) * segmentDistance)
            )
            let hovered = FreshLiveRoundClubWheelGeometry.hoveredClubName(
                for: touchPoint,
                center: center,
                clubNames: clubNames,
                segmentDistance: segmentDistance,
                entrySize: entrySize,
                innerSelectionRadius: 56,
                selectedIndex: selectedIndex
            )
            XCTAssertEqual(
                hovered,
                clubNames[entryIndex],
                "Touch on spoke \(entryIndex) (visible at relative \(relative)) should map back to that entry"
            )
        }
    }

    func testClubWheelHoverSelectionStaysOnPreviousSpokeForSmallAngularDrift() {
        // The user reported that an accidental upward drift on a
        // side-spoke would snap the hover back to the spoke at the top
        // of the rotated wheel. The fix is angular hysteresis: when the
        // touch has just barely crossed the boundary into the adjacent
        // sector, we keep the previous hover so small drifts feel sticky.
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        let clubNames = state.clubWheelEntries.map(\.clubName)
        let count = clubNames.count
        let center = CGPoint(x: 200, y: 200)
        let segmentDistance: CGFloat = 116
        let entrySize = CGSize(width: 72, height: 58)
        let angleStep = (2 * Double.pi) / Double(count)

        // Pick a non-top spoke and a touch point that's nudged just
        // past the midpoint toward the previous spoke (a light drift).
        let entryIndex = 3
        let centerAngle = (-Double.pi / 2) + (angleStep * Double(entryIndex))
        // Drift 60% of the way to the boundary between this spoke and
        // its anti-clockwise neighbour. With our 20% stickiness margin
        // this should still resolve to the original spoke.
        let driftFraction: Double = 0.6
        let driftedAngle = centerAngle - (angleStep / 2) * driftFraction
        let touchPoint = CGPoint(
            x: center.x + (CGFloat(cos(driftedAngle)) * segmentDistance),
            y: center.y + (CGFloat(sin(driftedAngle)) * segmentDistance)
        )

        let hovered = FreshLiveRoundClubWheelGeometry.hoveredClubName(
            for: touchPoint,
            center: center,
            clubNames: clubNames,
            segmentDistance: segmentDistance,
            entrySize: entrySize,
            innerSelectionRadius: 56,
            previousHoveredClubName: clubNames[entryIndex]
        )

        XCTAssertEqual(hovered, clubNames[entryIndex], "Drift inside the sector should keep the existing hover")
    }

    func testClubWheelHoverSelectionFlipsOnDeliberateAngularSweep() {
        // Mirror of the stickiness test: a drift well past the midpoint
        // (and through the stickiness margin) should commit to the new
        // spoke. Otherwise the wheel would feel locked.
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        let clubNames = state.clubWheelEntries.map(\.clubName)
        let count = clubNames.count
        let center = CGPoint(x: 200, y: 200)
        let segmentDistance: CGFloat = 116
        let entrySize = CGSize(width: 72, height: 58)
        let angleStep = (2 * Double.pi) / Double(count)

        let entryIndex = 3
        let centerAngle = (-Double.pi / 2) + (angleStep * Double(entryIndex))
        // Move 95% of an angleStep toward the previous spoke — well past
        // the stickiness threshold (midpoint = 50% + 20% margin = 70%).
        let driftFraction: Double = 0.95
        let driftedAngle = centerAngle - angleStep * driftFraction
        let touchPoint = CGPoint(
            x: center.x + (CGFloat(cos(driftedAngle)) * segmentDistance),
            y: center.y + (CGFloat(sin(driftedAngle)) * segmentDistance)
        )

        let hovered = FreshLiveRoundClubWheelGeometry.hoveredClubName(
            for: touchPoint,
            center: center,
            clubNames: clubNames,
            segmentDistance: segmentDistance,
            entrySize: entrySize,
            innerSelectionRadius: 56,
            previousHoveredClubName: clubNames[entryIndex]
        )

        XCTAssertEqual(
            hovered,
            clubNames[entryIndex - 1],
            "Deliberate sweep past the stickiness margin should flip to the neighbour"
        )
    }

    func testClubWheelHoverSelectionWithSelectedIndexZeroMatchesUnrotatedDefault() {
        // Sanity check: when selectedIndex defaults to 0, the rotated
        // helper should behave identically to the historical unrotated
        // path. This locks in back-compat for any call site that relies
        // on the default parameter.
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        let clubNames = state.clubWheelEntries.map(\.clubName)
        let center = CGPoint(x: 200, y: 200)
        let segmentDistance: CGFloat = 116
        let entrySize = CGSize(width: 72, height: 58)
        let angleStep = (2 * Double.pi) / Double(max(clubNames.count, 1))
        let touchIndex = 3
        let angle = (-Double.pi / 2) + (angleStep * Double(touchIndex))
        let touchPoint = CGPoint(
            x: center.x + (CGFloat(cos(angle)) * segmentDistance),
            y: center.y + (CGFloat(sin(angle)) * segmentDistance)
        )

        let withDefault = FreshLiveRoundClubWheelGeometry.hoveredClubName(
            for: touchPoint,
            center: center,
            clubNames: clubNames,
            segmentDistance: segmentDistance,
            entrySize: entrySize,
            innerSelectionRadius: 56
        )
        let withExplicitZero = FreshLiveRoundClubWheelGeometry.hoveredClubName(
            for: touchPoint,
            center: center,
            clubNames: clubNames,
            segmentDistance: segmentDistance,
            entrySize: entrySize,
            innerSelectionRadius: 56,
            selectedIndex: 0
        )
        XCTAssertEqual(withDefault, clubNames[touchIndex])
        XCTAssertEqual(withDefault, withExplicitZero)
    }

    func testLiveRoundChromeMetricsFavorEdgeAlignedLauncher() {
        // Distance-card metrics dropped along with the old 4-card row;
        // the redesigned phase-aware top bar sizes its hero / satellite
        // chips through `FreshLiveRoundTopPanelLayout` instead.
        let metrics = FreshLiveRoundChromeMetrics.standard

        XCTAssertEqual(metrics.launcherHorizontalInset, 0)
        XCTAssertGreaterThanOrEqual(metrics.launcherContentPadding, 16)
    }

    func testLiveRoundPaletteFlipsTextContrastBetweenLightAndDarkAppearances() {
        let lightPalette = FreshLiveRoundPalette.forColorScheme(.light)
        let darkPalette = FreshLiveRoundPalette.forColorScheme(.dark)

        XCTAssertEqual(lightPalette.primaryTextContrast, .darkInk)
        XCTAssertEqual(lightPalette.secondaryTextContrast, .darkInk)
        XCTAssertEqual(darkPalette.primaryTextContrast, .lightInk)
        XCTAssertEqual(darkPalette.secondaryTextContrast, .lightInk)
        XCTAssertFalse(lightPalette.unselectedChipUsesProminentFill)
        XCTAssertFalse(darkPalette.unselectedChipUsesProminentFill)
    }

    func testLiveRoundPaletteUsesLighterGlassTreatmentInsteadOfHeavySlabTinting() {
        let lightPalette = FreshLiveRoundPalette.forColorScheme(.light)
        let darkPalette = FreshLiveRoundPalette.forColorScheme(.dark)

        XCTAssertLessThan(lightPalette.chromeTintOpacity, 0.25)
        XCTAssertLessThan(lightPalette.panelFillOpacity, 0.18)
        XCTAssertLessThan(lightPalette.secondaryFillOpacity, 0.20)
        XCTAssertLessThan(lightPalette.tertiaryFillOpacity, 0.12)
        XCTAssertLessThan(darkPalette.chromeTintOpacity, 0.40)
        XCTAssertGreaterThanOrEqual(darkPalette.panelFillOpacity, 0.12)
        XCTAssertGreaterThanOrEqual(darkPalette.secondaryFillOpacity, 0.18)
        XCTAssertGreaterThanOrEqual(darkPalette.tertiaryFillOpacity, 0.10)
        XCTAssertLessThan(darkPalette.panelFillOpacity, 0.26)
        XCTAssertLessThan(darkPalette.secondaryFillOpacity, 0.30)
        XCTAssertLessThan(darkPalette.tertiaryFillOpacity, 0.20)
    }

    func testLiveRoundUsesNativeGlassAPIsOnIOS26AndAbove() {
        XCTAssertTrue(FreshLiveRoundGlassCapabilities.supportsNativeGlass)
    }

    func testLiveRoundPrimaryChromeUsesRegularNativeGlassVariant() {
        XCTAssertEqual(FreshLiveRoundNativeGlassPolicy.primaryChrome, .regular)
        XCTAssertEqual(FreshLiveRoundNativeGlassPolicy.embeddedChrome, .regular)
    }

    func testLiveRoundUsesDedicatedTopPanelGestureShield() {
        XCTAssertTrue(FreshLiveRoundHUDInteractionPolicy.usesDedicatedTopPanelGestureShield)
    }

    func testLiveRoundTopPanelGestureShieldIsBoundBehindPanelContent() {
        XCTAssertTrue(FreshLiveRoundHUDInteractionPolicy.topPanelGestureShieldUsesBackgroundSizing)
    }

    func testLiveRoundPaletteUsesTintedLoggerSelectableFillInsteadOfPlainWhite() {
        let lightPalette = FreshLiveRoundPalette.forColorScheme(.light)
        let darkPalette = FreshLiveRoundPalette.forColorScheme(.dark)

        XCTAssertTrue(lightPalette.loggerOptionUsesTintedFill)
        XCTAssertTrue(darkPalette.loggerOptionUsesTintedFill)
    }

    func testLiveRoundPaletteKeepsEmbeddedTileOpacitySubtleForGlassHierarchy() {
        let lightPalette = FreshLiveRoundPalette.forColorScheme(.light)
        let darkPalette = FreshLiveRoundPalette.forColorScheme(.dark)

        XCTAssertLessThan(lightPalette.secondaryFillOpacity, 0.07)
        XCTAssertLessThan(lightPalette.tertiaryFillOpacity, 0.04)
        XCTAssertGreaterThan(darkPalette.secondaryFillOpacity, lightPalette.secondaryFillOpacity)
        XCTAssertGreaterThan(darkPalette.tertiaryFillOpacity, lightPalette.tertiaryFillOpacity)
    }

    func testLiveRoundDarkPaletteStrengthensWheelAndCardSurfacesForReadableContrast() {
        let darkPalette = FreshLiveRoundPalette.forColorScheme(.dark)

        XCTAssertGreaterThanOrEqual(darkPalette.wheelEntryFillOpacity, 0.14)
        XCTAssertGreaterThanOrEqual(darkPalette.wheelCenterFillOpacity, 0.28)
        XCTAssertGreaterThan(darkPalette.secondaryFillOpacity, darkPalette.panelFillOpacity)
    }

    func testClubWheelLayoutCentersAndUsesLargerPhoneMetrics() {
        let anchor = CGRect(x: 24, y: 662, width: 132, height: 44)
        let containerSize = CGSize(width: 393, height: 852)
        let layout = FreshLiveRoundClubWheelLayout.resolve(
            anchorFrame: anchor,
            safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
            containerSize: containerSize,
            entryCount: 10
        )

        XCTAssertEqual(layout.center.x, containerSize.width / 2, accuracy: 0.001)
        XCTAssertEqual(layout.center.y, containerSize.height / 2, accuracy: 0.001)
        XCTAssertGreaterThan(layout.outerRadius, 142)
        XCTAssertGreaterThan(layout.entrySize.width, 84)
        XCTAssertGreaterThan(layout.entrySize.height, 68)
        XCTAssertLessThan(layout.segmentDistance, layout.outerRadius)
    }

    func testClubWheelMotionUsesProgressiveEntryAnimation() {
        let motion = FreshLiveRoundClubWheelMotion.standard

        XCTAssertLessThan(motion.entryBaseScale, 1)
        XCTAssertGreaterThan(motion.selectedScale, 1)
        XCTAssertGreaterThan(motion.entryDelayStep, 0)
    }

    func testShotOutcomeLayoutSplitsRingIntoEightEqualSectors() {
        let layout = FreshLiveRoundShotOutcomeLayout.standard

        XCTAssertEqual(layout.sectorAngleSpanDegrees, 45, accuracy: 0.001)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.allCases.count, 8)

        for node in FreshLiveRoundShotOutcomeNode.allCases {
            let span = layout.endAngleDegrees(for: node) - layout.startAngleDegrees(for: node)
            XCTAssertEqual(span, layout.sectorAngleSpanDegrees, accuracy: 0.001)
        }
    }

    func testShotOutcomeNodesPlaceLongAtTopAndShortAtBottomAndDirectionsOnHorizontalAxis() {
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.long.midAngleDegrees, 0, accuracy: 0.001)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.right.midAngleDegrees, 90, accuracy: 0.001)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.short.midAngleDegrees, 180, accuracy: 0.001)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.left.midAngleDegrees, 270, accuracy: 0.001)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.longRight.midAngleDegrees, 45, accuracy: 0.001)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.shortRight.midAngleDegrees, 135, accuracy: 0.001)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.shortLeft.midAngleDegrees, 225, accuracy: 0.001)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.longLeft.midAngleDegrees, 315, accuracy: 0.001)
    }

    func testShotOutcomeNodeResolvesDistanceForEachSector() {
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.long.distance, .long)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.longRight.distance, .long)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.longLeft.distance, .long)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.short.distance, .short)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.shortRight.distance, .short)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.shortLeft.distance, .short)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.left.distance, .onNumber)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.right.distance, .onNumber)
    }

    func testShotOutcomeNodeResolvesDirectionUsingIntensityForLateralSectors() {
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.right.resolvedDirection(intensity: .normal), .right)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.right.resolvedDirection(intensity: .far), .farRight)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.shortLeft.resolvedDirection(intensity: .normal), .left)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.shortLeft.resolvedDirection(intensity: .far), .farLeft)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.longRight.resolvedDirection(intensity: .far), .farRight)
    }

    func testShotOutcomeNodeIgnoresIntensityForNonLateralSectors() {
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.long.resolvedDirection(intensity: .normal), .hit)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.long.resolvedDirection(intensity: .far), .hit)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.short.resolvedDirection(intensity: .normal), .hit)
        XCTAssertEqual(FreshLiveRoundShotOutcomeNode.short.resolvedDirection(intensity: .far), .hit)
    }

    func testShotOutcomeLayoutLabelsAreSymmetricAroundCenter() {
        let layout = FreshLiveRoundShotOutcomeLayout.standard
        let ringCenter = layout.ringDiameter / 2

        let longLabel = layout.labelPosition(for: .long)
        let shortLabel = layout.labelPosition(for: .short)
        XCTAssertEqual(longLabel.x, ringCenter, accuracy: 0.001)
        XCTAssertEqual(shortLabel.x, ringCenter, accuracy: 0.001)
        XCTAssertEqual(longLabel.y + shortLabel.y, ringCenter * 2, accuracy: 0.001)

        let leftLabel = layout.labelPosition(for: .left)
        let rightLabel = layout.labelPosition(for: .right)
        XCTAssertEqual(leftLabel.y, ringCenter, accuracy: 0.001)
        XCTAssertEqual(rightLabel.y, ringCenter, accuracy: 0.001)
        XCTAssertEqual(leftLabel.x + rightLabel.x, ringCenter * 2, accuracy: 0.001)

        let longRightLabel = layout.labelPosition(for: .longRight)
        let shortLeftLabel = layout.labelPosition(for: .shortLeft)
        XCTAssertEqual(longRightLabel.x + shortLeftLabel.x, ringCenter * 2, accuracy: 0.001)
        XCTAssertEqual(longRightLabel.y + shortLeftLabel.y, ringCenter * 2, accuracy: 0.001)
    }

    func testShotOutcomeLayoutLabelsSitWithinSegmentBand() {
        let layout = FreshLiveRoundShotOutcomeLayout.standard
        let outerRadius = layout.ringDiameter / 2
        let innerRadius = outerRadius * layout.ringInnerRadiusRatio
        let ringCenter = CGPoint(x: outerRadius, y: outerRadius)

        for node in FreshLiveRoundShotOutcomeNode.allCases {
            let position = layout.labelPosition(for: node)
            let dx = position.x - ringCenter.x
            let dy = position.y - ringCenter.y
            let distanceFromCenter = (dx * dx + dy * dy).squareRoot()

            XCTAssertGreaterThanOrEqual(distanceFromCenter, innerRadius, "label for \(node) should sit at or beyond the inner edge")
            XCTAssertLessThanOrEqual(distanceFromCenter, outerRadius, "label for \(node) should not exceed the outer edge")
        }
    }

    func testShotOutcomeLayoutCenterButtonCircleFitsInsideTheInnerHole() {
        let layout = FreshLiveRoundShotOutcomeLayout.standard
        let innerRadius = (layout.ringDiameter / 2) * layout.ringInnerRadiusRatio
        // Center button is rendered as a Circle, so the visible radius is half its smaller dimension.
        let centerRadius = min(layout.centerButtonSize.width, layout.centerButtonSize.height) / 2

        XCTAssertLessThanOrEqual(centerRadius, innerRadius, "center button's visible circle should fit inside the ring's inner hole")
    }

    func testClubWheelKeepsSelectedClubAtTopOfRing() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.selectClubFromWheel(named: "SW")
        let anchor = CGRect(x: 24, y: 662, width: 132, height: 44)
        let layout = FreshLiveRoundClubWheelLayout.resolve(
            anchorFrame: anchor,
            safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
            containerSize: CGSize(width: 393, height: 852),
            entryCount: state.clubWheelEntries.count
        )
        let selectedIndex = try! XCTUnwrap(
            state.clubWheelEntries.firstIndex(where: { $0.clubName == state.selectedClubName })
        )
        let topOfRing = CGPoint(x: layout.center.x, y: layout.center.y - layout.segmentDistance)
        let distances = state.clubWheelEntries.indices.map { index -> CGFloat in
            let position = layout.entryPosition(
                for: index,
                count: state.clubWheelEntries.count,
                selectedIndex: selectedIndex,
                anchorFrame: anchor
            )
            return hypot(position.x - topOfRing.x, position.y - topOfRing.y)
        }

        let nearestIndex = distances.enumerated().min(by: { $0.element < $1.element })?.offset

        XCTAssertEqual(nearestIndex, selectedIndex)
    }

    func testClubWheelOrbitRingMatchesEntryOrbitDiameter() {
        let layout = FreshLiveRoundClubWheelLayout.resolve(
            anchorFrame: CGRect(x: 24, y: 662, width: 132, height: 44),
            safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
            containerSize: CGSize(width: 393, height: 852),
            entryCount: 11
        )

        XCTAssertEqual(layout.orbitRingDiameter, layout.segmentDistance * 2, accuracy: 0.001)
    }

    func testClubWheelChromeDiameterMatchesResolvedOuterRadius() {
        let layout = FreshLiveRoundClubWheelLayout.resolve(
            anchorFrame: CGRect(x: 24, y: 662, width: 132, height: 44),
            safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
            containerSize: CGSize(width: 393, height: 852),
            entryCount: 11
        )

        XCTAssertEqual(layout.chromeDiameter, layout.outerRadius * 2, accuracy: 0.001)
    }

    func testClubWheelResolvesToScreenCenterInsteadOfLauncherAnchor() {
        let containerSize = CGSize(width: 393, height: 852)
        let layout = FreshLiveRoundClubWheelLayout.resolve(
            anchorFrame: CGRect(x: 24, y: 662, width: 132, height: 44),
            safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
            containerSize: containerSize,
            entryCount: 11
        )

        XCTAssertEqual(layout.center.x, containerSize.width / 2, accuracy: 0.001)
        XCTAssertEqual(layout.center.y, containerSize.height / 2, accuracy: 0.001)
    }

    func testPresentShotLoggerUsesTeeSurfaceForOpeningShot() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentShotLogger()

        XCTAssertTrue(state.isShowingShotLogger)
        XCTAssertEqual(state.pendingShotSurface, .tee)
        XCTAssertNil(state.pendingShotDirection)
        XCTAssertNil(state.pendingShotDistance)
        XCTAssertNil(state.pendingShotStrike)
        XCTAssertEqual(state.pendingShotPenaltyCount, 0)
        XCTAssertEqual(state.pendingShotDropCount, 0)
        XCTAssertEqual(state.pendingShotClubName, "Driver")
        XCTAssertEqual(state.pendingShotStrokeNumber, 1)
        XCTAssertFalse(state.canConfirmPendingShot)
    }

    func testTeeShotHidesAtBallAction() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertFalse(state.showsAtBallAction)
        XCTAssertEqual(state.ballMarkStatus, .hidden)
        XCTAssertEqual(state.currentShotOriginSource, .tee)
    }

    func testAtBallBecomesAvailableAfterTeeShot() {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.97445, longitude: 145.03345),
                headingDegrees: 18,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)

        XCTAssertTrue(state.showsAtBallAction)
        XCTAssertEqual(state.ballMarkStatus, .available)
        XCTAssertEqual(state.currentShotOriginSource, .currentLocationFallback)
    }

    func testOpeningTeeShotOffersProvisionalBallShotType() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentShotLogger()

        XCTAssertTrue(state.availableShotTypes.contains(.provisionalBall))
    }

    func testNonOpeningShotHidesProvisionalBallShotType() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        state.presentShotLogger()

        XCTAssertFalse(state.availableShotTypes.contains(.provisionalBall))
    }

    func testExpandedLauncherUsesTallerLiveAndInspectionHeightsForActionGrid() {
        XCTAssertGreaterThan(FreshLiveRoundLauncherLayoutPolicy.liveActionsBaseHeight, 300)
        XCTAssertGreaterThan(FreshLiveRoundLauncherLayoutPolicy.liveExpandedBaseHeight, 550)
        XCTAssertEqual(FreshLiveRoundLauncherLayoutPolicy.inspectionActionsBaseHeight, FreshLiveRoundLauncherLayoutPolicy.liveActionsBaseHeight)
        XCTAssertEqual(FreshLiveRoundLauncherLayoutPolicy.inspectionExpandedBaseHeight, FreshLiveRoundLauncherLayoutPolicy.liveExpandedBaseHeight)
        XCTAssertGreaterThan(FreshLiveRoundLauncherLayoutPolicy.maxExpandedHeightRatio, 0.72)
    }

    func testTopPanelLayoutUsesRegularTwoRowPresentationOnTallerPhones() {
        let layout = FreshLiveRoundTopPanelLayout.resolve(
            containerSize: CGSize(width: 430, height: 932)
        )

        XCTAssertEqual(layout.density, .regular)
        XCTAssertGreaterThan(layout.panelMinHeight, 150)
        XCTAssertGreaterThan(layout.distanceCardMinHeight, 72)
    }

    func testTopPanelLayoutCompactsOnSmallerPhonesToProtectMapSpace() {
        let layout = FreshLiveRoundTopPanelLayout.resolve(
            containerSize: CGSize(width: 375, height: 667)
        )

        XCTAssertEqual(layout.density, .compact)
        XCTAssertLessThan(layout.panelMinHeight, 150)
        XCTAssertLessThan(layout.distanceValueFontSize, 24)
    }

    func testCompactTopPanelUsesShortHoleTitleThatKeepsNumberVisible() {
        XCTAssertEqual(
            FreshLiveRoundTopPanelLayout.compactHoleTitle(for: 12),
            "H12"
        )
    }

    func testRegularTopPanelCondensesHoleTitleOnNarrowPhonesToKeepHoleNumberVisible() {
        let layout = FreshLiveRoundTopPanelLayout.resolve(
            containerSize: CGSize(width: 393, height: 852)
        )

        XCTAssertEqual(layout.holeTitle(for: 2), "H2")
    }

    // MARK: - Phase-adaptive top-bar redesign

    func testTopBarPhaseMirrorsShotPhaseOnFreshTeeShot() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        // Stroke 0 + > 110 m to pin = `.teeShot`. Top-bar mirror.
        XCTAssertEqual(state.shotPhase, .teeShot)
        XCTAssertEqual(state.topBarPhase, .tee)
    }

    func testTopBarPhaseLeavesTeeBandAfterFirstShot() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertEqual(state.topBarPhase, .tee)
        // The shotPhase derivation pivots away from .teeShot once the
        // stroke counter ticks past 0; the exact post-tee band depends
        // on raw GPS-to-pin geometry which we don't control without
        // traced features. The contract test is just "stops being a
        // tee shot after the player swings" — and the satellite swap
        // (driver-rec → back-distance) keys off that.
        state.logShot(clubName: "Driver", distanceToTargetMeters: 250)
        XCTAssertNotEqual(state.topBarPhase, .tee)
    }

    func testTopBarHeroSubtitleHidesPlaysLikeWhenDeltaIsTrivial() {
        // No weather snapshot → plays-like delta is 0, hero subtitle
        // should hide rather than render "0 m plays" filler.
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.setClubAutoRecommendationEnabled(false)

        XCTAssertFalse(state.hasMeaningfulPlaysLikeDelta)
        XCTAssertNil(state.topBarHeroSubtitle)
    }

    func testTopBarHeroSubtitleSurfacesPlaysLikeOnApproachWhenDeltaIsMeaningful() async {
        // Mild head wind on a due-north hole — should push plays-like
        // beyond the ±2m threshold and the subtitle should call it out.
        let state = await makeStateWithDueNorthHoleAndWind(
            windCompassDirection: "N",
            windDirectionDegrees: 0,
            windSpeed: 25
        )
        // The harness leaves us on the tee for stroke 0, but the hole
        // is short (~210m) so we end up in `.approach`/`.scoring`.
        state.logShot(clubName: "Driver", distanceToTargetMeters: 60)

        XCTAssertTrue([LiveRoundState.TopBarPhase.approach, .scoring].contains(state.topBarPhase))
        XCTAssertTrue(state.hasMeaningfulPlaysLikeDelta)
        let subtitle = state.topBarHeroSubtitle
        XCTAssertNotNil(subtitle)
        XCTAssertTrue(subtitle?.contains("plays") == true, "Expected plays-like delta in subtitle, got \(subtitle ?? "nil")")
    }

    func testTopBarHeroSubtitleSwapsToStrokeCounterOnTheGreen() {
        // `distanceToPinMeters` is a stored heuristic on `LiveRoundState`
        // (it ticks down by ~32 m per logged shot rather than tracking
        // GPS), so the simplest deterministic way to get into
        // `.greenSide` is to seed it directly. Mirrors what
        // `confirmCurrentHole` / shot logging would eventually drive
        // anyway.
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.distanceToPinMeters = 5
        // Two prior strokes so the next-stroke counter renders as "3".
        state.logShot(clubName: "Wedge", distanceToTargetMeters: 100)
        state.logShot(clubName: "Wedge", distanceToTargetMeters: 30)
        state.distanceToPinMeters = 5

        XCTAssertEqual(state.topBarPhase, .greenSide)
        XCTAssertEqual(state.topBarHeroSubtitle, "Stroke 3 of par 4")
    }

    func testTopBarScoreChipReadsEvenParAndStrokeCounterMidHole() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertEqual(state.topBarScoreHeadline, "E")
        XCTAssertEqual(state.topBarScoreSubtitle, "Stroke 1")

        state.logShot(clubName: "Driver", distanceToTargetMeters: 250)
        XCTAssertEqual(state.topBarScoreHeadline, "E")
        XCTAssertEqual(state.topBarScoreSubtitle, "Stroke 2")
    }

    func testTopBarScoreChipShowsRecordedScoreWhenInspectingConfirmedHole() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [
                .init(number: 1, par: 4, features: []),
                .init(number: 2, par: 4, features: [])
            ],
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        // Birdie hole 1 → confirmed. `confirmCurrentHole` gates on the
        // full hole-summary form (score / putts / penalties / drops),
        // so we set every required field — mirrors the production
        // confirm-hole sheet flow used by other round-score tests.
        state.logShot(clubName: "Driver", distanceToTargetMeters: 250)
        state.presentHoleConfirmation()
        state.setPendingHoleScore(3)
        state.setPendingHolePutts(1)
        state.setPendingHolePenaltyCount(0)
        state.setPendingHoleDropCount(0)
        XCTAssertTrue(state.confirmCurrentHole())

        // confirmCurrentHole() auto-advances to hole 2; inspect the
        // previous hole so the displayed-hole geometry / score chip
        // points at the now-confirmed hole 1.
        state.inspectPreviousHole()

        XCTAssertEqual(state.topBarScoreHeadline, "-1")
        XCTAssertTrue(
            state.topBarScoreSubtitle.hasPrefix("Score "),
            "Expected Score subtitle, got \(state.topBarScoreSubtitle)"
        )
    }

    func testPlaysLikeDeltaSignedMetersCombinesWindAndTemperature() async {
        let state = await makeStateWithDueNorthHoleAndWind(
            windCompassDirection: "N",
            windDirectionDegrees: 0,
            windSpeed: 18,
            temperatureCelsius: 4
        )

        // Both head wind and cool air play the ball longer →
        // combined delta should be the sum of the two contributions
        // and strictly positive.
        XCTAssertEqual(
            state.playsLikeDeltaSignedMeters,
            state.playsLikeWindDeltaMeters + state.playsLikeTemperatureDeltaMeters
        )
        XCTAssertGreaterThan(state.playsLikeDeltaSignedMeters, 0)
    }

    func testTopPanelSubtitleIsParOnlySoItCannotEllipsiseInTheCluster() {
        // The hole-nav cluster sits between two fixed-width chips
        // on the new identity strip; any longer subtitle than
        // "Par 4" risked truncating to "Par 4 • …". We resolved
        // that by collapsing the subtitle to just par — the live
        // distance is carried by the PIN hero card directly below.
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            selectedTeeName: "Member",
            selectedTeeYards: 6420,
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertEqual(state.selectedTeeDistanceMeters, 5870, "Round-level tee total stays computable for other consumers")
        XCTAssertEqual(state.topPanelHoleSubtitle, "Par 4")
        XCTAssertFalse(state.topPanelHoleSubtitle.contains("•"), "Subtitle must stay single-component to dodge ellipsising")
        XCTAssertFalse(state.topPanelHoleSubtitle.contains("5870"), "Round-level course total must never appear in the per-hole subtitle")
    }

    func testTopPanelSubtitleReadsParThreeOnAParThreeHole() {
        let state = LiveRoundState(
            hole: HoleSession(number: 6, par: 3),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        XCTAssertEqual(state.topPanelHoleSubtitle, "Par 3")
    }

    func testShotLoggerUsesSystemSheetBackgroundBehavior() {
        XCTAssertTrue(FreshLiveRoundShotLoggerPresentationPolicy.usesSystemSheetBackground)
    }

    func testPostTeeWithoutLiveLocationDoesNotReportSyntheticCurrentLocationOrigin() {
        let provider = StubRoundLocationProvider(
            initialSnapshot: nil,
            status: .unavailable
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)

        XCTAssertTrue(state.showsAtBallAction)
        XCTAssertEqual(state.ballMarkStatus, .available)
        XCTAssertNil(state.currentShotOriginSource)
        XCTAssertNil(state.currentShotOriginCoordinate)

        state.presentShotLogger()
        state.selectShotDirection(.hit)
        state.selectShotDistance(.onNumber)
        state.selectShotStrike(.pure)
        state.confirmPendingShot()

        XCTAssertNil(state.lastLoggedShotOriginSource)
        XCTAssertNil(state.lastLoggedShotOriginCoordinate)
    }

    func testMarkBallStoresPreferredShotOrigin() throws {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.97445, longitude: 145.03345),
                headingDegrees: 18,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        state.markBall()

        XCTAssertEqual(state.ballMarkStatus, .marked)
        XCTAssertEqual(state.currentShotOriginSource, .ballMark)
        let origin = try XCTUnwrap(state.currentShotOriginCoordinate)
        XCTAssertEqual(origin.latitude, -37.97445)
        XCTAssertEqual(origin.longitude, 145.03345)
    }

    func testLoggingWithoutBallMarkFallsBackToCurrentLocationOrigin() throws {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.97445, longitude: 145.03345),
                headingDegrees: 18,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        state.presentShotLogger()
        state.selectShotDirection(.hit)
        state.selectShotDistance(.onNumber)
        state.selectShotStrike(.pure)
        state.confirmPendingShot()

        XCTAssertEqual(state.lastLoggedShotOriginSource, .currentLocationFallback)
        let origin = try XCTUnwrap(state.lastLoggedShotOriginCoordinate)
        XCTAssertEqual(origin.latitude, -37.97445)
        XCTAssertEqual(origin.longitude, 145.03345)
    }

    func testPendingShotDistanceLabelMatchesPinAfterPlanningTargetDrag() {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.975731, longitude: 145.033863),
                headingDegrees: 24,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        let staticTargetDistance = state.liveDistanceToSelectedTargetMeters
        state.movePlanningTarget(to: midwayCoordinate(player: state.playerCoordinate, target: state.targetCoordinate))

        XCTAssertEqual(
            state.pendingShotDistanceLabel,
            state.shortDistanceLabel(forMeters: state.displayedPinDistanceMeters)
        )
        XCTAssertNotEqual(state.planningCarryDistanceMeters, staticTargetDistance)
        XCTAssertNotEqual(state.planningCarryDistanceMeters, state.displayedPinDistanceMeters)
    }

    func testConfirmPendingShotLogsPinDistanceEvenWhenPlanningTargetDragged() throws {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.975731, longitude: 145.033863),
                headingDegrees: 24,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.movePlanningTarget(to: midwayCoordinate(player: state.playerCoordinate, target: state.targetCoordinate))
        let planningCarry = state.planningCarryDistanceMeters
        XCTAssertNotEqual(planningCarry, state.liveDistanceToSelectedTargetMeters)

        state.presentShotLogger()
        state.selectShotDirection(.hit)
        state.selectShotDistance(.onNumber)
        state.selectShotStrike(.pure)
        let pinDistanceAtConfirm = state.displayedPinDistanceMeters
        state.confirmPendingShot()

        let loggedShot = try XCTUnwrap(state.hole.shots.last)
        XCTAssertEqual(loggedShot.distanceToTargetMeters, pinDistanceAtConfirm)
        XCTAssertNotEqual(planningCarry, pinDistanceAtConfirm)
    }

    func testCurrentClubRemainsAvailableInCollapsedLauncherState() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertEqual(state.currentClubLauncherTitle, state.selectedClubName)
    }

    func testInspectionModeDisablesLiveLauncherActions() {
        let state = makeStateWithThreeHoles(activeHoleNumber: 2)

        state.inspectHole(at: 0)

        XCTAssertFalse(state.canPresentShotLogger)
        XCTAssertFalse(state.canMarkBallOnDisplayedHole)
        XCTAssertFalse(state.showsAtBallAction)
        XCTAssertFalse(state.showsFinishHoleInvoker)
    }

    func testInspectionModeIgnoresClubWheelPresentation() {
        let state = makeStateWithThreeHoles(activeHoleNumber: 2)

        state.inspectHole(at: 0)
        state.presentClubWheel()

        XCTAssertFalse(state.isShowingClubWheel)
    }

    func testLiveHoleShowsFinishHoleInvoker() {
        let state = makeStateWithThreeHoles(activeHoleNumber: 2)

        XCTAssertTrue(state.showsFinishHoleInvoker)
    }

    func testPresentHoleConfirmationSeedsPendingHoleSummaryAndShowsSheet() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        state.presentHoleConfirmation()

        XCTAssertTrue(state.isShowingHoleConfirmation)
        XCTAssertEqual(state.pendingHoleScore, 1)
        // With the redesign, putts/penalties/drops coerce derived
        // values to zero so the confirm button is immediately
        // actionable from the trimmed Quick-finish sheet (and the
        // watch's canFinishHole flips on).
        XCTAssertEqual(state.pendingHolePutts, 0)
        XCTAssertEqual(state.pendingHolePenaltyCount, 0)
        XCTAssertEqual(state.pendingHoleDropCount, 0)
        XCTAssertEqual(state.pendingHoleShotOutcomeSummary, "#1 Driver hit on number")
        XCTAssertEqual(state.pendingHoleClubCorrectionSummary, "Driver")
        XCTAssertNil(state.pendingHoleNotes)
        XCTAssertTrue(state.canConfirmHoleSummary)
    }

    func testConfirmCurrentHoleIsBlockedWhenSummaryFieldsAreNil() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        // No `presentHoleConfirmation()` call → pending* stay nil →
        // confirmation should be blocked.
        XCTAssertFalse(state.canConfirmHoleSummary)
        XCTAssertFalse(state.confirmCurrentHole())
        XCTAssertFalse(state.hole.isConfirmed)
    }

    func testConfirmCurrentHoleStoresPendingSummaryAndMarksHoleConfirmed() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        state.presentHoleConfirmation()
        state.setPendingHoleScore(4)
        state.setPendingHolePutts(2)
        state.setPendingHolePenaltyCount(1)
        state.setPendingHoleDropCount(1)
        state.setPendingHoleShotOutcomeSummary("Driver left, wedge got home")
        state.setPendingHoleClubCorrectionSummary("Driver, 54°")
        state.setPendingHoleNotes("Finished with a bunker save")

        XCTAssertTrue(state.confirmCurrentHole())
        XCTAssertTrue(state.hole.isConfirmed)
        XCTAssertEqual(state.hole.recordedScore, 4)
        XCTAssertEqual(state.hole.recordedPutts, 2)
        XCTAssertEqual(state.hole.recordedPenaltyCount, 1)
        XCTAssertEqual(state.hole.recordedDropCount, 1)
        XCTAssertEqual(state.hole.recordedShotOutcomeSummary, "Driver left, wedge got home")
        XCTAssertEqual(state.hole.recordedClubCorrectionSummary, "Driver, 54°")
        XCTAssertEqual(state.hole.recordedNotes, "Finished with a bunker save")
        XCTAssertFalse(state.isShowingHoleConfirmation)
    }

    func testConfirmCurrentHoleAdvancesToNextHoleWhenAvailable() {
        let state = makeStateWithThreeHoles(activeHoleNumber: 1)

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        state.presentHoleConfirmation()
        state.setPendingHoleScore(4)
        state.setPendingHolePutts(2)
        state.setPendingHolePenaltyCount(0)
        state.setPendingHoleDropCount(0)

        XCTAssertTrue(state.confirmCurrentHole())
        XCTAssertEqual(state.hole.number, 2)
        XCTAssertEqual(state.displayedHoleNumber, 2)
        XCTAssertTrue(state.snapshot.holeSessions[0].isConfirmed)
        XCTAssertEqual(state.snapshot.holeSessions[0].recordedScore, 4)
        XCTAssertEqual(state.snapshot.holeSessions[0].recordedPutts, 2)
    }

    func testAdvancingToNextHoleClearsPreviousBallMarkState() {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.97445, longitude: 145.03345),
                headingDegrees: 18,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [
                .init(number: 1, par: 4, features: []),
                .init(number: 2, par: 4, features: []),
                .init(number: 3, par: 3, features: [])
            ],
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        state.markBall()
        XCTAssertEqual(state.ballMarkStatus, .marked)
        XCTAssertEqual(state.currentShotOriginSource, .ballMark)

        state.presentHoleConfirmation()
        state.setPendingHoleScore(4)
        state.setPendingHolePutts(2)
        state.setPendingHolePenaltyCount(0)
        state.setPendingHoleDropCount(0)

        XCTAssertTrue(state.confirmCurrentHole())
        XCTAssertEqual(state.hole.number, 2)
        XCTAssertNil(state.ballMarkState)
        XCTAssertNil(state.ballMarkSuggestionBaselineCoordinate)
        XCTAssertEqual(state.ballMarkStatus, .hidden)
        XCTAssertEqual(state.currentShotOriginSource, .tee)

        state.logShot(clubName: "7i", distanceToTargetMeters: 152, surface: .tee)

        XCTAssertEqual(state.ballMarkStatus, .available)
        XCTAssertNotEqual(state.currentShotOriginSource, .ballMark)
    }

    func testConfirmingFinalHoleExitsLiveShotFlow() {
        let state = LiveRoundState(
            hole: HoleSession(number: 18, par: 4),
            courseHoles: [
                .init(number: 18, par: 4, features: [])
            ],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        state.presentHoleConfirmation()
        state.setPendingHoleScore(4)
        state.setPendingHolePutts(2)
        state.setPendingHolePenaltyCount(0)
        state.setPendingHoleDropCount(0)

        XCTAssertTrue(state.confirmCurrentHole())
        XCTAssertTrue(state.hole.isConfirmed)
        XCTAssertFalse(state.isDisplayedHoleLive)
        XCTAssertFalse(state.canPresentShotLogger)
        XCTAssertFalse(state.canAdjustTargetOnDisplayedHole)
        XCTAssertFalse(state.canMarkBallOnDisplayedHole)
    }

    func testEditingConfirmedHolePuttsAfterConfirmationSetsAuditFlag() {
        let state = makeStateWithThreeHoles(activeHoleNumber: 1)

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        state.presentHoleConfirmation()
        state.setPendingHoleScore(4)
        state.setPendingHolePutts(2)
        state.setPendingHolePenaltyCount(0)
        state.setPendingHoleDropCount(0)
        XCTAssertTrue(state.confirmCurrentHole())

        state.inspectPreviousHole()
        state.updateInspectedHolePutts(3)

        XCTAssertEqual(state.displayedHoleSession.recordedPutts, 3)
        XCTAssertTrue(state.displayedHoleSession.isConfirmed)
        XCTAssertTrue(state.displayedHoleSession.wasEditedAfterConfirmation)
    }

    func testPresentHoleConfirmationDerivesDropAndSummaryFieldsFromShotData() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.logShot(
            clubName: "Driver",
            distanceToTargetMeters: 214,
            penaltyCount: 1,
            dropCount: 1,
            surface: .tee,
            direction: .left,
            distanceResult: .short
        )
        state.logShot(
            clubName: "PW",
            distanceToTargetMeters: 94,
            surface: .fairway,
            direction: .hit,
            distanceResult: .onNumber,
            strikeResult: .pure
        )

        state.presentHoleConfirmation()

        XCTAssertEqual(state.pendingHolePenaltyCount, 1)
        XCTAssertEqual(state.pendingHoleDropCount, 1)
        XCTAssertEqual(
            state.pendingHoleShotOutcomeSummary,
            "#1 Driver left short\n#2 PW hit on number pure"
        )
        XCTAssertEqual(state.pendingHoleClubCorrectionSummary, "Driver, PW")
    }

    func testPresentShotLoggerUsesGreenSurfaceNearHole() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.distanceToPinMeters = 18
        state.presentShotLogger()

        XCTAssertEqual(state.pendingShotSurface, .green)
    }

    func testCurrentShotLoggerContextIsTeeOnOpeningStrokeRegardlessOfSurfaceInference() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentShotLogger()
        // suggestedShotSurface might fall back to fairway in test geometry,
        // but stroke 1 should always foreground the tee context.
        XCTAssertEqual(state.pendingShotStrokeNumber, 1)
        XCTAssertEqual(state.currentShotLoggerContext, .tee)
    }

    func testCurrentShotLoggerContextSwitchesToPuttOnceSurfaceIsGreen() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentShotLogger()
        state.selectShotSurface(.green)

        XCTAssertEqual(state.currentShotLoggerContext, .putt)
    }

    func testCurrentShotLoggerContextIsShotForFairwayMidHole() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        state.presentShotLogger()
        state.selectShotSurface(.fairway)

        XCTAssertEqual(state.currentShotLoggerContext, .shot)
    }

    func testPendingShotConfirmCTAAdaptsToContext() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentShotLogger()
        XCTAssertEqual(state.pendingShotConfirmCTAText, "Log tee shot")

        // Mid-hole approach.
        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        state.presentShotLogger()
        state.selectShotSurface(.fairway)
        XCTAssertEqual(state.pendingShotConfirmCTAText, "Log shot")

        // Putt context, no choice yet.
        state.selectShotSurface(.green)
        XCTAssertEqual(state.pendingShotConfirmCTAText, "Log putt")

        // Marked holed.
        state.setPendingShotPuttHoled(true)
        XCTAssertEqual(state.pendingShotConfirmCTAText, "Hole out")

        // Marked missed.
        state.setPendingShotPuttHoled(false)
        XCTAssertEqual(state.pendingShotConfirmCTAText, "Log missed putt")
    }

    func testPendingShotLieBannerTitleReflectsSelectedSurface() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.presentShotLogger()

        state.selectShotSurface(.tee)
        XCTAssertEqual(state.pendingShotLieBannerTitle, "Off the tee")
        state.selectShotSurface(.fairway)
        XCTAssertEqual(state.pendingShotLieBannerTitle, "From the fairway")
        state.selectShotSurface(.rough)
        XCTAssertEqual(state.pendingShotLieBannerTitle, "From the rough")
        state.selectShotSurface(.bunker)
        XCTAssertEqual(state.pendingShotLieBannerTitle, "From the bunker")
        state.selectShotSurface(.green)
        XCTAssertEqual(state.pendingShotLieBannerTitle, "On the green")
    }

    func testPuttContextRequiresHoledMissedChoiceBeforeConfirm() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.presentShotLogger()
        state.selectShotSurface(.green)

        XCTAssertFalse(state.canConfirmPendingShot)

        state.setPendingShotPuttHoled(false)
        XCTAssertTrue(state.canConfirmPendingShot)

        state.setPendingShotPuttHoled(nil)
        XCTAssertFalse(state.canConfirmPendingShot)

        state.setPendingShotPuttHoled(true)
        XCTAssertTrue(state.canConfirmPendingShot)
    }

    func testConfirmingHoledPuttPersistsHoledFlagAndShotType() throws {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.presentShotLogger()
        state.selectShotSurface(.green)
        state.setPendingShotPuttHoled(true)
        state.confirmPendingShot()

        let shot = try XCTUnwrap(state.hole.shots.last)
        XCTAssertEqual(shot.shotType, .putt)
        XCTAssertEqual(shot.surface, .green)
        XCTAssertEqual(shot.direction, .hit)
        XCTAssertEqual(shot.distanceResult, .onNumber)
        XCTAssertEqual(shot.puttDetail?.holed, true)
        XCTAssertNil(shot.puttDetail?.missDistanceMeters)
    }

    func testConfirmingMissedPuttPersistsMissDirectionAndDistance() throws {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.presentShotLogger()
        state.selectShotSurface(.green)
        state.setPendingShotPuttHoled(false)
        state.setPendingShotPuttMissOutcome(direction: .left, distance: .short)
        state.setPendingShotPuttMissDistanceMeters(2)
        state.confirmPendingShot()

        let shot = try XCTUnwrap(state.hole.shots.last)
        XCTAssertEqual(shot.shotType, .putt)
        XCTAssertEqual(shot.direction, .left)
        XCTAssertEqual(shot.distanceResult, .short)
        XCTAssertEqual(shot.puttDetail?.holed, false)
        XCTAssertEqual(shot.puttDetail?.missDistanceMeters, 2)
    }

    func testPuttMissOutcomeDialCanEncodeLongLeftFinishWithoutMeters() throws {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.presentShotLogger()
        state.selectShotSurface(.green)
        state.setPendingShotPuttHoled(false)
        // The "long-left" sector on the dial sets both axes in one tap.
        state.setPendingShotPuttMissOutcome(direction: .left, distance: .long)
        state.confirmPendingShot()

        let shot = try XCTUnwrap(state.hole.shots.last)
        XCTAssertEqual(shot.shotType, .putt)
        XCTAssertEqual(shot.direction, .left)
        XCTAssertEqual(shot.distanceResult, .long)
        XCTAssertNil(shot.puttDetail?.missDistanceMeters)
    }

    func testPuttMissOutcomeDialCardinalShortFinishLeavesDirectionNeutral() throws {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.presentShotLogger()
        state.selectShotSurface(.green)
        state.setPendingShotPuttHoled(false)
        // The "short" cardinal: distance only, direction stays neutral.
        state.setPendingShotPuttMissOutcome(direction: .hit, distance: .short)
        state.confirmPendingShot()

        let shot = try XCTUnwrap(state.hole.shots.last)
        XCTAssertEqual(shot.direction, .hit)
        XCTAssertEqual(shot.distanceResult, .short)
    }

    func testMarkingPuttHoledClearsPreviouslyEnteredMissFields() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.presentShotLogger()
        state.selectShotSurface(.green)
        state.setPendingShotPuttHoled(false)
        state.setPendingShotPuttMissOutcome(direction: .right, distance: .long)
        state.setPendingShotPuttMissDistanceMeters(3)

        state.setPendingShotPuttHoled(true)

        XCTAssertNil(state.pendingShotPuttMissDirection)
        XCTAssertNil(state.pendingShotPuttMissDistance)
        XCTAssertNil(state.pendingShotPuttMissDistanceMeters)
    }

    // MARK: - Bottom-tray redesign

    private func makeStateWithLoggedShots(_ count: Int = 1) -> LiveRoundState {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        for index in 0..<count {
            state.logShot(
                clubName: "Driver",
                distanceToTargetMeters: 200,
                strokeNumber: index + 1,
                surface: .tee
            )
        }
        return state
    }

    func testHoledPuttSeedsHoleConfirmationPillFromDerivedValues() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.logShot(clubName: "Driver", distanceToTargetMeters: 220, strokeNumber: 1, surface: .tee)
        state.logShot(clubName: "8i", distanceToTargetMeters: 130, strokeNumber: 2, surface: .fairway)
        state.logShot(
            clubName: "Putter",
            distanceToTargetMeters: 8,
            strokeNumber: 3,
            surface: .green,
            shotType: .putt,
            puttDetail: .init(puttCount: 1, firstPuttDistanceMeters: 8, holed: false)
        )

        state.presentShotLogger()
        state.selectShotSurface(.green)
        state.setPendingShotPuttHoled(true)
        state.confirmPendingShot()

        XCTAssertTrue(state.isShowingHoleConfirmationPill)
        XCTAssertEqual(state.pendingHoleScore, state.hole.strokeCount)
        XCTAssertEqual(state.pendingHolePutts, 2)
        XCTAssertFalse(state.hole.isConfirmed)
    }

    func testHoleConfirmationPillDismissesWhenAnotherShotIsLogged() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.logShot(clubName: "Driver", distanceToTargetMeters: 220, surface: .tee)
        state.presentShotLogger()
        state.selectShotSurface(.green)
        state.setPendingShotPuttHoled(true)
        state.confirmPendingShot()

        XCTAssertTrue(state.isShowingHoleConfirmationPill)

        state.logShot(clubName: "Putter", distanceToTargetMeters: 2, surface: .green, shotType: .putt)

        XCTAssertFalse(state.isShowingHoleConfirmationPill)
    }

    func testConfirmCurrentHoleFromDerivedValuesPersistsAggregatesAndClearsPill() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.logShot(clubName: "Driver", distanceToTargetMeters: 220, penaltyCount: 1, surface: .tee)
        state.logShot(
            clubName: "Putter",
            distanceToTargetMeters: 4,
            strokeNumber: 2,
            surface: .green,
            shotType: .putt,
            puttDetail: .init(puttCount: 1, holed: true)
        )
        state.presentShotLogger()
        state.selectShotSurface(.green)
        state.setPendingShotPuttHoled(true)
        state.confirmPendingShot()
        XCTAssertTrue(state.isShowingHoleConfirmationPill)
        let strokeCountBefore = state.hole.strokeCount

        let didConfirm = state.confirmCurrentHoleFromDerivedValues()

        XCTAssertTrue(didConfirm)
        XCTAssertFalse(state.isShowingHoleConfirmationPill)
        XCTAssertEqual(state.hole.recordedScore, strokeCountBefore)
        XCTAssertEqual(state.hole.recordedPenaltyCount, 1)
        XCTAssertNotNil(state.hole.recordedPutts)
        XCTAssertTrue(state.hole.isConfirmed)
    }

    func testEditHoleDraftDefaultsToDerivedValuesMidHole() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.logShot(clubName: "Driver", distanceToTargetMeters: 220, penaltyCount: 1, surface: .tee)
        state.logShot(
            clubName: "Putter",
            distanceToTargetMeters: 4,
            strokeNumber: 2,
            dropCount: 1,
            surface: .green,
            shotType: .putt,
            puttDetail: .init(puttCount: 1, holed: false)
        )

        let draft = state.makeCurrentHoleEditDraft()

        XCTAssertEqual(draft.score, max(state.hole.strokeCount, 1))
        XCTAssertEqual(draft.putts, 1, "Should derive putt count from logged putt shots")
        XCTAssertEqual(draft.penaltyCount, 1, "Should derive penalty total from per-shot penaltyCount")
        XCTAssertEqual(draft.dropCount, 1, "Should derive drop total from per-shot dropCount")
    }

    func testCanUndoLastShotIsTrueAfterLoggingFromActiveHole() {
        let state = makeStateWithLoggedShots(1)
        XCTAssertTrue(state.canUndoLastShot)
        XCTAssertNotNil(state.lastShotUndoSnapshot)
    }

    func testCanUndoLastShotIsFalseWithNoShotsLogged() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        XCTAssertFalse(state.canUndoLastShot)
        XCTAssertNil(state.lastShotUndoSnapshot)
    }

    func testPresentUndoConfirmationStagesPreviewOfLastShot() {
        let state = makeStateWithLoggedShots(1)
        let preview = state.presentUndoConfirmation()
        XCTAssertEqual(preview?.clubName, "Driver")
        XCTAssertEqual(state.pendingUndoPreview?.clubName, "Driver")
    }

    func testConfirmUndoLastShotPopsShotAndClearsSnapshot() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.logShot(clubName: "Driver", distanceToTargetMeters: 220, surface: .tee)
        XCTAssertEqual(state.hole.shots.count, 1)

        state.presentUndoConfirmation()
        let undone = state.confirmUndoLastShot()

        XCTAssertNotNil(undone)
        XCTAssertEqual(undone?.clubName, "Driver")
        XCTAssertEqual(state.hole.shots.count, 0)
        XCTAssertNil(state.lastShotUndoSnapshot)
        XCTAssertNil(state.pendingUndoPreview)
        XCTAssertEqual(state.lastUndoneShotPreview?.clubName, "Driver")
    }

    func testConfirmUndoLastShotRestoresPostConfirmDistanceShim() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.distanceToPinMeters = 200
        state.presentShotLogger()
        state.selectShotDirection(.hit)
        state.selectShotDistance(.onNumber)
        state.confirmPendingShot()
        XCTAssertEqual(state.distanceToPinMeters, max(0, 200 - 32), "confirmPendingShot applies a -32m shim")
        XCTAssertEqual(state.hole.shots.count, 1)

        state.presentUndoConfirmation()
        _ = state.confirmUndoLastShot()

        XCTAssertEqual(state.distanceToPinMeters, 200, "Undo restores the pre-shot distance")
        XCTAssertEqual(state.hole.shots.count, 0)
    }

    func testUndoingHoledPuttAlsoDismissesHoleConfirmationPill() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.logShot(clubName: "Driver", distanceToTargetMeters: 220, surface: .tee)
        state.presentShotLogger()
        state.selectShotSurface(.green)
        state.setPendingShotPuttHoled(true)
        state.confirmPendingShot()
        XCTAssertTrue(state.isShowingHoleConfirmationPill)

        state.presentUndoConfirmation()
        _ = state.confirmUndoLastShot()

        XCTAssertFalse(state.isShowingHoleConfirmationPill)
    }

    func testAcknowledgeUndoneShotPreviewClearsTheToast() {
        let state = makeStateWithLoggedShots(1)
        state.presentUndoConfirmation()
        _ = state.confirmUndoLastShot()
        XCTAssertNotNil(state.lastUndoneShotPreview)

        state.acknowledgeUndoneShotPreview()

        XCTAssertNil(state.lastUndoneShotPreview)
    }

    func testLoggingNewShotClearsLastUndoneShotToast() {
        let state = makeStateWithLoggedShots(1)
        state.presentUndoConfirmation()
        _ = state.confirmUndoLastShot()
        XCTAssertNotNil(state.lastUndoneShotPreview)

        state.logShot(clubName: "Driver", distanceToTargetMeters: 200, surface: .tee)

        XCTAssertNil(state.lastUndoneShotPreview)
    }

    func testLogQuickPenaltyAddsPenaltyShotWithCorrectStrokeNumber() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.logShot(clubName: "Driver", distanceToTargetMeters: 220, surface: .tee)

        state.logQuickPenalty(.lostBall)

        XCTAssertEqual(state.hole.shots.count, 2)
        let penalty = state.hole.shots.last
        XCTAssertEqual(penalty?.clubName, "Penalty")
        XCTAssertEqual(penalty?.penaltyCount, 1)
        XCTAssertEqual(penalty?.strokeNumber, 2)
        XCTAssertEqual(penalty?.note, "Lost ball penalty")
    }

    func testLogQuickPenaltyForUnplayableAlsoAddsADrop() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.logShot(clubName: "Driver", distanceToTargetMeters: 220, surface: .tee)
        state.logQuickPenalty(.unplayable)

        let penalty = state.hole.shots.last
        XCTAssertEqual(penalty?.penaltyCount, 1)
        XCTAssertEqual(penalty?.dropCount, 1)
    }

    func testQuickPenaltyPickerDismissesAfterLogging() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.presentQuickPenaltyPicker()
        XCTAssertTrue(state.isShowingQuickPenaltyPicker)

        state.logQuickPenalty(.water)

        XCTAssertFalse(state.isShowingQuickPenaltyPicker)
    }

    func testConfirmReteeAddsPenaltyAndResetsPendingShotForTeeReplay() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.logShot(clubName: "Driver", distanceToTargetMeters: 220, surface: .tee)
        state.presentShotLogger()
        state.selectShotSurface(.fairway)
        state.selectShotDirection(.left)

        state.confirmRetee()

        XCTAssertEqual(state.hole.shots.last?.clubName, "Penalty")
        XCTAssertEqual(state.hole.shots.last?.penaltyCount, 1)
        XCTAssertEqual(state.hole.shots.last?.note, "Re-tee")
        XCTAssertEqual(state.pendingShotSurface, .tee)
        XCTAssertNil(state.pendingShotDirection)
        XCTAssertNil(state.pendingShotDistance)
    }

    // MARK: - Shot history row classification

    func testShotHistoryClassifiesQuickPenaltyAsPenaltyKindWithReadableSubtitle() throws {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 220, surface: .tee)
        state.logQuickPenalty(.lostBall)

        let penalty = try XCTUnwrap(state.hole.shots.last)
        XCTAssertEqual(state.shotHistoryEntryKind(for: penalty), .penalty)
        // The user-facing copy has to surface the actual reason — *not*
        // "Hit • On Number", which is filler kept for analytics joins.
        XCTAssertEqual(state.shotHistorySubtitle(for: penalty), "Lost ball penalty • +1 stroke")
        XCTAssertNil(state.shotHistoryDetail(for: penalty))
    }

    func testShotHistoryPenaltySubtitleIncludesDropQualifierForReliefPenalties() throws {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 220, surface: .tee)
        // Unplayable / water carry a drop alongside the +1 stroke.
        state.logQuickPenalty(.unplayable)

        let penalty = try XCTUnwrap(state.hole.shots.last)
        XCTAssertEqual(state.shotHistorySubtitle(for: penalty), "Unplayable lie • +1 stroke • +1 drop")
    }

    func testShotHistoryClassifiesReteeAsPenaltyKind() throws {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 220, surface: .tee)
        state.confirmRetee()

        let retee = try XCTUnwrap(state.hole.shots.last)
        XCTAssertEqual(state.shotHistoryEntryKind(for: retee), .penalty)
        XCTAssertEqual(state.shotHistorySubtitle(for: retee), "Re-tee • +1 stroke")
    }

    func testShotHistoryClassifiesHoledPuttWithDedicatedSubtitle() throws {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.presentShotLogger()
        state.selectShotSurface(.green)
        state.setPendingShotPuttHoled(true)
        state.confirmPendingShot()

        let putt = try XCTUnwrap(state.hole.shots.last)
        XCTAssertEqual(state.shotHistoryEntryKind(for: putt), .putt)
        XCTAssertEqual(state.shotHistorySubtitle(for: putt), "Holed")
    }

    func testShotHistoryMissedPuttSubtitleSurfacesDirectionDistanceAndMeters() throws {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.presentShotLogger()
        state.selectShotSurface(.green)
        state.setPendingShotPuttHoled(false)
        state.setPendingShotPuttMissOutcome(direction: .left, distance: .long)
        state.setPendingShotPuttMissDistanceMeters(2)
        state.confirmPendingShot()

        let putt = try XCTUnwrap(state.hole.shots.last)
        XCTAssertEqual(state.shotHistorySubtitle(for: putt), "Missed • Left · Long · 2m")
    }

    func testShotHistoryRegularShotSubtitleRetainsLegacyTriple() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.logShot(
            clubName: "8i",
            distanceToTargetMeters: 152,
            strokeNumber: 2,
            surface: .fairway,
            direction: .right,
            distanceResult: .short
        )

        let shot = state.hole.shots.last!
        XCTAssertEqual(state.shotHistoryEntryKind(for: shot), .shot)
        XCTAssertEqual(state.shotHistorySubtitle(for: shot), "152m • Right • Short")
    }

    func testShotHistoryRegularShotSubtitleAppendsInlinePenaltyAndDrop() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.logShot(
            clubName: "8i",
            distanceToTargetMeters: 152,
            strokeNumber: 2,
            penaltyCount: 1,
            dropCount: 1,
            surface: .fairway,
            direction: .hit,
            distanceResult: .onNumber
        )

        let shot = state.hole.shots.last!
        XCTAssertEqual(
            state.shotHistorySubtitle(for: shot),
            "152m • Hit • On number · +1 penalty · +1 drop"
        )
    }

    func testAdvancingToNextHoleClearsUndoSnapshotAndPill() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.logShot(clubName: "Driver", distanceToTargetMeters: 220, surface: .tee)
        state.presentShotLogger()
        state.selectShotSurface(.green)
        state.setPendingShotPuttHoled(true)
        state.confirmPendingShot()
        XCTAssertNotNil(state.lastShotUndoSnapshot)

        XCTAssertTrue(state.confirmCurrentHoleFromDerivedValues())

        XCTAssertNil(state.lastShotUndoSnapshot)
        XCTAssertNil(state.lastUndoneShotPreview)
        XCTAssertNil(state.pendingUndoPreview)
        XCTAssertFalse(state.isShowingHoleConfirmationPill)
    }

    func testPresentShotLoggerUsesBunkerSurfaceWhenPlayerIsInsideBunkerFeature() {
        let bunker = SwingPalCourse.Hole.Feature(
            kind: .bunker,
            label: "Front right bunker",
            coordinates: [
                .init(latitude: -37.97455, longitude: 145.03335),
                .init(latitude: -37.97455, longitude: 145.03355),
                .init(latitude: -37.97435, longitude: 145.03355),
                .init(latitude: -37.97435, longitude: 145.03335)
            ]
        )
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.97445, longitude: 145.03345),
                headingDegrees: 18,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            holeFeatures: [bunker],
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.presentShotLogger()

        XCTAssertEqual(state.pendingShotSurface, .bunker)
        XCTAssertEqual(state.pendingShotSurfaceReasonTitle, "Mapped lie detected")
        XCTAssertEqual(state.pendingShotSurfaceReasonText, "You are inside Front right bunker, so SwingPal starts the shot from bunker.")
    }

    func testPresentShotLoggerUsesFairwaySurfaceWhenPlayerIsInsideFairwayFeature() {
        let fairway = SwingPalCourse.Hole.Feature(
            kind: .fairway,
            label: "Primary fairway",
            coordinates: [
                .init(latitude: -37.97455, longitude: 145.03335),
                .init(latitude: -37.97455, longitude: 145.03375),
                .init(latitude: -37.97415, longitude: 145.03375),
                .init(latitude: -37.97415, longitude: 145.03335)
            ]
        )
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.97435, longitude: 145.03355),
                headingDegrees: 22,
                horizontalAccuracyMeters: 4
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            holeFeatures: [fairway],
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.distanceToPinMeters = 18
        state.presentShotLogger()

        XCTAssertEqual(state.pendingShotSurface, .fairway)
        XCTAssertEqual(state.pendingShotSurfaceReasonTitle, "Mapped lie detected")
        XCTAssertEqual(state.pendingShotSurfaceReasonText, "You are inside Primary fairway, so SwingPal starts the shot from fairway.")
    }

    func testPresentShotLoggerExplainsPhaseBasedFallbackWhenNoFeatureMatchExists() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.distanceToPinMeters = 72
        state.presentShotLogger()

        XCTAssertEqual(state.pendingShotSurface, .fairway)
        XCTAssertEqual(state.pendingShotSurfaceReasonTitle, "Phase-based starting lie")
        XCTAssertEqual(state.pendingShotSurfaceReasonText, "Scoring zone defaults to fairway until mapped lie data says otherwise.")
    }

    func testConfirmPendingShotLogsSelectedSurfaceAndDismissesLogger() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.selectClub(named: "5W")
        state.presentShotLogger()
        let expectedDistance = state.displayedPinDistanceMeters
        state.selectShotSurface(.rough)
        state.selectShotDirection(.hit)
        state.selectShotDistance(.onNumber)
        state.setPendingShotStrokeNumber(2)
        state.setPendingShotPenaltyCount(1)
        state.setPendingShotDropCount(1)
        state.confirmPendingShot()

        XCTAssertFalse(state.isShowingShotLogger)
        XCTAssertEqual(state.hole.shots.first?.clubName, "5W")
        XCTAssertEqual(state.hole.shots.first?.surface, .rough)
        XCTAssertEqual(state.hole.shots.first?.distanceToTargetMeters, expectedDistance)
        XCTAssertEqual(state.hole.shots.first?.strokeNumber, 2)
        XCTAssertEqual(state.hole.shots.first?.penaltyCount, 1)
        XCTAssertEqual(state.hole.shots.first?.dropCount, 1)
    }

    func testConfirmPendingShotStoresBasicLoggerFields() throws {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentShotLogger()
        state.selectShotDirection(.left)
        state.selectShotDistance(.short)
        state.setPendingShotStrokeNumber(3)
        state.setPendingShotPenaltyCount(2)
        state.setPendingShotDropCount(1)
        state.confirmPendingShot()

        let shot = try XCTUnwrap(state.hole.shots.last)
        XCTAssertEqual(shot.direction, .left)
        XCTAssertEqual(shot.distanceResult, .short)
        XCTAssertEqual(shot.strokeNumber, 3)
        XCTAssertEqual(shot.penaltyCount, 2)
        XCTAssertEqual(shot.dropCount, 1)
        XCTAssertNil(shot.shotType)
        XCTAssertNil(shot.strikeResult)
        XCTAssertNil(shot.puttDetail)
        XCTAssertNil(shot.note)
    }

    func testConfirmPendingShotStoresStrikeAndNoteWhenAddDetailIsUsed() throws {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        // Stroke 2 onwards is "shot" context — direction + distance gate.
        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        state.presentShotLogger()
        state.selectShotSurface(.fairway)
        state.selectShotDirection(.hit)
        state.selectShotDistance(.onNumber)
        state.selectShotStrike(.pure)
        state.setPendingShotNote("Solid 7-iron")
        state.confirmPendingShot()

        let shot = try XCTUnwrap(state.hole.shots.last)
        XCTAssertEqual(shot.surface, .fairway)
        XCTAssertEqual(shot.strikeResult, .pure)
        XCTAssertEqual(shot.note, "Solid 7-iron")
    }

    func testConfirmingPuttWithoutMissDistanceLeavesItNil() throws {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentShotLogger()
        state.selectShotSurface(.green)
        state.setPendingShotPuttHoled(false)
        state.confirmPendingShot()

        let shot = try XCTUnwrap(state.hole.shots.last)
        XCTAssertEqual(shot.shotType, .putt)
        XCTAssertEqual(shot.puttDetail?.holed, false)
        XCTAssertNil(shot.puttDetail?.missDistanceMeters)
    }

    func testConfirmPendingShotAllowsManualClubOverride() throws {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.selectClub(named: "Driver")
        state.presentShotLogger()
        state.overridePendingShotClubName("5W")
        state.selectShotDirection(.right)
        state.selectShotDistance(.long)
        state.confirmPendingShot()

        let shot = try XCTUnwrap(state.hole.shots.last)
        XCTAssertEqual(shot.clubName, "5W")
        XCTAssertEqual(state.selectedClubName, "Driver")
    }

    func testShotLoggerRequiresDirectionAndDistanceBeforeConfirm() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentShotLogger()
        XCTAssertFalse(state.canConfirmPendingShot)

        state.selectShotDirection(.hit)
        XCTAssertFalse(state.canConfirmPendingShot)

        state.selectShotDistance(.onNumber)
        XCTAssertTrue(state.canConfirmPendingShot)
    }

    func testPresentShotLoggerResetsPendingStructuredSelections() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentShotLogger()
        state.overridePendingShotClubName("5W")
        state.selectShotDirection(.right)
        state.selectShotDistance(.long)
        state.selectShotStrike(.hook)
        state.setPendingShotType(.recovery)
        state.setPendingShotPenaltyCount(2)
        state.setPendingShotDropCount(1)
        state.setPendingShotPuttHoled(false)
        state.setPendingShotPuttMissOutcome(direction: .left, distance: .long)
        state.setPendingShotPuttMissDistanceMeters(2)
        state.setPendingShotNote("Forced punch-out")
        state.setShotLoggerAddDetailVisibility(true)
        state.dismissShotLogger()

        state.presentShotLogger()

        XCTAssertEqual(state.pendingShotClubName, state.selectedClubName)
        XCTAssertNil(state.pendingShotDirection)
        XCTAssertNil(state.pendingShotDistance)
        XCTAssertNil(state.pendingShotStrike)
        XCTAssertNil(state.pendingShotType)
        XCTAssertEqual(state.pendingShotPenaltyCount, 0)
        XCTAssertEqual(state.pendingShotDropCount, 0)
        XCTAssertNil(state.pendingShotNote)
        XCTAssertNil(state.pendingShotPuttHoled)
        XCTAssertNil(state.pendingShotPuttMissDirection)
        XCTAssertNil(state.pendingShotPuttMissDistance)
        XCTAssertNil(state.pendingShotPuttMissDistanceMeters)
        XCTAssertFalse(state.isShowingShotLoggerAddDetail)
        XCTAssertFalse(state.canConfirmPendingShot)
    }

    func testConfirmPendingShotStoresLoggerContextIncludingOriginSourceAndSelectedTarget() throws {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.97445, longitude: 145.03345),
                headingDegrees: 18,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        state.markBall()
        state.presentShotLogger()
        state.selectShotDirection(.left)
        state.selectShotDistance(.short)
        state.confirmPendingShot()

        XCTAssertEqual(state.lastLoggedShotOriginSource, .ballMark)
        XCTAssertEqual(state.lastLoggedShotTargetLabel, "Pin")
        let target = try XCTUnwrap(state.lastLoggedShotTargetCoordinate)
        XCTAssertEqual(target.latitude, state.planningTargetCoordinate.latitude, accuracy: 0.000001)
        XCTAssertEqual(target.longitude, state.planningTargetCoordinate.longitude, accuracy: 0.000001)
    }

    func testAtBallSuggestionWaitsForMeaningfulMovement() {
        let provider = StubRoundLocationProvider(initialSnapshot: nil, status: .locating)
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)

        XCTAssertFalse(state.shouldSuggestBallMark)

        let tee = state.teeCoordinate
        func pushOffset(lat: Double, lon: Double) {
            provider.push(
                .init(
                    coordinate: .init(latitude: tee.latitude + lat, longitude: tee.longitude + lon),
                    headingDegrees: 18,
                    horizontalAccuracyMeters: 5
                )
            )
        }

        pushOffset(lat: 0.00005, lon: 0)
        waitForMainQueueFlush()
        XCTAssertFalse(state.shouldSuggestBallMark)

        pushOffset(lat: 0.0001, lon: 0.00001)
        waitForMainQueueFlush()
        XCTAssertFalse(state.shouldSuggestBallMark)

        pushOffset(lat: 0.0003, lon: 0.00002)
        waitForMainQueueFlush()
        XCTAssertTrue(state.shouldSuggestBallMark)
    }

    func testMarkBallClearsContextualAtBallSuggestion() {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.97445, longitude: 145.03345),
                headingDegrees: 18,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)
        provider.push(
            .init(
                coordinate: .init(latitude: -37.97415, longitude: 145.03368),
                headingDegrees: 27,
                horizontalAccuracyMeters: 5
            )
        )
        XCTAssertTrue(state.shouldSuggestBallMark)

        state.markBall()

        XCTAssertFalse(state.shouldSuggestBallMark)
    }

    func testAtBallSuggestionFallsBackToTeeOriginWhenGpsIsUnavailableAtLogTime() throws {
        let provider = StubRoundLocationProvider(
            initialSnapshot: nil,
            status: .unavailable
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.logShot(clubName: "Driver", distanceToTargetMeters: 214, surface: .tee)

        let baseline = try XCTUnwrap(state.ballMarkSuggestionBaselineCoordinate)
        XCTAssertEqual(baseline.latitude, state.teeCoordinate.latitude, accuracy: 0.000001)
        XCTAssertEqual(baseline.longitude, state.teeCoordinate.longitude, accuracy: 0.000001)
        XCTAssertFalse(state.shouldSuggestBallMark)

        provider.push(
            .init(
                coordinate: .init(latitude: state.teeCoordinate.latitude + 0.00030, longitude: state.teeCoordinate.longitude + 0.00030),
                headingDegrees: 33,
                horizontalAccuracyMeters: 5
            )
        )

        waitForMainQueueFlush()
        XCTAssertTrue(state.shouldSuggestBallMark)
    }

    func testHUDLanguageDescribesAimAndPinDistances() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertEqual(state.liveDistanceCaption, "Meters to aim")
        XCTAssertEqual(state.planningRemainingCaption, "Remain to pin")
    }

    func testLiveRoundStartsCollapsedWithBothContextPillRows() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertEqual(state.launcherDetent, .collapsed)
        XCTAssertEqual(state.primaryContextPills.count, 2)
        XCTAssertEqual(state.secondaryContextPills.count, 2)
    }

    func testLauncherSnapPolicyKeepsCollapsedTrayCollapsedForSmallUpwardDrag() {
        let heights = FreshLiveRoundLauncherDetentHeights(
            collapsed: 160,
            actions: 360,
            expanded: 620
        )

        let detent = FreshLiveRoundLauncherSnapPolicy.targetDetent(
            from: .collapsed,
            translation: -20,
            predictedEndTranslation: -24,
            heights: heights
        )

        XCTAssertEqual(detent, .collapsed)
    }

    func testLauncherSnapPolicyAdvancesCollapsedTrayByOnlyOneDetent() {
        let heights = FreshLiveRoundLauncherDetentHeights(
            collapsed: 160,
            actions: 360,
            expanded: 620
        )

        let detent = FreshLiveRoundLauncherSnapPolicy.targetDetent(
            from: .collapsed,
            translation: -260,
            predictedEndTranslation: -340,
            heights: heights
        )

        XCTAssertEqual(detent, .actions)
    }

    func testLauncherSnapPolicyAdvancesActionsTrayToExpandedOnStrongUpwardDrag() {
        let heights = FreshLiveRoundLauncherDetentHeights(
            collapsed: 160,
            actions: 360,
            expanded: 620
        )

        let detent = FreshLiveRoundLauncherSnapPolicy.targetDetent(
            from: .actions,
            translation: -120,
            predictedEndTranslation: -180,
            heights: heights
        )

        XCTAssertEqual(detent, .expanded)
    }

    func testLauncherSnapPolicyRetreatsExpandedTrayByOnlyOneDetent() {
        let heights = FreshLiveRoundLauncherDetentHeights(
            collapsed: 160,
            actions: 360,
            expanded: 620
        )

        let detent = FreshLiveRoundLauncherSnapPolicy.targetDetent(
            from: .expanded,
            translation: 260,
            predictedEndTranslation: 340,
            heights: heights
        )

        XCTAssertEqual(detent, .actions)
    }

    func testInspectingPreviousHoleEntersInspectionMode() {
        let state = makeStateWithThreeHoles(activeHoleNumber: 2)

        state.inspectHole(at: 0)

        XCTAssertTrue(state.isInspectingHole)
        XCTAssertEqual(state.displayedHoleNumber, 1)
        XCTAssertFalse(state.isDisplayedHoleLive)
    }

    func testInspectingAnotherHoleDisablesLiveShotAndTargetingAffordances() {
        let state = makeStateWithThreeHoles(activeHoleNumber: 2)

        state.inspectNextHole()

        XCTAssertTrue(state.isInspectingHole)
        XCTAssertFalse(state.canLogLiveShotOnDisplayedHole)
        XCTAssertFalse(state.canAdjustTargetOnDisplayedHole)
    }

    func testInspectionModePreferredMapRegionUsesDisplayedHoleFraming() {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.9650, longitude: 145.0500),
                headingDegrees: 24,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 2, par: 3),
            courseHoles: [
                .init(
                    number: 1,
                    par: 4,
                    features: [
                        .init(
                            kind: .tee,
                            label: "Hole 1 tee",
                            coordinates: [
                                .init(latitude: -37.9759, longitude: 145.0331),
                                .init(latitude: -37.9759, longitude: 145.0333),
                                .init(latitude: -37.9757, longitude: 145.0333),
                                .init(latitude: -37.9757, longitude: 145.0331)
                            ]
                        ),
                        .init(
                            kind: .green,
                            label: "Hole 1 green",
                            coordinates: [
                                .init(latitude: -37.9738, longitude: 145.0340),
                                .init(latitude: -37.9738, longitude: 145.0342),
                                .init(latitude: -37.9736, longitude: 145.0342),
                                .init(latitude: -37.9736, longitude: 145.0340)
                            ]
                        )
                    ]
                ),
                .init(
                    number: 2,
                    par: 3,
                    features: [
                        .init(
                            kind: .tee,
                            label: "Hole 2 tee",
                            coordinates: [
                                .init(latitude: -37.9729, longitude: 145.0388),
                                .init(latitude: -37.9729, longitude: 145.0390),
                                .init(latitude: -37.9727, longitude: 145.0390),
                                .init(latitude: -37.9727, longitude: 145.0388)
                            ]
                        ),
                        .init(
                            kind: .green,
                            label: "Hole 2 green",
                            coordinates: [
                                .init(latitude: -37.9711, longitude: 145.0401),
                                .init(latitude: -37.9711, longitude: 145.0403),
                                .init(latitude: -37.9709, longitude: 145.0403),
                                .init(latitude: -37.9709, longitude: 145.0401)
                            ]
                        )
                    ]
                )
            ],
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.inspectPreviousHole()

        XCTAssertTrue(state.isInspectingHole)
        XCTAssertEqual(state.preferredMapRegion.center.latitude, state.displayedHoleRegion.center.latitude, accuracy: 0.000001)
        XCTAssertEqual(state.preferredMapRegion.center.longitude, state.displayedHoleRegion.center.longitude, accuracy: 0.000001)
        XCTAssertEqual(state.preferredMapRegion.span.latitudeDelta, state.displayedHoleRegion.span.latitudeDelta, accuracy: 0.000001)
        XCTAssertEqual(state.preferredMapRegion.span.longitudeDelta, state.displayedHoleRegion.span.longitudeDelta, accuracy: 0.000001)
    }

    func testDisplayedFrontAndBackAnchorOnPinDistanceWithGreenPolygonDepth() {
        // Real-world bug: on Medway hole 1 PIN read 152 m while
        // FRONT and BACK both reported 388 m — `playerCoordinate`
        // was falling back to the course centroid (~388 m from
        // the green) so front/back lived in a totally different
        // reference frame from PIN.
        //
        // The anchored model: front/back must = pin ± the actual
        // depth of the green polygon along the tee→pin axis. We
        // verify with a synthetic ~13 m deep green that brackets
        // the user-set pin distance.
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 1 tee",
            coordinates: [
                .init(latitude: -37.9759, longitude: 145.0331)
            ]
        )
        // Green polygon is a small north-stretched rectangle so
        // its tee→pin axis depth is ~13 m. Centroid ≈ -37.9747.
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.97470, longitude: 145.0335),
                .init(latitude: -37.97476, longitude: 145.0337),
                .init(latitude: -37.97464, longitude: 145.0337),
                .init(latitude: -37.97464, longitude: 145.0335)
            ]
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [.init(number: 1, par: 4, features: [tee, green])],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        // Force a known pin distance independent of GPS so the
        // test reads as a contract on the anchored model rather
        // than on geometry maths.
        state.distanceToPinMeters = 154

        XCTAssertEqual(state.displayedPinDistanceMeters, 154)
        XCTAssertLessThan(state.displayedFrontDistanceMeters, state.displayedPinDistanceMeters, "Front must sit closer to the player than the pin")
        XCTAssertGreaterThan(state.displayedBackDistanceMeters, state.displayedPinDistanceMeters, "Back must sit farther from the player than the pin")
        XCTAssertGreaterThan(state.displayedBackDistanceMeters, state.displayedFrontDistanceMeters)

        // Green depth along the shot line is bounded — front/back
        // should bracket pin within a sensible range (typical PGA
        // greens are 25–35 m deep; this synthetic one is smaller).
        let greenDepth = state.displayedBackDistanceMeters - state.displayedFrontDistanceMeters
        XCTAssertGreaterThan(greenDepth, 0)
        XCTAssertLessThan(greenDepth, 80, "A real green is never bigger than ~30 m; an 80 m cap catches reference-frame regressions")
    }

    func testDisplayedFrontAndBackCollapseToPinWhenNoGreenGeometryIsAvailable() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.distanceToPinMeters = 154

        XCTAssertEqual(state.displayedPinDistanceMeters, 154)
        XCTAssertEqual(state.displayedFrontDistanceMeters, state.displayedPinDistanceMeters)
        XCTAssertEqual(state.displayedBackDistanceMeters, state.displayedPinDistanceMeters)
    }

    func testDisplayedDistancesClampToHoleMaxWhenPlayerIsWayOffCourse() {
        // Real-world: a player launches the round simulator with a sim
        // location set to e.g. Cupertino while the course is in
        // Melbourne. Without clamping the front/pin/back numbers blow
        // up to "25,974 m" which is useless. The clamp brings the
        // displayed distances back down to the hole's tee→back
        // envelope (with an 8% buffer) so the HUD shows something
        // sensible.
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 1 tee",
            coordinates: [
                .init(latitude: -37.9759, longitude: 145.0331),
                .init(latitude: -37.9759, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0331)
            ]
        )
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.9738, longitude: 145.0340),
                .init(latitude: -37.9738, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0340)
            ]
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [.init(number: 1, par: 4, features: [tee, green])],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        // Way off course: 25 km from the hole.
        state.distanceToPinMeters = 25_974

        guard let max = state.displayedHoleMaxReasonableDistanceMeters else {
            XCTFail("Expected a non-nil hole max for a hole with traced geometry")
            return
        }

        // The hole's tee→back is ~260 m, so the clamp should bring
        // pin/front/back well below the 25 km input.
        XCTAssertLessThan(max, 1_000)
        XCTAssertEqual(state.displayedPinDistanceMeters, max)
        XCTAssertLessThanOrEqual(state.displayedFrontDistanceMeters, max)
        XCTAssertLessThanOrEqual(state.displayedBackDistanceMeters, max)
    }

    func testShotOriginFallsBackToTeeWhenPlayerIsBehindTeebox() {
        // Real-world scenario: simulator location set to Cupertino while
        // the round is on a Melbourne course. The aim line from the
        // player would otherwise stretch across the world; we want it
        // to anchor at the tee instead.
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 1 tee",
            coordinates: [
                .init(latitude: -37.9759, longitude: 145.0331),
                .init(latitude: -37.9759, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0331)
            ]
        )
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.9738, longitude: 145.0340),
                .init(latitude: -37.9738, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0340)
            ]
        )
        // Player parked in Cupertino — far further from the (Melbourne)
        // pin than the Melbourne tee is.
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: 37.3318, longitude: -122.0312),
                headingDegrees: 0,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [.init(number: 1, par: 4, features: [tee, green])],
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        let teeCoord = state.teeCoordinate
        let origin = state.shotOriginCoordinate
        XCTAssertEqual(origin.latitude, teeCoord.latitude, accuracy: 0.000001)
        XCTAssertEqual(origin.longitude, teeCoord.longitude, accuracy: 0.000001)
    }

    func testShotOriginUsesPlayerWhenTheyAreOnTheHole() {
        // Player is comfortably inside the hole envelope (somewhere on
        // the fairway), so the aim line should originate from their
        // actual position — that's the whole point of the live HUD.
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 1 tee",
            coordinates: [
                .init(latitude: -37.9759, longitude: 145.0331),
                .init(latitude: -37.9759, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0331)
            ]
        )
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.9738, longitude: 145.0340),
                .init(latitude: -37.9738, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0340)
            ]
        )
        // Halfway between the tee and the pin — definitely "on the hole".
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.9748, longitude: 145.0336),
                headingDegrees: 14,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [.init(number: 1, par: 4, features: [tee, green])],
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        let player = state.playerCoordinate
        let origin = state.shotOriginCoordinate
        XCTAssertEqual(origin.latitude, player.latitude, accuracy: 0.000001)
        XCTAssertEqual(origin.longitude, player.longitude, accuracy: 0.000001)
    }

    // MARK: - View green / approach inspection camera

    func testGreenInspectionCameraSpecCentersOnGreenCentroid() throws {
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 1 tee",
            coordinates: [
                .init(latitude: -37.9759, longitude: 145.0331),
                .init(latitude: -37.9759, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0331)
            ]
        )
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.9738, longitude: 145.0340),
                .init(latitude: -37.9738, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0340)
            ]
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [.init(number: 1, par: 4, features: [tee, green])],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        let spec = try XCTUnwrap(state.greenInspectionCameraSpec)
        // The 4-vertex green polygon is a tiny axis-aligned rectangle —
        // centroid is the simple coordinate average. Anchor copy here
        // so future polygon-tessellation refactors can't silently
        // shift the camera off the green.
        XCTAssertEqual(spec.center.latitude, -37.9737, accuracy: 0.00001)
        XCTAssertEqual(spec.center.longitude, 145.0341, accuracy: 0.00001)

        XCTAssertNotNil(state.greenInspectionPanLimits)
    }

    func testGreenInspectionCameraSpecHeadingMatchesShotOriginToGreenBearing() throws {
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 1 tee",
            coordinates: [
                .init(latitude: -37.9759, longitude: 145.0331),
                .init(latitude: -37.9759, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0331)
            ]
        )
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.9738, longitude: 145.0340),
                .init(latitude: -37.9738, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0340)
            ]
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [.init(number: 1, par: 4, features: [tee, green])],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        let spec = try XCTUnwrap(state.greenInspectionCameraSpec)
        let expectedHeading = LiveRoundState.bearing(
            from: state.shotOriginCoordinate,
            to: CLLocationCoordinate2D(latitude: -37.9737, longitude: 145.0341)
        )
        XCTAssertEqual(spec.heading, expectedHeading, accuracy: 0.5)
    }

    func testGreenInspectionCameraSpecDistanceScalesWithGreenDiameter() throws {
        // Two greens, identical centroids, but the second is ~3× wider
        // than the first. The camera distance should grow with the
        // green's bbox diagonal so a giant plateau green still fits in
        // frame and a tiny tucked green doesn't get drowned in fairway.
        let smallGreen = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Small green",
            coordinates: [
                .init(latitude: -37.9738, longitude: 145.0340),
                .init(latitude: -37.9738, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0340)
            ]
        )
        let largeGreen = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Plateau green",
            coordinates: [
                .init(latitude: -37.9742, longitude: 145.0335),
                .init(latitude: -37.9742, longitude: 145.0347),
                .init(latitude: -37.9732, longitude: 145.0347),
                .init(latitude: -37.9732, longitude: 145.0335)
            ]
        )
        let origin = CLLocationCoordinate2D(latitude: -37.9759, longitude: 145.0331)

        let smallSpec = try XCTUnwrap(LiveRoundState.greenInspectionCameraSpec(
            features: [smallGreen],
            shotOriginCoordinate: origin
        ))
        let largeSpec = try XCTUnwrap(LiveRoundState.greenInspectionCameraSpec(
            features: [largeGreen],
            shotOriginCoordinate: origin
        ))

        XCTAssertGreaterThan(largeSpec.distance, smallSpec.distance)
        // Sanity-check the bracket the camera distance lives in: the
        // floor (130 m) keeps tiny test geometry usable, the ceiling
        // (220 m) keeps huge greens from fully zooming out.
        XCTAssertGreaterThanOrEqual(smallSpec.distance, 130)
        XCTAssertLessThanOrEqual(largeSpec.distance, 220)
    }

    func testGreenInspectionCameraSpecIsNilWhenNoGreenFeatureIsTraced() {
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 1 tee",
            coordinates: [
                .init(latitude: -37.9759, longitude: 145.0331),
                .init(latitude: -37.9759, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0331)
            ]
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            // Tee only — no traced green polygon.
            courseHoles: [.init(number: 1, par: 4, features: [tee])],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertNil(state.greenInspectionCameraSpec)
        XCTAssertFalse(state.canInspectGreen)
    }

    func testCanInspectGreenIsTrueWhenGreenFeatureIsAvailable() {
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.9738, longitude: 145.0340),
                .init(latitude: -37.9738, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0340)
            ]
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [.init(number: 1, par: 4, features: [green])],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertTrue(state.canInspectGreen)
    }

    func testPlanningCarryDistanceUsesShotOriginNotRawPlayerCoordinate() {
        // When the player is off-course the carry pill on the aim line
        // would otherwise show "25,000 m". Since the line is anchored
        // to the tee in that case, the carry number must be tee→aim
        // too — otherwise the visual and the number disagree.
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 1 tee",
            coordinates: [
                .init(latitude: -37.9759, longitude: 145.0331),
                .init(latitude: -37.9759, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0331)
            ]
        )
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.9738, longitude: 145.0340),
                .init(latitude: -37.9738, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0340)
            ]
        )
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: 37.3318, longitude: -122.0312),
                headingDegrees: 0,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [.init(number: 1, par: 4, features: [tee, green])],
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        // Carry distance should be in the same envelope as the hole's
        // tee→back yardage (a few hundred metres), not the 13,000 km
        // tee-to-Cupertino distance.
        XCTAssertLessThan(state.planningCarryDistanceMeters, 1_000)
    }

    func testDisplayedDistancesPassThroughBelowHoleMax() {
        // Sanity check for the clamp: when the raw distances are well
        // within the hole envelope we don't accidentally chop them.
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 1 tee",
            coordinates: [
                .init(latitude: -37.9759, longitude: 145.0331),
                .init(latitude: -37.9759, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0331)
            ]
        )
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.9738, longitude: 145.0340),
                .init(latitude: -37.9738, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0340)
            ]
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [.init(number: 1, par: 4, features: [tee, green])],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.distanceToPinMeters = 120

        XCTAssertEqual(state.displayedPinDistanceMeters, 120)
    }

    func testDisplayedDistanceMetricsUseDisplayedHoleGeometryWhileInspecting() {
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 1 tee",
            coordinates: [
                .init(latitude: -37.9759, longitude: 145.0331),
                .init(latitude: -37.9759, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0331)
            ]
        )
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.9738, longitude: 145.0340),
                .init(latitude: -37.9738, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0340)
            ]
        )
        let holeTwoTee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 2 tee",
            coordinates: [
                .init(latitude: -37.9729, longitude: 145.0388),
                .init(latitude: -37.9729, longitude: 145.0390),
                .init(latitude: -37.9727, longitude: 145.0390),
                .init(latitude: -37.9727, longitude: 145.0388)
            ]
        )
        let holeTwoGreen = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 2 green",
            coordinates: [
                .init(latitude: -37.9711, longitude: 145.0401),
                .init(latitude: -37.9711, longitude: 145.0403),
                .init(latitude: -37.9709, longitude: 145.0403),
                .init(latitude: -37.9709, longitude: 145.0401)
            ]
        )
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.9720, longitude: 145.0402),
                headingDegrees: 14,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 2, par: 3),
            courseHoles: [
                .init(number: 1, par: 4, features: [tee, green]),
                .init(number: 2, par: 3, features: [holeTwoTee, holeTwoGreen])
            ],
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.distanceToPinMeters = 999
        state.inspectPreviousHole()

        XCTAssertGreaterThan(state.displayedPinDistanceMeters, 0)
        XCTAssertLessThanOrEqual(state.displayedFrontDistanceMeters, state.displayedPinDistanceMeters)
        XCTAssertGreaterThan(state.displayedBackDistanceMeters, state.displayedFrontDistanceMeters)
        XCTAssertGreaterThanOrEqual(state.displayedBackDistanceMeters, state.displayedPinDistanceMeters)
    }

    func testInspectionNavigationAvailabilityTracksDisplayedHoleIndex() {
        let state = makeStateWithThreeHoles(activeHoleNumber: 2)

        XCTAssertTrue(state.canInspectPreviousHole)
        XCTAssertTrue(state.canInspectNextHole)

        state.inspectHole(at: 0)

        XCTAssertFalse(state.canInspectPreviousHole)
        XCTAssertTrue(state.canInspectNextHole)

        state.inspectHole(at: 2)

        XCTAssertTrue(state.canInspectPreviousHole)
        XCTAssertFalse(state.canInspectNextHole)
    }

    func testEditingConfirmedHoleMarksHoleAsEditedAfterConfirmation() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentHoleConfirmation()
        state.setPendingHoleScore(4)
        state.setPendingHolePutts(2)
        state.setPendingHolePenaltyCount(0)
        state.setPendingHoleDropCount(0)
        XCTAssertTrue(state.confirmCurrentHole())
        state.updateInspectedHoleScore(5)

        XCTAssertEqual(state.hole.recordedScore, 5)
        XCTAssertTrue(state.hole.isConfirmed)
        XCTAssertTrue(state.hole.wasEditedAfterConfirmation)
    }

    func testEditingConfirmedHoleClubCorrectionSummaryMarksHoleAsEditedAfterConfirmation() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentHoleConfirmation()
        state.setPendingHoleScore(4)
        state.setPendingHolePutts(2)
        state.setPendingHolePenaltyCount(0)
        state.setPendingHoleDropCount(0)
        state.setPendingHoleClubCorrectionSummary("Driver")
        XCTAssertTrue(state.confirmCurrentHole())

        state.updateInspectedHoleClubCorrectionSummary("Driver, 3W")

        XCTAssertEqual(state.hole.recordedClubCorrectionSummary, "Driver, 3W")
        XCTAssertTrue(state.hole.isConfirmed)
        XCTAssertTrue(state.hole.wasEditedAfterConfirmation)
    }

    func testEditingConfirmedHoleWithoutChangingScoreKeepsAuditFlagFalse() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentHoleConfirmation()
        state.setPendingHoleScore(4)
        state.setPendingHolePutts(2)
        state.setPendingHolePenaltyCount(0)
        state.setPendingHoleDropCount(0)
        XCTAssertTrue(state.confirmCurrentHole())
        state.updateInspectedHoleScore(4)

        XCTAssertEqual(state.hole.recordedScore, 4)
        XCTAssertTrue(state.hole.isConfirmed)
        XCTAssertFalse(state.hole.wasEditedAfterConfirmation)
    }

    func testCurrentHoleEditDraftDoesNotMutateConfirmedHoleUntilApplied() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.presentHoleConfirmation()
        state.setPendingHoleScore(4)
        state.setPendingHolePutts(2)
        state.setPendingHolePenaltyCount(0)
        state.setPendingHoleDropCount(0)
        XCTAssertTrue(state.confirmCurrentHole())

        var draft = state.makeCurrentHoleEditDraft()
        draft.score = 5
        draft.putts = 3
        draft.penaltyCount = 1
        draft.dropCount = 1
        draft.shotOutcomeSummary = "Recovery from trees"
        draft.clubCorrectionSummary = "Driver, 7i"
        draft.notes = "Adjusted after review"

        XCTAssertEqual(state.hole.recordedScore, 4)
        XCTAssertEqual(state.hole.recordedPutts, 2)
        XCTAssertEqual(state.hole.recordedPenaltyCount, 0)
        XCTAssertEqual(state.hole.recordedDropCount, 0)
        XCTAssertNil(state.hole.recordedShotOutcomeSummary)
        XCTAssertNil(state.hole.recordedClubCorrectionSummary)
        XCTAssertNil(state.hole.recordedNotes)
        XCTAssertFalse(state.hole.wasEditedAfterConfirmation)

        state.applyCurrentHoleEditDraft(draft)

        XCTAssertEqual(state.hole.recordedScore, 5)
        XCTAssertEqual(state.hole.recordedPutts, 3)
        XCTAssertEqual(state.hole.recordedPenaltyCount, 1)
        XCTAssertEqual(state.hole.recordedDropCount, 1)
        XCTAssertEqual(state.hole.recordedShotOutcomeSummary, "Recovery from trees")
        XCTAssertEqual(state.hole.recordedClubCorrectionSummary, "Driver, 7i")
        XCTAssertEqual(state.hole.recordedNotes, "Adjusted after review")
        XCTAssertTrue(state.hole.wasEditedAfterConfirmation)
    }

    func testEditingFutureHoleScoreIsIgnored() {
        let state = makeStateWithThreeHoles(activeHoleNumber: 2)

        state.inspectNextHole()
        state.updateInspectedHoleScore(7)

        XCTAssertEqual(state.displayedHoleNumber, 3)
        XCTAssertNil(state.displayedHoleSession.recordedScore)
        XCTAssertFalse(state.displayedHoleSession.wasEditedAfterConfirmation)
    }

    func testSnapshotRoundTripPreservesInspectionAndNonActiveHoleAuditState() {
        let state = makeStateWithThreeHoles(activeHoleNumber: 1)

        state.logShot(clubName: "7i", distanceToTargetMeters: 152)
        state.presentHoleConfirmation()
        state.setPendingHoleScore(4)
        state.setPendingHolePutts(2)
        state.setPendingHolePenaltyCount(0)
        state.setPendingHoleDropCount(1)
        state.setPendingHoleShotOutcomeSummary("Tee shot right, approach recovered")
        state.setPendingHoleClubCorrectionSummary("7i, PW")
        XCTAssertTrue(state.confirmCurrentHole())
        state.inspectPreviousHole()
        state.updateInspectedHoleScore(5)

        let restored = LiveRoundState(snapshot: state.snapshot)

        XCTAssertEqual(restored.hole.number, 2)
        XCTAssertEqual(restored.displayedHoleNumber, 1)
        XCTAssertTrue(restored.isInspectingHole)
        XCTAssertEqual(restored.displayedHoleSession.recordedScore, 5)
        XCTAssertTrue(restored.displayedHoleSession.isConfirmed)
        XCTAssertTrue(restored.displayedHoleSession.wasEditedAfterConfirmation)
        XCTAssertEqual(restored.displayedHoleSession.recordedDropCount, 1)
        XCTAssertEqual(restored.displayedHoleSession.recordedShotOutcomeSummary, "Tee shot right, approach recovered")
        XCTAssertEqual(restored.displayedHoleSession.recordedClubCorrectionSummary, "7i, PW")
        XCTAssertEqual(restored.displayedHoleSession.shots.count, 1)
    }

    func testSnapshotMismatchFallbackPreservesMatchingConfirmedHoleSummaries() {
        let state = makeStateWithThreeHoles(activeHoleNumber: 1)

        state.logShot(clubName: "7i", distanceToTargetMeters: 152, penaltyCount: 1, dropCount: 1)
        state.presentHoleConfirmation()
        state.setPendingHoleScore(4)
        state.setPendingHolePutts(2)
        state.setPendingHolePenaltyCount(1)
        state.setPendingHoleDropCount(1)
        state.setPendingHoleShotOutcomeSummary("7i leaked right, wedge recovered")
        state.setPendingHoleClubCorrectionSummary("7i, PW")
        state.setPendingHoleNotes("Wind held it up")
        XCTAssertTrue(state.confirmCurrentHole())

        let baseSnapshot = state.snapshot
        let mismatchedHoleSessions = [
            baseSnapshot.holeSessions[0],
            HoleSession(
                number: 3,
                par: 3,
                recordedScore: 5,
                recordedPutts: 2,
                recordedPenaltyCount: 0,
                recordedDropCount: 1,
                recordedShotOutcomeSummary: "Layup left, bunker save",
                recordedClubCorrectionSummary: "5W, SW",
                recordedNotes: "Preserve mismatched summary",
                isConfirmed: true,
                wasEditedAfterConfirmation: true,
                shots: []
            )
        ]
        let restored = LiveRoundState(
            snapshot: .init(
                hole: baseSnapshot.hole,
                holeSessions: mismatchedHoleSessions,
                activeHoleIndex: baseSnapshot.activeHoleIndex,
                displayedHoleIndex: baseSnapshot.displayedHoleIndex,
                courseName: baseSnapshot.courseName,
                courseCoordinate: baseSnapshot.courseCoordinate,
                courseHoles: baseSnapshot.courseHoles,
                players: baseSnapshot.players,
                selectedClubName: baseSnapshot.selectedClubName,
                distanceToPinMeters: baseSnapshot.distanceToPinMeters,
                mapRotationDegrees: baseSnapshot.mapRotationDegrees,
                mapPanOffset: baseSnapshot.mapPanOffset,
                planningTargetCoordinate: baseSnapshot.planningTargetCoordinate,
                reviewPlayers: baseSnapshot.reviewPlayers,
                playerLocation: baseSnapshot.playerLocation,
                ballMarkState: baseSnapshot.ballMarkState,
                lastLoggedShotOriginCoordinate: baseSnapshot.lastLoggedShotOriginCoordinate,
                lastLoggedShotOriginSource: baseSnapshot.lastLoggedShotOriginSource,
                lastLoggedShotTargetCoordinate: baseSnapshot.lastLoggedShotTargetCoordinate,
                lastLoggedShotTargetLabel: baseSnapshot.lastLoggedShotTargetLabel,
                ballMarkSuggestionBaselineCoordinate: baseSnapshot.ballMarkSuggestionBaselineCoordinate
            )
        )

        restored.inspectPreviousHole()

        XCTAssertEqual(restored.displayedHoleNumber, 1)
        XCTAssertEqual(restored.displayedHoleSession.recordedScore, 4)
        XCTAssertEqual(restored.displayedHoleSession.recordedPutts, 2)
        XCTAssertEqual(restored.displayedHoleSession.recordedPenaltyCount, 1)
        XCTAssertEqual(restored.displayedHoleSession.recordedDropCount, 1)
        XCTAssertEqual(restored.displayedHoleSession.recordedShotOutcomeSummary, "7i leaked right, wedge recovered")
        XCTAssertEqual(restored.displayedHoleSession.recordedClubCorrectionSummary, "7i, PW")
        XCTAssertEqual(restored.displayedHoleSession.recordedNotes, "Wind held it up")
        XCTAssertTrue(restored.displayedHoleSession.isConfirmed)
        XCTAssertEqual(restored.hole.number, 3)
        let mismatchedHole3 = restored.snapshot.holeSessions.first { $0.number == 3 }
        XCTAssertEqual(mismatchedHole3?.recordedNotes, "Preserve mismatched summary")
        XCTAssertEqual(mismatchedHole3?.recordedClubCorrectionSummary, "5W, SW")
        XCTAssertTrue(mismatchedHole3?.wasEditedAfterConfirmation ?? false)
    }

    func testHoleTransitionPresentationUsesCurrentHoleAndOpeningNumber() {
        let state = LiveRoundState(
            hole: HoleSession(number: 2, par: 3),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: StubRoundLocationProvider(status: .locating)
        )

        XCTAssertEqual(state.holeTransitionTitle, "Hole 2")
        XCTAssertEqual(state.holeTransitionSubtitle, "Par 3 • 360m opening number")
        XCTAssertEqual(state.holeTransitionDetail, "Pick a confident starting line.")
    }

    func testSnapshotRoundTripPreservesCourseContext() {
        let coordinate = LiveRoundState.MapCoordinate(latitude: -37.9749, longitude: 145.0376)
        let holeFeatures = [
            SwingPalCourse.Hole.Feature(
                kind: .fairway,
                label: "Primary corridor",
                coordinates: [
                    .init(latitude: -37.9754, longitude: 145.0336),
                    .init(latitude: -37.9750, longitude: 145.0339),
                    .init(latitude: -37.9746, longitude: 145.0337),
                    .init(latitude: -37.9749, longitude: 145.0334)
                ]
            )
        ]
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseName: "Kingston Heath",
            courseCoordinate: coordinate,
            holeFeatures: holeFeatures,
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        let restored = LiveRoundState(snapshot: state.snapshot)

        XCTAssertEqual(restored.courseName, "Kingston Heath")
        XCTAssertEqual(restored.courseCoordinate, coordinate)
        XCTAssertEqual(restored.targetLabel, "Pin")
        XCTAssertEqual(restored.currentHoleFeatures, holeFeatures)
    }

    func testCurrentHoleFeaturesFollowHoleNumberWithinCourseModel() {
        let holeOne = SwingPalCourse.Hole(
            number: 1,
            par: 4,
            features: [
                .init(
                    kind: .fairway,
                    label: "Hole 1 corridor",
                    coordinates: [
                        .init(latitude: -37.9754, longitude: 145.0336),
                        .init(latitude: -37.9750, longitude: 145.0339),
                        .init(latitude: -37.9746, longitude: 145.0337),
                        .init(latitude: -37.9749, longitude: 145.0334)
                    ]
                )
            ]
        )
        let holeTwoFeature = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 2 green",
            coordinates: [
                .init(latitude: -37.9744, longitude: 145.0344),
                .init(latitude: -37.9743, longitude: 145.0346),
                .init(latitude: -37.9741, longitude: 145.0345),
                .init(latitude: -37.9742, longitude: 145.0343)
            ]
        )
        let holeTwo = SwingPalCourse.Hole(number: 2, par: 3, features: [holeTwoFeature])

        let state = LiveRoundState(
            hole: HoleSession(number: 2, par: 3),
            courseHoles: [holeOne, holeTwo],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertEqual(state.currentHoleFeatures, [holeTwoFeature])
    }

    func testCurrentHoleBoundsContainCurrentHoleFeatureGeometry() {
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 2 tee",
            coordinates: [
                .init(latitude: -37.9729, longitude: 145.0388),
                .init(latitude: -37.9729, longitude: 145.0390),
                .init(latitude: -37.9727, longitude: 145.0390),
                .init(latitude: -37.9727, longitude: 145.0388)
            ]
        )
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 2 green",
            coordinates: [
                .init(latitude: -37.9711, longitude: 145.0401),
                .init(latitude: -37.9711, longitude: 145.0403),
                .init(latitude: -37.9709, longitude: 145.0403),
                .init(latitude: -37.9709, longitude: 145.0401)
            ]
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 2, par: 3),
            courseHoles: [.init(number: 2, par: 3, features: [tee, green])],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        let bounds = state.currentHoleBounds
        for coordinate in tee.coordinates + green.coordinates {
            XCTAssertTrue(bounds.contains(coordinate))
        }
        XCTAssertGreaterThan(bounds.latitudeDelta, 0)
        XCTAssertGreaterThan(bounds.longitudeDelta, 0)
    }

    func testDisplayedHoleExposesBoundedRegion() {
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 2 tee",
            coordinates: [
                .init(latitude: -37.9729, longitude: 145.0388),
                .init(latitude: -37.9729, longitude: 145.0390),
                .init(latitude: -37.9727, longitude: 145.0390),
                .init(latitude: -37.9727, longitude: 145.0388)
            ]
        )
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 2 green",
            coordinates: [
                .init(latitude: -37.9711, longitude: 145.0401),
                .init(latitude: -37.9711, longitude: 145.0403),
                .init(latitude: -37.9709, longitude: 145.0403),
                .init(latitude: -37.9709, longitude: 145.0401)
            ]
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 2, par: 3),
            courseHoles: [.init(number: 2, par: 3, features: [tee, green])],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        let viewportBounds = state.displayedHoleViewportBounds
        let region = state.displayedHoleRegion

        XCTAssertEqual(state.displayedHole?.number, 2)
        XCTAssertGreaterThan(viewportBounds.maxX, viewportBounds.minX)
        XCTAssertGreaterThan(viewportBounds.maxY, viewportBounds.minY)
        XCTAssertEqual(region.center.latitude, state.currentHoleBounds.center.latitude, accuracy: 0.000001)
        XCTAssertEqual(region.center.longitude, state.currentHoleBounds.center.longitude, accuracy: 0.000001)
        XCTAssertGreaterThan(region.span.latitudeDelta, 0)
        XCTAssertGreaterThan(region.span.longitudeDelta, 0)
    }

    func testCurrentTargetZoneCombinesAllRelevantFairwaySegments() {
        let fairwaySegmentOne = SwingPalCourse.Hole.Feature(
            kind: .fairway,
            label: "Left landing",
            coordinates: [
                .init(latitude: -37.9759, longitude: 145.0333),
                .init(latitude: -37.9759, longitude: 145.0335),
                .init(latitude: -37.9757, longitude: 145.0335),
                .init(latitude: -37.9757, longitude: 145.0333)
            ]
        )
        let fairwaySegmentTwo = SwingPalCourse.Hole.Feature(
            kind: .fairway,
            label: "Right landing",
            coordinates: [
                .init(latitude: -37.9749, longitude: 145.0360),
                .init(latitude: -37.9749, longitude: 145.0362),
                .init(latitude: -37.9747, longitude: 145.0362),
                .init(latitude: -37.9747, longitude: 145.0360)
            ]
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [.init(number: 1, par: 4, features: [fairwaySegmentOne, fairwaySegmentTwo])],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertTrue(state.currentTargetZone.contains(fairwaySegmentOne.coordinates[0]))
        XCTAssertTrue(state.currentTargetZone.contains(fairwaySegmentTwo.coordinates[0]))
        XCTAssertGreaterThan(state.currentTargetZone.bounds.longitudeDelta, 0.002)
    }

    func testTeeAndTargetCoordinatesFollowCurrentHoleFeatureGeometry() {
        let holeOneTee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 1 tee",
            coordinates: [
                .init(latitude: -37.9759, longitude: 145.0331),
                .init(latitude: -37.9759, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0331)
            ]
        )
        let holeOneGreen = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.9738, longitude: 145.0340),
                .init(latitude: -37.9738, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0340)
            ]
        )
        let holeTwoTee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 2 tee",
            coordinates: [
                .init(latitude: -37.9729, longitude: 145.0388),
                .init(latitude: -37.9729, longitude: 145.0390),
                .init(latitude: -37.9727, longitude: 145.0390),
                .init(latitude: -37.9727, longitude: 145.0388)
            ]
        )
        let holeTwoGreen = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 2 green",
            coordinates: [
                .init(latitude: -37.9711, longitude: 145.0401),
                .init(latitude: -37.9711, longitude: 145.0403),
                .init(latitude: -37.9709, longitude: 145.0403),
                .init(latitude: -37.9709, longitude: 145.0401)
            ]
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 2, par: 3),
            courseHoles: [
                .init(number: 1, par: 4, features: [holeOneTee, holeOneGreen]),
                .init(number: 2, par: 3, features: [holeTwoTee, holeTwoGreen])
            ],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertEqual(state.teeCoordinate.latitude, -37.9728, accuracy: 0.000001)
        XCTAssertEqual(state.teeCoordinate.longitude, 145.0389, accuracy: 0.000001)
        XCTAssertEqual(state.targetCoordinate.latitude, -37.9710, accuracy: 0.000001)
        XCTAssertEqual(state.targetCoordinate.longitude, 145.0402, accuracy: 0.000001)
    }

    func testAdvanceToNextHoleUpdatesHoleAndFeatureContext() {
        let holeOne = SwingPalCourse.Hole(
            number: 1,
            par: 4,
            features: [
                .init(
                    kind: .fairway,
                    label: "Hole 1 corridor",
                    coordinates: [
                        .init(latitude: -37.9754, longitude: 145.0336),
                        .init(latitude: -37.9750, longitude: 145.0339),
                        .init(latitude: -37.9746, longitude: 145.0337),
                        .init(latitude: -37.9749, longitude: 145.0334)
                    ]
                )
            ]
        )
        let holeTwoFeature = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 2 green",
            coordinates: [
                .init(latitude: -37.9744, longitude: 145.0344),
                .init(latitude: -37.9743, longitude: 145.0346),
                .init(latitude: -37.9741, longitude: 145.0345),
                .init(latitude: -37.9742, longitude: 145.0343)
            ]
        )
        let holeTwo = SwingPalCourse.Hole(number: 2, par: 3, features: [holeTwoFeature])
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [holeOne, holeTwo],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        let holeOneTargetLatitude = state.targetCoordinate.latitude

        XCTAssertTrue(state.advanceToNextHole())

        XCTAssertEqual(state.hole.number, 2)
        XCTAssertEqual(state.hole.par, 3)
        XCTAssertEqual(state.currentHoleFeatures, [holeTwoFeature])
        XCTAssertEqual(state.hole.shots.count, 0)
        XCTAssertNotEqual(state.targetCoordinate.latitude, holeOneTargetLatitude)
    }

    func testLocationProviderSeedsPlayerPositionAndHeading() {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.9721, longitude: 145.0412),
                headingDegrees: 37,
                horizontalAccuracyMeters: 6
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        XCTAssertEqual(state.playerLocation?.coordinate.latitude, -37.9721)
        XCTAssertEqual(state.playerLocation?.headingDegrees, 37)
        XCTAssertEqual(state.playerLocationStatusText, "GPS ±6m • heading 37°")
    }

    func testLocationUpdatesPersistThroughSnapshotRoundTrip() {
        let provider = StubRoundLocationProvider()
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        provider.push(
            .init(
                coordinate: .init(latitude: -37.9755, longitude: 145.0381),
                headingDegrees: 118,
                horizontalAccuracyMeters: 4
            )
        )

        waitForMainQueueFlush()

        let restored = LiveRoundState(snapshot: state.snapshot)

        XCTAssertEqual(state.playerLocation?.coordinate.latitude, -37.9755)
        XCTAssertEqual(restored.playerLocation?.headingDegrees, 118)
        XCTAssertEqual(restored.playerLocationStatusText, "GPS ±4m • heading 118°")
    }

    func testReadyLocationUsesMeasuredTargetDistanceInsteadOfStaticDistance() {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.975731, longitude: 145.033863),
                headingDegrees: 24,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )
        state.distanceToPinMeters = 152

        XCTAssertNotEqual(state.liveDistanceToSelectedTargetMeters, 152)
        XCTAssertEqual(state.liveDistanceToSelectedTargetMeters, 357)
    }

    func testAdvancingHoleWithReadyLocationRefreshesDisplayedPinDistanceForNextHole() {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.975731, longitude: 145.033863),
                headingDegrees: 24,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let holeOneGreen = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.9741, longitude: 145.03395),
                .init(latitude: -37.9741, longitude: 145.03405),
                .init(latitude: -37.9740, longitude: 145.03405),
                .init(latitude: -37.9740, longitude: 145.03395)
            ]
        )
        let holeTwoGreen = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 2 green",
            coordinates: [
                .init(latitude: -37.9724, longitude: 145.04055),
                .init(latitude: -37.9724, longitude: 145.04070),
                .init(latitude: -37.9722, longitude: 145.04070),
                .init(latitude: -37.9722, longitude: 145.04055)
            ]
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [
                .init(number: 1, par: 4, features: [holeOneGreen]),
                .init(number: 2, par: 3, features: [holeTwoGreen])
            ],
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        XCTAssertTrue(state.advanceToNextHole())

        let measuredDistance = state.liveDistanceToSelectedTargetMeters
        XCTAssertNotEqual(measuredDistance, 152)
        XCTAssertEqual(state.displayedPinDistanceMeters, measuredDistance)
    }

    func testRecommendedMapRegionCentersBetweenPlayerAndTarget() {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.975731, longitude: 145.033863),
                headingDegrees: 24,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        let region = state.recommendedMapRegion

        XCTAssertEqual(region.center.latitude, -37.974973, accuracy: 0.0005)
        XCTAssertEqual(region.center.longitude, 145.033907, accuracy: 0.0005)
        XCTAssertGreaterThan(region.span.latitudeDelta, 0.001)
        XCTAssertGreaterThan(region.span.longitudeDelta, 0.0011)
    }

    func testStartupMapRegionUsesTeeToTargetFramingWhenGPSIsNotReady() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseCoordinate: .init(latitude: -37.9742, longitude: 145.0338),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: StubRoundLocationProvider(status: .locating)
        )

        let region = state.startupMapRegion
        let tee = state.teeCoordinate
        let target = state.targetCoordinate

        XCTAssertEqual(region.center.latitude, (tee.latitude + target.latitude) / 2, accuracy: 0.0004)
        XCTAssertEqual(region.center.longitude, (tee.longitude + target.longitude) / 2, accuracy: 0.0004)
        XCTAssertGreaterThan(region.span.latitudeDelta, 0.002)
        XCTAssertGreaterThan(region.span.longitudeDelta, 0.001)
    }

    func testStartupMapRegionMatchesRecommendedRegionWhenGPSIsReady() {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.975731, longitude: 145.033863),
                headingDegrees: 24,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        XCTAssertEqual(state.startupMapRegion.center.latitude, state.recommendedMapRegion.center.latitude, accuracy: 0.000001)
        XCTAssertEqual(state.startupMapRegion.center.longitude, state.recommendedMapRegion.center.longitude, accuracy: 0.000001)
    }

    func testPreferredMapRegionUsesStartupFramingUntilGPSIsReady() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: StubRoundLocationProvider(status: .locating)
        )

        XCTAssertEqual(state.preferredMapRegion.center.latitude, state.startupMapRegion.center.latitude, accuracy: 0.000001)
        XCTAssertEqual(state.preferredMapRegion.center.longitude, state.startupMapRegion.center.longitude, accuracy: 0.000001)
    }

    func testPreferredMapRegionTracksNewHoleGeometryAfterAdvance() {
        let holeOne = SwingPalCourse.Hole(
            number: 1,
            par: 4,
            features: [
                .init(
                    kind: .tee,
                    label: "Hole 1 tee",
                    coordinates: [
                        .init(latitude: -37.9759, longitude: 145.0331),
                        .init(latitude: -37.9759, longitude: 145.0333),
                        .init(latitude: -37.9757, longitude: 145.0333),
                        .init(latitude: -37.9757, longitude: 145.0331)
                    ]
                ),
                .init(
                    kind: .green,
                    label: "Hole 1 green",
                    coordinates: [
                        .init(latitude: -37.9738, longitude: 145.0340),
                        .init(latitude: -37.9738, longitude: 145.0342),
                        .init(latitude: -37.9736, longitude: 145.0342),
                        .init(latitude: -37.9736, longitude: 145.0340)
                    ]
                )
            ]
        )
        let holeTwo = SwingPalCourse.Hole(
            number: 2,
            par: 3,
            features: [
                .init(
                    kind: .tee,
                    label: "Hole 2 tee",
                    coordinates: [
                        .init(latitude: -37.9729, longitude: 145.0388),
                        .init(latitude: -37.9729, longitude: 145.0390),
                        .init(latitude: -37.9727, longitude: 145.0390),
                        .init(latitude: -37.9727, longitude: 145.0388)
                    ]
                ),
                .init(
                    kind: .green,
                    label: "Hole 2 green",
                    coordinates: [
                        .init(latitude: -37.9711, longitude: 145.0401),
                        .init(latitude: -37.9711, longitude: 145.0403),
                        .init(latitude: -37.9709, longitude: 145.0403),
                        .init(latitude: -37.9709, longitude: 145.0401)
                    ]
                )
            ]
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [holeOne, holeTwo],
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: StubRoundLocationProvider(status: .locating)
        )
        let initialRegion = state.preferredMapRegion

        XCTAssertTrue(state.advanceToNextHole())

        XCTAssertNotEqual(state.preferredMapRegion.center.latitude, initialRegion.center.latitude)
        XCTAssertNotEqual(state.preferredMapRegion.center.longitude, initialRegion.center.longitude)
    }

    func testPreferredMapRegionCentersBetweenPlayerAndPlanningTarget() {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.975731, longitude: 145.033863),
                headingDegrees: 24,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.movePlanningTarget(to: midwayCoordinate(player: state.playerCoordinate, target: state.targetCoordinate))

        let region = state.preferredMapRegion
        let planningTarget = state.planningTargetCoordinate
        let player = try? XCTUnwrap(state.playerLocation)

        XCTAssertEqual(region.center.latitude, ((player?.coordinate.latitude ?? 0) + planningTarget.latitude) / 2, accuracy: 0.0005)
        XCTAssertEqual(region.center.longitude, ((player?.coordinate.longitude ?? 0) + planningTarget.longitude) / 2, accuracy: 0.0005)
    }

    func testRecenterViewportRegionUsesPlayerAndPlanningTargetWithinDisplayedHoleBounds() throws {
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 1 tee",
            coordinates: [
                .init(latitude: -37.9759, longitude: 145.0331),
                .init(latitude: -37.9759, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0331)
            ]
        )
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.9738, longitude: 145.0340),
                .init(latitude: -37.9738, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0340)
            ]
        )
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.9751, longitude: 145.0335),
                headingDegrees: 24,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [.init(number: 1, par: 4, features: [tee, green])],
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.movePlanningTarget(to: midwayCoordinate(player: state.playerCoordinate, target: state.targetCoordinate))

        let region = state.recenterViewportRegion
        let player = try XCTUnwrap(state.playerLocation)
        let planningTarget = state.planningTargetCoordinate
        let bounds = state.currentHoleBounds
        let latitudeInset = region.span.latitudeDelta / 2
        let longitudeInset = region.span.longitudeDelta / 2

        XCTAssertEqual(region.center.latitude, (player.coordinate.latitude + planningTarget.latitude) / 2, accuracy: 0.0005)
        XCTAssertEqual(region.center.longitude, (player.coordinate.longitude + planningTarget.longitude) / 2, accuracy: 0.0005)
        XCTAssertGreaterThanOrEqual(region.center.latitude - latitudeInset, bounds.minLatitude - 0.000001)
        XCTAssertLessThanOrEqual(region.center.latitude + latitudeInset, bounds.maxLatitude + 0.000001)
        XCTAssertGreaterThanOrEqual(region.center.longitude - longitudeInset, bounds.minLongitude - 0.000001)
        XCTAssertLessThanOrEqual(region.center.longitude + longitudeInset, bounds.maxLongitude + 0.000001)
    }

    func testPreferredMapRegionStaysWithinCurrentHoleBoundsWhenPlayerLocationDriftsOutsideHole() {
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 1 tee",
            coordinates: [
                .init(latitude: -37.9759, longitude: 145.0331),
                .init(latitude: -37.9759, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0333),
                .init(latitude: -37.9757, longitude: 145.0331)
            ]
        )
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.9738, longitude: 145.0340),
                .init(latitude: -37.9738, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0342),
                .init(latitude: -37.9736, longitude: 145.0340)
            ]
        )
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.9650, longitude: 145.0500),
                headingDegrees: 24,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [.init(number: 1, par: 4, features: [tee, green])],
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        let region = state.preferredMapRegion
        let bounds = state.currentHoleBounds
        let latitudeInset = region.span.latitudeDelta / 2
        let longitudeInset = region.span.longitudeDelta / 2

        XCTAssertGreaterThanOrEqual(region.center.latitude - latitudeInset, bounds.minLatitude - 0.000001)
        XCTAssertLessThanOrEqual(region.center.latitude + latitudeInset, bounds.maxLatitude + 0.000001)
        XCTAssertGreaterThanOrEqual(region.center.longitude - longitudeInset, bounds.minLongitude - 0.000001)
        XCTAssertLessThanOrEqual(region.center.longitude + longitudeInset, bounds.maxLongitude + 0.000001)
    }

    func testPlanningTargetCoordinatePersistsThroughSnapshotRoundTrip() {
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.975731, longitude: 145.033863),
                headingDegrees: 24,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        state.movePlanningTarget(to: midwayCoordinate(player: state.playerCoordinate, target: state.targetCoordinate))
        let planningTarget = state.planningTargetCoordinate

        let restored = LiveRoundState(snapshot: state.snapshot)

        XCTAssertEqual(restored.planningTargetCoordinate.latitude, planningTarget.latitude, accuracy: 0.000001)
        XCTAssertEqual(restored.planningTargetCoordinate.longitude, planningTarget.longitude, accuracy: 0.000001)
    }

    func testPermissionDeniedProviderShowsSettingsGuidance() {
        let provider = StubRoundLocationProvider(status: .permissionDenied)
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        XCTAssertEqual(state.playerLocationStatusText, "Location blocked • enable in Settings")
    }

    func testUnavailableProviderShowsFallbackStatus() {
        let provider = StubRoundLocationProvider(status: .unavailable)
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: provider
        )

        XCTAssertEqual(state.playerLocationStatusText, "Location unavailable")
    }

    func testMapPanIsClampedToPlanningBounds() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.setMapPan(to: CGSize(width: 320, height: -290))

        XCTAssertEqual(state.mapPanOffset.width, 180)
        XCTAssertEqual(state.mapPanOffset.height, -180)
    }

    func testMapRotationNormalizesIntoCompactRange() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.setMapRotation(to: 220)
        XCTAssertEqual(state.mapRotationDegrees, -140, accuracy: 0.001)

        state.setMapRotation(to: -230)
        XCTAssertEqual(state.mapRotationDegrees, 130, accuracy: 0.001)
    }

    func testInstrumentMetricsReflectCurrentRoundState() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.selectClub(named: "5W")
        state.presentShotLogger()
        state.selectShotDirection(.hit)
        state.selectShotDistance(.onNumber)
        state.confirmPendingShot()

        XCTAssertEqual(
            state.leadingInstrumentMetrics,
            [
                .init(title: "Plays Like", value: "\(state.playsLikeDistanceMeters)m"),
                .init(title: "Club", value: "5W")
            ]
        )
        XCTAssertEqual(
            state.trailingInstrumentMetrics,
            [
                .init(title: "Strokes", value: "1"),
                .init(title: "Target", value: "Pin")
            ]
        )
    }

    func testMovePlanningTargetUpdatesCarryAndRemainingDistances() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        let originalCarry = state.planningCarryDistanceMeters
        let originalRemaining = state.planningRemainingDistanceMeters

        let player = state.playerCoordinate
        let pin = state.targetCoordinate
        let threeQuartersToPin = CLLocationCoordinate2D(
            latitude: player.latitude + (pin.latitude - player.latitude) * 0.75,
            longitude: player.longitude + (pin.longitude - player.longitude) * 0.75
        )
        state.movePlanningTarget(to: threeQuartersToPin)

        XCTAssertNotEqual(state.planningCarryDistanceMeters, originalCarry)
        XCTAssertNotEqual(state.planningRemainingDistanceMeters, originalRemaining)
        XCTAssertGreaterThan(state.planningCarryDistanceMeters, 0)
        XCTAssertGreaterThan(state.planningRemainingDistanceMeters, 0)
    }

    func testMovePlanningTargetClampsCoordinateIntoDisplayedHoleBounds() {
        let fairway = SwingPalCourse.Hole.Feature(
            kind: .fairway,
            label: "Narrow fairway window",
            coordinates: [
                .init(latitude: -37.97495, longitude: 145.03380),
                .init(latitude: -37.97495, longitude: 145.03392),
                .init(latitude: -37.97475, longitude: 145.03392),
                .init(latitude: -37.97475, longitude: 145.03380)
            ]
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [.init(number: 1, par: 4, features: [fairway])],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        let waydOff = CLLocationCoordinate2D(latitude: -37.0, longitude: 146.5)
        state.movePlanningTarget(to: waydOff)

        let planningTarget = SwingPalCourse.Coordinate(
            latitude: state.planningTargetCoordinate.latitude,
            longitude: state.planningTargetCoordinate.longitude
        )

        XCTAssertTrue(state.currentHoleBounds.contains(planningTarget))
    }

    func testRefreshingWeatherPublishesAppleWeatherSnapshot() async {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            weatherLoader: StubWeatherLoader(
                result: .success(
                    .init(
                        temperatureCelsius: 22,
                        apparentTemperatureCelsius: 24,
                        conditionDescription: "Partly cloudy",
                        symbolName: "cloud.sun.fill",
                        windSpeedKilometersPerHour: 19,
                        windCompassDirection: "NW",
                        attributionText: "Weather for testing"
                    )
                )
            )
        )

        await state.refreshWeather()

        XCTAssertEqual(state.windSummaryText, "Wind 19 km/h NW")
        XCTAssertEqual(state.temperatureSummaryText, "22°C")
        XCTAssertEqual(state.weatherConditionText, "Partly cloudy")
        XCTAssertEqual(state.weatherAttributionText, "Weather for testing")
    }

    func testRefreshingWeatherFallsBackGracefullyWhenLoaderFails() async {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            weatherLoader: StubWeatherLoader(result: .failure(StubWeatherError.unavailable))
        )

        await state.refreshWeather()

        XCTAssertEqual(state.windSummaryText, "Weather unavailable")
        XCTAssertEqual(state.temperatureSummaryText, "--")
        XCTAssertEqual(state.weatherConditionText, "Live conditions unavailable")
        XCTAssertNil(state.weatherAttributionText)
    }

    // MARK: - Shot-relative wind chip / Conditions hero refactor

    private func makeStateWithDueNorthHoleAndWind(
        windCompassDirection: String,
        windDirectionDegrees: Double?,
        windSpeed: Int = 12,
        temperatureCelsius: Int = 20
    ) async -> LiveRoundState {
        // Tee + green aligned north-south so the shot bearing lands at
        // ~0° (due north). Lets us assert wind components against the
        // raw compass without bearing-skew arithmetic in the test.
        let tee = SwingPalCourse.Hole.Feature(
            kind: .tee,
            label: "Hole 1 tee",
            coordinates: [
                .init(latitude: -37.9760, longitude: 145.03395),
                .init(latitude: -37.9760, longitude: 145.03405),
                .init(latitude: -37.9759, longitude: 145.03405),
                .init(latitude: -37.9759, longitude: 145.03395)
            ]
        )
        let green = SwingPalCourse.Hole.Feature(
            kind: .green,
            label: "Hole 1 green",
            coordinates: [
                .init(latitude: -37.9741, longitude: 145.03395),
                .init(latitude: -37.9741, longitude: 145.03405),
                .init(latitude: -37.9740, longitude: 145.03405),
                .init(latitude: -37.9740, longitude: 145.03395)
            ]
        )
        // Player parked on the tee so live shot bearing aligns with
        // tee→pin (0° = north).
        let provider = StubRoundLocationProvider(
            initialSnapshot: .init(
                coordinate: .init(latitude: -37.97595, longitude: 145.03400),
                headingDegrees: 0,
                horizontalAccuracyMeters: 5
            ),
            status: .ready
        )
        let snapshot = RoundWeatherSnapshot(
            temperatureCelsius: temperatureCelsius,
            apparentTemperatureCelsius: temperatureCelsius,
            conditionDescription: "Clear",
            symbolName: "sun.max.fill",
            windSpeedKilometersPerHour: windSpeed,
            windCompassDirection: windCompassDirection,
            windDirectionDegrees: windDirectionDegrees,
            attributionText: "Test"
        )
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [.init(number: 1, par: 4, features: [tee, green])],
            players: [.init(name: "You", kind: .selfPlayer)],
            weatherLoader: StubWeatherLoader(result: .success(snapshot)),
            locationProvider: provider
        )
        await state.refreshWeather()
        return state
    }

    func testWindHeadComponentIsPositiveWhenWindBlowsFromAheadOfTheShot() async {
        let state = await makeStateWithDueNorthHoleAndWind(
            windCompassDirection: "N",
            windDirectionDegrees: 0,
            windSpeed: 12
        )

        // Shot heads north, wind blows from the north → pure head wind.
        XCTAssertEqual(state.windHeadComponentKmh, 12)
        XCTAssertEqual(state.windCrossComponentKmh, 0)
        XCTAssertEqual(state.windRelativeCategory, .head)
    }

    func testWindHeadComponentIsNegativeWhenWindBlowsFromBehindAsTailwind() async {
        let state = await makeStateWithDueNorthHoleAndWind(
            windCompassDirection: "S",
            windDirectionDegrees: 180,
            windSpeed: 12
        )

        // Wind from the south, shot heads north → pure tail wind.
        XCTAssertEqual(state.windHeadComponentKmh, -12)
        XCTAssertEqual(state.windCrossComponentKmh, 0)
        XCTAssertEqual(state.windRelativeCategory, .tail)
    }

    func testWindCrossComponentIsPositiveForLeftToRightCrossWind() async {
        let state = await makeStateWithDueNorthHoleAndWind(
            windCompassDirection: "W",
            windDirectionDegrees: 270,
            windSpeed: 10
        )

        // Wind from west pushes the ball toward the player's right when
        // they're facing north → cross R, no head/tail component.
        XCTAssertEqual(state.windHeadComponentKmh, 0)
        XCTAssertEqual(state.windCrossComponentKmh, 10)
        XCTAssertEqual(state.windRelativeCategory, .crossRight)
    }

    func testWindCrossComponentIsNegativeForRightToLeftCrossWind() async {
        let state = await makeStateWithDueNorthHoleAndWind(
            windCompassDirection: "E",
            windDirectionDegrees: 90,
            windSpeed: 10
        )

        XCTAssertEqual(state.windHeadComponentKmh, 0)
        XCTAssertEqual(state.windCrossComponentKmh, -10)
        XCTAssertEqual(state.windRelativeCategory, .crossLeft)
    }

    func testWindCategoryReportsCalmBelowThreeKilometersPerHour() async {
        let state = await makeStateWithDueNorthHoleAndWind(
            windCompassDirection: "N",
            windDirectionDegrees: 0,
            windSpeed: 1
        )

        XCTAssertEqual(state.windRelativeCategory, .calm)
        XCTAssertFalse(state.hasUsableWindReading)
    }

    func testWindRelativeCategoryIsCalmWhenNoWeatherSnapshotPresent() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertEqual(state.windRelativeCategory, .calm)
        XCTAssertEqual(state.windHeadComponentKmh, 0)
        XCTAssertEqual(state.windCrossComponentKmh, 0)
        XCTAssertNil(state.windRelativeMotionDegrees)
        XCTAssertNil(state.windComponentBreakdownText)
        XCTAssertFalse(state.hasUsableWindReading)
    }

    func testPlaysLikeWindDeltaIsPositiveIntoTheBreezeAndNegativeWithIt() async {
        let intoWind = await makeStateWithDueNorthHoleAndWind(
            windCompassDirection: "N",
            windDirectionDegrees: 0,
            windSpeed: 20
        )
        let downwind = await makeStateWithDueNorthHoleAndWind(
            windCompassDirection: "S",
            windDirectionDegrees: 180,
            windSpeed: 20
        )

        // Sign check is the contract test here — the calculator's
        // exact percentage stays free to evolve.
        XCTAssertGreaterThan(intoWind.playsLikeWindDeltaMeters, 0)
        XCTAssertLessThan(downwind.playsLikeWindDeltaMeters, 0)
    }

    func testPlaysLikeTemperatureDeltaIsPositiveBelowBaselineAndNegativeAbove() async {
        let coldDay = await makeStateWithDueNorthHoleAndWind(
            windCompassDirection: "N",
            windDirectionDegrees: 0,
            windSpeed: 0,
            temperatureCelsius: 4
        )
        let warmDay = await makeStateWithDueNorthHoleAndWind(
            windCompassDirection: "N",
            windDirectionDegrees: 0,
            windSpeed: 0,
            temperatureCelsius: 35
        )

        // Cool air = denser = ball flies less = plays-like LONGER.
        XCTAssertGreaterThan(coldDay.playsLikeTemperatureDeltaMeters, 0)
        XCTAssertLessThan(warmDay.playsLikeTemperatureDeltaMeters, 0)
    }

    func testWindComponentBreakdownTextDescribesHeadAndCrossWhenBothAreNonZero() async {
        // Wind from NE = heading SW → opposes due-north shot AND pushes
        // the ball to the player's left. Both axes should be populated.
        let state = await makeStateWithDueNorthHoleAndWind(
            windCompassDirection: "NE",
            windDirectionDegrees: 45,
            windSpeed: 14
        )

        let breakdown = state.windComponentBreakdownText
        XCTAssertNotNil(breakdown)
        XCTAssertTrue(breakdown?.contains("head") == true, "Expected head component, got \(breakdown ?? "nil")")
        XCTAssertTrue(breakdown?.contains("cross") == true, "Expected cross component, got \(breakdown ?? "nil")")
    }

    func testLoggingShotAppendsShotAndIncrementsStrokeCount() {
        let hole = HoleSession(number: 1, par: 4)
        let state = LiveRoundState(
            hole: hole,
            players: [
                .init(name: "You", kind: .selfPlayer),
                .init(name: "Ben", kind: .guest)
            ]
        )

        state.logShot(clubName: "7i", distanceToTargetMeters: 152)

        XCTAssertEqual(state.hole.shots.count, 1)
        XCTAssertEqual(state.hole.strokeCount, 1)
    }

    func testLoggingShotMovesLongHoleIntoApproachPhase() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.logShot(clubName: "7i", distanceToTargetMeters: 152)

        XCTAssertEqual(state.shotPhase, .approach)
        XCTAssertEqual(state.shotPhaseTitle, "Approach")
        XCTAssertEqual(state.shotFocus, "Commit to a full carry number.")
    }

    func testLoggingShotMarksSignedInPlayerAsEdited() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [
                .init(name: "You", kind: .selfPlayer),
                .init(name: "Ben", kind: .guest)
            ]
        )

        state.logShot(clubName: "7i", distanceToTargetMeters: 152)

        XCTAssertEqual(state.reviewPlayers.first?.status, .edited)
        XCTAssertEqual(state.reviewPlayers.last?.status, .pending)
    }

    func testLoggingShotCapturesSurfaceAndDistance() {
        let state = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.logShot(clubName: "7i", distanceToTargetMeters: 152, surface: .rough)

        XCTAssertEqual(state.hole.shots.first?.surface, .rough)
        XCTAssertEqual(state.hole.shots.first?.distanceToTargetMeters, 152)
    }

    func testReviewPlayersAreDerivedFromLiveRoundState() {
        let hole = HoleSession(number: 1, par: 4)
        let state = LiveRoundState(
            hole: hole,
            players: [
                .init(name: "You", kind: .selfPlayer),
                .init(name: "Ben", kind: .guest)
            ]
        )

        state.logShot(clubName: "7i", distanceToTargetMeters: 152)

        XCTAssertEqual(state.reviewPlayers.count, 2)
        XCTAssertEqual(state.reviewPlayers.first?.name, "You")
        XCTAssertEqual(state.reviewPlayers.first?.strokes, 1)
        XCTAssertEqual(state.reviewPlayers.first?.status, .edited)
        XCTAssertEqual(state.reviewPlayers.last?.name, "Ben")
        XCTAssertNil(state.reviewPlayers.last?.strokes)
    }

    func testRoundReviewSummaryCountsLoggedAndPendingPlayers() {
        let summary = RoundReviewSummary(players: [
            .init(name: "You", isGuest: false, strokes: 4, status: .edited),
            .init(name: "Ben", isGuest: true, status: .pending),
            .init(name: "Sarah", isGuest: false, strokes: 5, status: .confirmed)
        ])

        XCTAssertEqual(summary.playerCount, 3)
        XCTAssertEqual(summary.loggedCount, 2)
        XCTAssertEqual(summary.pendingCount, 1)
        XCTAssertEqual(summary.confirmedCount, 1)
        XCTAssertFalse(summary.isReadyToClose)
    }
}

/// Helper that returns a coordinate halfway between the player position and a target position.
/// Used by tests that need to nudge the planning aim point off the default pin location without
/// caring about the specific coordinate, mirroring the user dragging the on-map crosshair.
private func midwayCoordinate(
    player: CLLocationCoordinate2D,
    target: CLLocationCoordinate2D
) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(
        latitude: (player.latitude + target.latitude) / 2,
        longitude: (player.longitude + target.longitude) / 2
    )
}

private extension XCTestCase {
    func waitForMainQueueFlush() {
        let flush = expectation(description: "main queue flush")
        DispatchQueue.main.async { flush.fulfill() }
        wait(for: [flush], timeout: 2.0)
    }
}

private func makeStateWithThreeHoles(activeHoleNumber: Int) -> LiveRoundState {
    LiveRoundState(
        hole: HoleSession(number: activeHoleNumber, par: 4),
        courseHoles: [
            .init(number: 1, par: 4, features: []),
            .init(number: 2, par: 4, features: []),
            .init(number: 3, par: 3, features: [])
        ],
        players: [.init(name: "You", kind: .selfPlayer)]
    )
}

private struct StubWeatherLoader: RoundWeatherLoading {
    let result: Result<RoundWeatherSnapshot, Error>

    func fetchCurrentWeather() async throws -> RoundWeatherSnapshot {
        try result.get()
    }
}

private enum StubWeatherError: Error {
    case unavailable
}

private final class StubRoundLocationProvider: RoundLocationProviding {
    private(set) var currentSnapshot: RoundLocationSnapshot?
    private(set) var currentStatus: RoundLocationStatus
    private var updateHandler: ((RoundLocationSnapshot) -> Void)?
    private var statusHandler: ((RoundLocationStatus) -> Void)?

    init(initialSnapshot: RoundLocationSnapshot? = nil, status: RoundLocationStatus = .locating) {
        currentSnapshot = initialSnapshot
        currentStatus = status
    }

    func setUpdateHandler(_ handler: @escaping (RoundLocationSnapshot) -> Void) {
        updateHandler = handler
    }

    func setStatusHandler(_ handler: @escaping (RoundLocationStatus) -> Void) {
        statusHandler = handler
    }

    func startUpdating() {}

    func stopUpdating() {}

    func push(_ snapshot: RoundLocationSnapshot) {
        currentSnapshot = snapshot
        currentStatus = .ready
        updateHandler?(snapshot)
        statusHandler?(.ready)
    }

    func pushStatus(_ status: RoundLocationStatus) {
        currentStatus = status
        statusHandler?(status)
    }
}
