import Foundation
import Combine
import CoreGraphics
import CoreLocation
import MapKit

struct RoundLocationSnapshot: Equatable, Codable {
    let coordinate: LiveRoundState.MapCoordinate
    let headingDegrees: Double
    let horizontalAccuracyMeters: Int

    init(
        coordinate: LiveRoundState.MapCoordinate,
        headingDegrees: Double,
        horizontalAccuracyMeters: Int
    ) {
        self.coordinate = coordinate
        self.headingDegrees = headingDegrees
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
    }
}

enum RoundLocationStatus: String, Equatable, Codable {
    case locating
    case ready
    case requestingPermission
    case permissionDenied
    case unavailable
}

/// Values for SwiftUI `Map` `MapCameraBounds` when the live round clamps
/// pan/zoom to the green (plus padding) after **View green**.
struct GreenInspectionPanLimits {
    let paddedGreenMapRect: MKMapRect
    let minimumCameraDistance: CLLocationDistance
    let maximumCameraDistance: CLLocationDistance
}

/// The shot logger sheet adapts to one of three contextual modes based on
/// where the ball is sitting. The mode drives which inputs are foregrounded
/// (full outcome ring vs. holed/missed binary), the primary CTA copy, and
/// what the confirm-gate requires before the user can log the shot.
enum ShotLoggerContext: String, Equatable {
    /// Tee shot — the player is on the tee box (or it's stroke 1). The form
    /// emphasises the outcome ring + provisional toggle.
    case tee
    /// Generic full shot — fairway / rough / bunker. Outcome ring is the
    /// centrepiece; provisional + putt fields are hidden.
    case shot
    /// Putt — the player is on the green. Replaces the outcome ring with a
    /// holed / missed binary and a miss-distance/direction panel.
    case putt
}

protocol RoundLocationProviding: AnyObject {
    var currentSnapshot: RoundLocationSnapshot? { get }
    var currentStatus: RoundLocationStatus { get }
    func setUpdateHandler(_ handler: @escaping (RoundLocationSnapshot) -> Void)
    func setStatusHandler(_ handler: @escaping (RoundLocationStatus) -> Void)
    func startUpdating()
    func stopUpdating()
}

final class PreviewRoundLocationProvider: RoundLocationProviding {
    private var updateHandler: ((RoundLocationSnapshot) -> Void)?
    private var statusHandler: ((RoundLocationStatus) -> Void)?

    let currentSnapshot: RoundLocationSnapshot? = .init(
        coordinate: .init(latitude: -37.9744, longitude: 145.0334),
        headingDegrees: 32,
        horizontalAccuracyMeters: 8
    )
    let currentStatus: RoundLocationStatus = .ready

    func setUpdateHandler(_ handler: @escaping (RoundLocationSnapshot) -> Void) {
        updateHandler = handler
    }

    func setStatusHandler(_ handler: @escaping (RoundLocationStatus) -> Void) {
        statusHandler = handler
    }

    func startUpdating() {
        statusHandler?(currentStatus)
        if let currentSnapshot {
            updateHandler?(currentSnapshot)
        }
    }

    func stopUpdating() {}
}

final class CoreLocationRoundLocationProvider: NSObject, CLLocationManagerDelegate, RoundLocationProviding {
    private let manager = CLLocationManager()
    private var updateHandler: ((RoundLocationSnapshot) -> Void)?
    private var statusHandler: ((RoundLocationStatus) -> Void)?

    private(set) var currentSnapshot: RoundLocationSnapshot?
    private(set) var currentStatus: RoundLocationStatus = .locating

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.activityType = .fitness
        manager.headingFilter = 5
    }

    func setUpdateHandler(_ handler: @escaping (RoundLocationSnapshot) -> Void) {
        updateHandler = handler
    }

    func setStatusHandler(_ handler: @escaping (RoundLocationStatus) -> Void) {
        statusHandler = handler
    }

    func startUpdating() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            publishStatus(currentSnapshot == nil ? .locating : .ready)
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        case .notDetermined:
            publishStatus(.requestingPermission)
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            publishStatus(.permissionDenied)
        @unknown default:
            publishStatus(.unavailable)
        }
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.stopUpdatingHeading()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdating()
        case .denied, .restricted:
            publishStatus(.permissionDenied)
        case .notDetermined:
            publishStatus(.requestingPermission)
        @unknown default:
            publishStatus(.unavailable)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let heading = normalizedHeading(from: manager.heading)
        let snapshot = RoundLocationSnapshot(
            coordinate: .init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            headingDegrees: heading,
            horizontalAccuracyMeters: max(1, Int(location.horizontalAccuracy.rounded()))
        )
        currentSnapshot = snapshot
        publishStatus(.ready)
        updateHandler?(snapshot)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard let currentSnapshot else { return }
        let heading = normalizedHeading(from: newHeading)
        let snapshot = RoundLocationSnapshot(
            coordinate: currentSnapshot.coordinate,
            headingDegrees: heading,
            horizontalAccuracyMeters: currentSnapshot.horizontalAccuracyMeters
        )
        self.currentSnapshot = snapshot
        publishStatus(.ready)
        updateHandler?(snapshot)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        publishStatus(.unavailable)
    }

    private func publishStatus(_ status: RoundLocationStatus) {
        currentStatus = status
        statusHandler?(status)
    }

    private func normalizedHeading(from heading: CLHeading?) -> Double {
        guard let heading else { return 0 }
        if heading.trueHeading >= 0 {
            return heading.trueHeading
        }
        if heading.magneticHeading >= 0 {
            return heading.magneticHeading
        }
        return 0
    }
}

final class LiveRoundState: ObservableObject {

    /// Single spoke on the live-round club selector wheel. The wheel is the
    /// primary "what should I hit?" surface during a round, so the entry has
    /// to carry more than just a name — it also has to express
    ///
    ///   • how far the club typically goes (`displayCarryMeters`),
    ///   • whether that number came from logged player data or a baseline
    ///     (`carrySource`),
    ///   • how that carry relates to the *current shot's* plays-like target
    ///     (`gapToTargetMeters` + `relevance`), and
    ///   • whether it's the auto-recommended club for this shot
    ///     (`isRecommended`).
    ///
    /// The view layer (`FreshLiveRoundClubWheelOverlay`) reads these fields
    /// directly to drive in-range muting, the "REC" badge, and the gap chip.
    struct ClubWheelEntry: Equatable, Identifiable {
        enum CarrySource: Equatable {
            /// Distance backed by the player's logged shots / bag setting.
            case logged
            /// Distance falling back to the amateur baseline because no data
            /// has been captured for this club yet.
            case baseline
        }

        /// Where this club lives relative to the current shot's target. The
        /// view layer uses this to decide whether to fade the entry, tint
        /// the gap chip, and so on.
        enum Relevance: Equatable {
            /// The closest club (or one of the close cluster) to the target.
            case viable
            /// Carry is longer than the target by more than one club gap; the
            /// player would likely fly the green.
            case tooLong
            /// Carry is shorter than the target by more than one club gap; the
            /// player would likely come up short.
            case tooShort
            /// The wheel is currently in putter mode (close to / on the green)
            /// and this club isn't a putter, so it's irrelevant.
            case mutedByPutterMode
        }

        let id: String
        let clubName: String
        let displayCarryMeters: Int
        /// Signed difference between `displayCarryMeters` and the wheel's
        /// target distance. Positive = club is *longer* than the shot calls
        /// for, negative = shorter. `nil` when no target is available
        /// (e.g. previewing while inspecting an unscored hole).
        let gapToTargetMeters: Int?
        let carrySource: CarrySource
        let relevance: Relevance
        let isRecommended: Bool
    }

    struct HoleInspectionEntry: Equatable, Identifiable {
        let id: Int
        let number: Int
        let par: Int
        let score: Int?
        let putts: Int?
        let fairwayHit: Bool?
        let greenInRegulation: Bool?
        let isConfirmed: Bool
        let isDisplayed: Bool
        let isActive: Bool
        let wasEditedAfterConfirmation: Bool
    }

    struct CurrentHoleEditDraft: Equatable {
        var score: Int
        var putts: Int
        var penaltyCount: Int
        var dropCount: Int
        var shotOutcomeSummary: String
        var clubCorrectionSummary: String
        var notes: String
    }

    enum ShotOriginSource: String, Equatable, Codable {
        case tee
        case ballMark
        case currentLocationFallback
    }

    enum BallMarkStatus: Equatable {
        case hidden
        case available
        case marked
    }

    enum LauncherDetent: String, Equatable, Codable, CaseIterable {
        case collapsed
        case actions
        case expanded
    }

    /// Captured snapshot of round state immediately before a shot is
    /// logged, so we can roll the live HUD back to the pre-shot view if
    /// the player taps "Undo last shot". Single-level undo (only the
    /// most recently logged shot can be undone) keeps the surface simple
    /// and avoids surprising "undo a shot from three holes ago"
    /// behaviour.
    struct ShotUndoSnapshot: Equatable {
        let previousDistanceToPinMeters: Int
        let previousLastLoggedShotOriginCoordinate: MapCoordinate?
        let previousLastLoggedShotOriginSource: ShotOriginSource?
        let previousLastLoggedShotTargetCoordinate: MapCoordinate?
        let previousLastLoggedShotTargetLabel: String?
        let previousBallMarkState: BallMarkState?
        let previousBallMarkSuggestionBaselineCoordinate: MapCoordinate?
        let previousReviewPlayers: [PlayerScoreState]
    }

    /// Lightweight summary of a shot used by the undo confirmation
    /// popover and the "Undid X" toast that appears after the action
    /// completes.
    struct LoggedShotPreview: Equatable {
        let clubName: String
        let surface: ShotEvent.Surface
        let strokeNumber: Int
        let isPutt: Bool
        let createdAt: Date
    }

    /// Synthetic club name used by the "Quick penalty" tray and the
    /// re-tee flow when there's no real swing to attribute the
    /// penalty stroke to. Treated as a marker by the shot-history
    /// classifier (`shotHistoryEntryKind`) so we render the row as a
    /// penalty rather than a literal "Hit / On Number" outcome.
    static let syntheticPenaltyClubName = "Penalty"

    /// Discriminator used by the shot-history view (and any future
    /// shot-list surface) to render each event with the right copy.
    /// Centralising the rule on the state keeps the view dumb and the
    /// tests deterministic.
    enum ShotHistoryEntryKind: Equatable {
        /// Synthetic +1 stroke event (lost ball, OB, unplayable lie,
        /// water hazard, re-tee). The `direction` and `distanceResult`
        /// fields are filler for analytics — show the note instead.
        case penalty
        /// A logged putt. Holed/missed plus the optional miss
        /// direction/distance is a more useful summary than the legacy
        /// direction × distanceResult grid.
        case putt
        /// A regular swing — shows the existing distance / direction /
        /// distanceResult triple plus any optional metadata.
        case shot
    }

    /// Quick-penalty types surfaced in the launcher tray. Each entry
    /// adds a synthetic event with `penaltyCount = 1` so the score and
    /// per-shot tally stay accurate without the player having to drag
    /// through the full shot logger.
    enum QuickPenaltyType: String, Equatable, Codable, CaseIterable, Identifiable {
        case lostBall
        case outOfBounds
        case unplayable
        case water

        var id: String { rawValue }

        var label: String {
            switch self {
            case .lostBall: return "Lost ball"
            case .outOfBounds: return "Out of bounds"
            case .unplayable: return "Unplayable lie"
            case .water: return "Water hazard"
            }
        }

        var subtitle: String {
            switch self {
            case .lostBall: return "Stroke + distance · re-hit from previous"
            case .outOfBounds: return "Stroke + distance · re-hit from previous"
            case .unplayable: return "+1 penalty · drop within 2 club lengths"
            case .water: return "+1 penalty · drop where it crossed"
            }
        }

        var iconName: String {
            switch self {
            case .lostBall: return "questionmark.circle.fill"
            case .outOfBounds: return "rectangle.dashed"
            case .unplayable: return "leaf.fill"
            case .water: return "water.waves"
            }
        }

        var noteText: String {
            switch self {
            case .lostBall: return "Lost ball penalty"
            case .outOfBounds: return "OB penalty"
            case .unplayable: return "Unplayable lie"
            case .water: return "Water hazard"
            }
        }

        /// Stroke-and-distance penalties (lost ball, OB) require the
        /// player to replay the shot from the previous spot. We log a
        /// single +1 penalty here; the replay shot is logged by the
        /// player's next shot entry as normal.
        var dropCount: Int {
            switch self {
            case .unplayable, .water: return 1
            case .lostBall, .outOfBounds: return 0
            }
        }
    }

    struct MapCoordinate: Equatable, Codable {
        let latitude: Double
        let longitude: Double

        var clLocationCoordinate2D: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    struct BallMarkState: Equatable, Codable {
        let coordinate: MapCoordinate
        let headingDegrees: Double
        let recordedAt: Date
    }

    struct Snapshot: Equatable, Codable {
        let hole: HoleSession
        let holeSessions: [HoleSession]
        let activeHoleIndex: Int
        let displayedHoleIndex: Int
        let courseName: String
        let courseCoordinate: MapCoordinate
        let courseHoles: [SwingPalCourse.Hole]
        let selectedTeeName: String?
        let selectedTeeYards: Int?
        let players: [RoundPlayerDraft]
        let selectedClubName: String
        let distanceToPinMeters: Int
        let mapRotationDegrees: Double
        let mapPanOffset: CodableSize
        let planningTargetCoordinate: MapCoordinate
        let reviewPlayers: [PlayerScoreState]
        let playerLocation: RoundLocationSnapshot?
        let ballMarkState: BallMarkState?
        let lastLoggedShotOriginCoordinate: MapCoordinate?
        let lastLoggedShotOriginSource: ShotOriginSource?
        let lastLoggedShotTargetCoordinate: MapCoordinate?
        let lastLoggedShotTargetLabel: String?
        let ballMarkSuggestionBaselineCoordinate: MapCoordinate?

        private enum CodingKeys: String, CodingKey {
            case hole
            case holeSessions
            case activeHoleIndex
            case displayedHoleIndex
            case courseName
            case courseCoordinate
            case courseHoles
            case selectedTeeName
            case selectedTeeYards
            case players
            case selectedClubName
            case distanceToPinMeters
            case mapRotationDegrees
            case mapPanOffset
            case planningTargetCoordinate
            case reviewPlayers
            case playerLocation
            case ballMarkState
            case lastLoggedShotOriginCoordinate
            case lastLoggedShotOriginSource
            case lastLoggedShotTargetCoordinate
            case lastLoggedShotTargetLabel
            case ballMarkSuggestionBaselineCoordinate
        }

        init(
            hole: HoleSession,
            holeSessions: [HoleSession],
            activeHoleIndex: Int,
            displayedHoleIndex: Int,
            courseName: String,
            courseCoordinate: MapCoordinate,
            courseHoles: [SwingPalCourse.Hole],
            selectedTeeName: String? = nil,
            selectedTeeYards: Int? = nil,
            players: [RoundPlayerDraft],
            selectedClubName: String,
            distanceToPinMeters: Int,
            mapRotationDegrees: Double,
            mapPanOffset: CodableSize,
            planningTargetCoordinate: MapCoordinate,
            reviewPlayers: [PlayerScoreState],
            playerLocation: RoundLocationSnapshot?,
            ballMarkState: BallMarkState?,
            lastLoggedShotOriginCoordinate: MapCoordinate?,
            lastLoggedShotOriginSource: ShotOriginSource?,
            lastLoggedShotTargetCoordinate: MapCoordinate?,
            lastLoggedShotTargetLabel: String?,
            ballMarkSuggestionBaselineCoordinate: MapCoordinate?
        ) {
            self.hole = hole
            self.holeSessions = holeSessions
            self.activeHoleIndex = activeHoleIndex
            self.displayedHoleIndex = displayedHoleIndex
            self.courseName = courseName
            self.courseCoordinate = courseCoordinate
            self.courseHoles = courseHoles
            self.selectedTeeName = selectedTeeName
            self.selectedTeeYards = selectedTeeYards
            self.players = players
            self.selectedClubName = selectedClubName
            self.distanceToPinMeters = distanceToPinMeters
            self.mapRotationDegrees = mapRotationDegrees
            self.mapPanOffset = mapPanOffset
            self.planningTargetCoordinate = planningTargetCoordinate
            self.reviewPlayers = reviewPlayers
            self.playerLocation = playerLocation
            self.ballMarkState = ballMarkState
            self.lastLoggedShotOriginCoordinate = lastLoggedShotOriginCoordinate
            self.lastLoggedShotOriginSource = lastLoggedShotOriginSource
            self.lastLoggedShotTargetCoordinate = lastLoggedShotTargetCoordinate
            self.lastLoggedShotTargetLabel = lastLoggedShotTargetLabel
            self.ballMarkSuggestionBaselineCoordinate = ballMarkSuggestionBaselineCoordinate
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let hole = try container.decode(HoleSession.self, forKey: .hole)
            let courseHoles = try container.decode([SwingPalCourse.Hole].self, forKey: .courseHoles)

            let fallbackActiveHoleIndex = courseHoles.firstIndex(where: { $0.number == hole.number }) ?? 0
            let decodedHoleSessions = try container.decodeIfPresent([HoleSession].self, forKey: .holeSessions)
            let resolvedHoleSessions = Self.resolveHoleSessions(
                decodedHoleSessions,
                courseHoles: courseHoles,
                fallbackActiveHole: hole
            )
            let resolvedActiveHoleIndex = Self.clampedIndex(
                try container.decodeIfPresent(Int.self, forKey: .activeHoleIndex) ?? fallbackActiveHoleIndex,
                upperBound: resolvedHoleSessions.count
            )
            let resolvedDisplayedHoleIndex = Self.clampedIndex(
                try container.decodeIfPresent(Int.self, forKey: .displayedHoleIndex) ?? resolvedActiveHoleIndex,
                upperBound: resolvedHoleSessions.count
            )

            self.init(
                hole: resolvedHoleSessions[resolvedActiveHoleIndex],
                holeSessions: resolvedHoleSessions,
                activeHoleIndex: resolvedActiveHoleIndex,
                displayedHoleIndex: resolvedDisplayedHoleIndex,
                courseName: try container.decode(String.self, forKey: .courseName),
                courseCoordinate: try container.decode(MapCoordinate.self, forKey: .courseCoordinate),
                courseHoles: courseHoles,
                selectedTeeName: try container.decodeIfPresent(String.self, forKey: .selectedTeeName),
                selectedTeeYards: try container.decodeIfPresent(Int.self, forKey: .selectedTeeYards),
                players: try container.decode([RoundPlayerDraft].self, forKey: .players),
                selectedClubName: try container.decode(String.self, forKey: .selectedClubName),
                distanceToPinMeters: try container.decode(Int.self, forKey: .distanceToPinMeters),
                mapRotationDegrees: try container.decode(Double.self, forKey: .mapRotationDegrees),
                mapPanOffset: try container.decode(CodableSize.self, forKey: .mapPanOffset),
                planningTargetCoordinate: try container.decode(MapCoordinate.self, forKey: .planningTargetCoordinate),
                reviewPlayers: try container.decode([PlayerScoreState].self, forKey: .reviewPlayers),
                playerLocation: try container.decodeIfPresent(RoundLocationSnapshot.self, forKey: .playerLocation),
                ballMarkState: try container.decodeIfPresent(BallMarkState.self, forKey: .ballMarkState),
                lastLoggedShotOriginCoordinate: try container.decodeIfPresent(MapCoordinate.self, forKey: .lastLoggedShotOriginCoordinate),
                lastLoggedShotOriginSource: try container.decodeIfPresent(ShotOriginSource.self, forKey: .lastLoggedShotOriginSource),
                lastLoggedShotTargetCoordinate: try container.decodeIfPresent(MapCoordinate.self, forKey: .lastLoggedShotTargetCoordinate),
                lastLoggedShotTargetLabel: try container.decodeIfPresent(String.self, forKey: .lastLoggedShotTargetLabel),
                ballMarkSuggestionBaselineCoordinate: try container.decodeIfPresent(MapCoordinate.self, forKey: .ballMarkSuggestionBaselineCoordinate)
            )
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(hole, forKey: .hole)
            try container.encode(holeSessions, forKey: .holeSessions)
            try container.encode(activeHoleIndex, forKey: .activeHoleIndex)
            try container.encode(displayedHoleIndex, forKey: .displayedHoleIndex)
            try container.encode(courseName, forKey: .courseName)
            try container.encode(courseCoordinate, forKey: .courseCoordinate)
            try container.encode(courseHoles, forKey: .courseHoles)
            try container.encodeIfPresent(selectedTeeName, forKey: .selectedTeeName)
            try container.encodeIfPresent(selectedTeeYards, forKey: .selectedTeeYards)
            try container.encode(players, forKey: .players)
            try container.encode(selectedClubName, forKey: .selectedClubName)
            try container.encode(distanceToPinMeters, forKey: .distanceToPinMeters)
            try container.encode(mapRotationDegrees, forKey: .mapRotationDegrees)
            try container.encode(mapPanOffset, forKey: .mapPanOffset)
            try container.encode(planningTargetCoordinate, forKey: .planningTargetCoordinate)
            try container.encode(reviewPlayers, forKey: .reviewPlayers)
            try container.encodeIfPresent(playerLocation, forKey: .playerLocation)
            try container.encodeIfPresent(ballMarkState, forKey: .ballMarkState)
            try container.encodeIfPresent(lastLoggedShotOriginCoordinate, forKey: .lastLoggedShotOriginCoordinate)
            try container.encodeIfPresent(lastLoggedShotOriginSource, forKey: .lastLoggedShotOriginSource)
            try container.encodeIfPresent(lastLoggedShotTargetCoordinate, forKey: .lastLoggedShotTargetCoordinate)
            try container.encodeIfPresent(lastLoggedShotTargetLabel, forKey: .lastLoggedShotTargetLabel)
            try container.encodeIfPresent(ballMarkSuggestionBaselineCoordinate, forKey: .ballMarkSuggestionBaselineCoordinate)
        }

        private static func resolveHoleSessions(
            _ decodedHoleSessions: [HoleSession]?,
            courseHoles: [SwingPalCourse.Hole],
            fallbackActiveHole: HoleSession
        ) -> [HoleSession] {
            guard !courseHoles.isEmpty else {
                return decodedHoleSessions ?? [fallbackActiveHole]
            }
            guard let decodedHoleSessions else {
                return courseHoles.map { courseHole in
                    if courseHole.number == fallbackActiveHole.number {
                        return fallbackActiveHole
                    }
                    return HoleSession(number: courseHole.number, par: courseHole.par)
                }
            }
            guard decodedHoleSessions.count == courseHoles.count else {
                let sessionsByNumber = decodedHoleSessions.reduce(into: [Int: HoleSession]()) { partialResult, session in
                    partialResult[session.number] = session
                }
                return courseHoles.map { courseHole in
                    if let decodedSession = sessionsByNumber[courseHole.number] {
                        return HoleSession(
                            number: courseHole.number,
                            par: courseHole.par,
                            recordedScore: decodedSession.recordedScore,
                            recordedPutts: decodedSession.recordedPutts,
                            recordedPenaltyCount: decodedSession.recordedPenaltyCount,
                            recordedDropCount: decodedSession.recordedDropCount,
                            recordedShotOutcomeSummary: decodedSession.recordedShotOutcomeSummary,
                            recordedClubCorrectionSummary: decodedSession.recordedClubCorrectionSummary,
                            recordedNotes: decodedSession.recordedNotes,
                            isConfirmed: decodedSession.isConfirmed,
                            wasEditedAfterConfirmation: decodedSession.wasEditedAfterConfirmation,
                            shots: decodedSession.shots
                        )
                    }
                    if courseHole.number == fallbackActiveHole.number {
                        return fallbackActiveHole
                    }
                    return HoleSession(number: courseHole.number, par: courseHole.par)
                }
            }
            return decodedHoleSessions.enumerated().map { index, session in
                let hole = courseHoles[index]
                // Par always comes from the course (older saves could carry a default).
                guard session.number == hole.number, session.par == hole.par else {
                    return HoleSession(
                        number: hole.number,
                        par: hole.par,
                        recordedScore: session.recordedScore,
                        recordedPutts: session.recordedPutts,
                        recordedPenaltyCount: session.recordedPenaltyCount,
                        recordedDropCount: session.recordedDropCount,
                        recordedShotOutcomeSummary: session.recordedShotOutcomeSummary,
                        recordedClubCorrectionSummary: session.recordedClubCorrectionSummary,
                        recordedNotes: session.recordedNotes,
                        isConfirmed: session.isConfirmed,
                        wasEditedAfterConfirmation: session.wasEditedAfterConfirmation,
                        shots: session.shots
                    )
                }
                return session
            }
        }

        private static func clampedIndex(_ candidate: Int, upperBound: Int) -> Int {
            guard upperBound > 0 else { return 0 }
            return min(max(candidate, 0), upperBound - 1)
        }
    }

    struct CodableSize: Equatable, Codable {
        let width: Double
        let height: Double

        init(_ size: CGSize) {
            width = size.width
            height = size.height
        }

        var cgSize: CGSize {
            CGSize(width: width, height: height)
        }
    }

    enum ShotPhase: Equatable {
        case teeShot
        case approach
        case scoring
        case greenSide

    }

    static let defaultClubNames = [
        "Driver",
        "3W",
        "5W",
        "4i",
        "5i",
        "6i",
        "7i",
        "8i",
        "9i",
        "PW",
        "SW",
        "Putter"
    ]

    static let amateurBaselineCarryMetersByClubName: [String: Int] = [
        "Driver": 200,
        "3W": 185,
        "5W": 174,
        "4i": 164,
        "5i": 155,
        "6i": 141,
        "7i": 128,
        "8i": 119,
        "9i": 110,
        "PW": 96,
        "SW": 73,
        "Putter": 10
    ]
    private static let fallbackCarryMeters = amateurBaselineCarryMetersByClubName["7i"] ?? 128

    @Published var hole: HoleSession {
        didSet {
            syncActiveHoleSession()
            notifyRoundUpdated()
        }
    }
    @Published private(set) var displayedHoleIndex: Int {
        didSet { notifyRoundUpdated() }
    }
    @Published var selectedClubName: String = "Driver" {
        didSet { notifyRoundUpdated() }
    }
    @Published var distanceToPinMeters: Int = 152 {
        didSet { notifyRoundUpdated() }
    }
    @Published private(set) var mapRotationDegrees: Double = 0 {
        didSet { notifyRoundUpdated() }
    }
    @Published private(set) var mapPanOffset: CGSize = .zero {
        didSet { notifyRoundUpdated() }
    }
    @Published private(set) var planningTargetCoordinate: MapCoordinate {
        didSet { notifyRoundUpdated() }
    }
    private var storedReviewPlayers: [PlayerScoreState]

    /// Only the owner has a score stream. Companion players remain untracked.
    var reviewPlayers: [PlayerScoreState] {
        storedReviewPlayers.map { player in
            guard !player.isGuest else { return player }
            var review = player
            let hasScore = holeSessions.contains { $0.recordedScore != nil || !$0.shots.isEmpty }
            review.strokes = hasScore ? roundTotalStrokes : nil
            review.status = canCompleteRound ? .confirmed : (hasScore ? .edited : .pending)
            return review
        }
    }

    var roundTotalStrokes: Int {
        holeSessions.reduce(0) { $0 + $1.totalScore }
    }

    var roundTotalHoleCount: Int { holeSessions.count }

    var canCompleteRound: Bool {
        players.contains { $0.kind == .selfPlayer }
            && !holeSessions.isEmpty
            && holeSessions.allSatisfy { $0.isConfirmed && ($0.recordedScore ?? 0) > 0 }
    }
    @Published private(set) var weatherSnapshot: RoundWeatherSnapshot?
    @Published private(set) var playerLocation: RoundLocationSnapshot? {
        didSet {
            refreshLivePinDistanceFromCurrentLocationIfPossible()
            notifyRoundUpdated()
        }
    }
    @Published private(set) var ballMarkState: BallMarkState? {
        didSet { notifyRoundUpdated() }
    }
    @Published private(set) var lastLoggedShotOriginCoordinate: MapCoordinate? {
        didSet { notifyRoundUpdated() }
    }
    @Published private(set) var lastLoggedShotOriginSource: ShotOriginSource? {
        didSet { notifyRoundUpdated() }
    }
    @Published private(set) var lastLoggedShotTargetCoordinate: MapCoordinate? {
        didSet { notifyRoundUpdated() }
    }
    @Published private(set) var lastLoggedShotTargetLabel: String? {
        didSet { notifyRoundUpdated() }
    }
    @Published private(set) var ballMarkSuggestionBaselineCoordinate: MapCoordinate? {
        didSet { notifyRoundUpdated() }
    }
    @Published private(set) var locationStatus: RoundLocationStatus = .locating {
        didSet { notifyRoundUpdated() }
    }
    @Published private(set) var isShowingClubPicker = false
    @Published private(set) var isShowingClubWheel = false
    /// User preference for whether the club wheel should highlight a
    /// recommended club (and visually mute out-of-range options) for the
    /// current shot. When `false`, the wheel reverts to a "manual" picker:
    /// every club shows at full strength with no REC badge, no muting, and
    /// no auto-putter mode. The default is `true` because most golfers want
    /// the assist; players who prefer to think for themselves can flip it
    /// off from inside the wheel and the choice persists across rounds.
    @Published private(set) var isClubAutoRecommendationEnabled: Bool = true {
        didSet { notifyRoundUpdated() }
    }
    @Published private(set) var isShowingShotLogger = false
    @Published private(set) var isShowingHoleConfirmation = false
    @Published private(set) var launcherDetent: LauncherDetent = .collapsed
    /// Pill banner that surfaces at the top of the map after a holed
    /// putt is logged, suggesting the player tap once to confirm the
    /// hole + advance. Auto-dismisses if the player logs another shot
    /// on the same hole (e.g. they were just practicing tap-ins) or
    /// undoes the holed putt.
    @Published private(set) var isShowingHoleConfirmationPill = false
    /// Confirmation popover that surfaces when the player taps
    /// "Undo last shot" so a fat-finger doesn't silently destroy data.
    /// The bound preview drives the popover copy ("Undo 7-iron from
    /// fairway?") and is non-nil while the popover is visible.
    @Published private(set) var pendingUndoPreview: LoggedShotPreview?
    /// "Undid 7-iron" toast that flashes briefly after the undo
    /// completes so the player can tell what was rolled back. Cleared
    /// either by `acknowledgeUndoneShotPreview()` (timeout / tap) or
    /// when the next shot is logged.
    @Published private(set) var lastUndoneShotPreview: LoggedShotPreview?
    /// Picker sheet for the "Quick penalty" tray action (lost ball,
    /// OB, unplayable, water).
    @Published private(set) var isShowingQuickPenaltyPicker = false
    /// Confirmation sheet for the "Re-tee" tray action — adds a +1
    /// penalty and resets the next pending shot to a tee shot.
    @Published private(set) var isShowingReteeConfirmation = false
    /// Single-level undo snapshot: present when the most recent
    /// `logShot` call has a roll-back point. Cleared after each undo,
    /// after hole transitions, and after hole confirmation.
    @Published private(set) var lastShotUndoSnapshot: ShotUndoSnapshot?
    @Published private(set) var pendingShotClubName: String
    @Published private(set) var pendingShotStrokeNumber: Int
    @Published private(set) var pendingShotPenaltyCount: Int = 0
    @Published private(set) var pendingShotDropCount: Int = 0
    @Published private(set) var pendingShotSurface: ShotEvent.Surface = .fairway
    @Published private(set) var pendingShotDirection: ShotEvent.DirectionResult?
    @Published private(set) var pendingShotDistance: ShotEvent.DistanceResult?
    @Published private(set) var pendingShotStrike: ShotEvent.StrikeResult?
    @Published private(set) var pendingShotType: ShotEvent.ShotType?
    @Published private(set) var pendingShotPuttCount: Int?
    @Published private(set) var pendingShotFirstPuttDistanceMeters: Int?
    @Published private(set) var pendingShotNote: String?
    /// Putt-context only. `nil` until the player explicitly chooses one of
    /// "Holed" / "Missed" — confirm is gated on this so we never accidentally
    /// log an ambiguous putt event.
    @Published private(set) var pendingShotPuttHoled: Bool?
    /// Putt-context only. The cardinal direction the missed putt finished
    /// in relative to the cup. Defaults to `nil` (centre / no quantitative
    /// miss); used to populate the `direction` field on the persisted event.
    @Published private(set) var pendingShotPuttMissDirection: ShotEvent.DirectionResult?
    /// Putt-context only. The categorical short / on-the-line / long
    /// classification driven by the putt-miss outcome dial. Defaults to
    /// `nil` (player hasn't picked a long/short axis yet); fed into the
    /// persisted event's `distanceResult` field at confirm time.
    @Published private(set) var pendingShotPuttMissDistance: ShotEvent.DistanceResult?
    /// Putt-context only. How far past / short of the cup the missed putt
    /// finished, in metres. Defaults to `nil` (player skipped the field).
    @Published private(set) var pendingShotPuttMissDistanceMeters: Int?
    /// Whether the user has explicitly opened the "Add detail" disclosure
    /// in the redesigned sheet. Driven from the view layer; we keep it here
    /// so the choice persists across sheet repositioning / detent changes.
    @Published var isShowingShotLoggerAddDetail: Bool = false
    @Published private(set) var pendingHoleScore: Int?
    @Published private(set) var pendingHolePutts: Int?
    @Published private(set) var pendingHolePenaltyCount: Int?
    @Published private(set) var pendingHoleDropCount: Int?
    @Published private(set) var pendingHoleShotOutcomeSummary: String?
    @Published private(set) var pendingHoleClubCorrectionSummary: String?
    @Published private(set) var pendingHoleNotes: String?
    @Published private(set) var shotLogConfirmationCount: Int = 0

    let courseName: String
    let courseCoordinate: MapCoordinate
    let courseHoles: [SwingPalCourse.Hole]
    let selectedTeeName: String?
    let selectedTeeYards: Int?
    private let weatherLoader: RoundWeatherLoading
    private let locationProvider: RoundLocationProviding
    private let players: [RoundPlayerDraft]
    private let clubCarryMetersByClubName: [String: Int]
    private var roundCompanionSync: RoundCompanionSyncing
    private var isCompanionSyncSuppressed = false
    private var activeRoundCompanionMutationSourceContext: RoundCompanionMutationSource?
    private var lastRoundCompanionMutationSource: RoundCompanionMutationSource = .phone
    private var lastRoundCompanionMutationAt: Date = .now
    private var roundCompanionConnectionState: RoundCompanionConnectionState = .connected
    private var holeSessions: [HoleSession]
    private var activeHoleIndex: Int

    private let panLimit: CGFloat = 180
    private let ballMarkSuggestionThresholdMeters: CLLocationDistance = 20

    var onRoundUpdated: (() -> Void)?
    /// Fires when the user toggles the club-wheel auto-recommendation setting
    /// from inside the wheel UI. AppState wires this up so the choice can be
    /// written to the persistent UserDefaults store and used by the next
    /// round.
    var onClubAutoRecommendationPreferenceChanged: ((Bool) -> Void)?

    private(set) var distanceUnit: DistanceUnit = .meters

    var roundCompanionSnapshot: RoundCompanionSnapshot {
        let session = displayedHoleSessionState
        return .init(
            distanceUnit: distanceUnit,
            holeNumber: session.number,
            par: session.par,
            selectedClubName: selectedClubName,
            availableClubNames: availableClubNames,
            frontDistanceMeters: displayedFrontDistanceMeters,
            distanceToTargetMeters: displayedPinDistanceMeters,
            backDistanceMeters: displayedBackDistanceMeters,
            loggedShotCount: session.shots.count,
            shotNumber: max(1, session.strokeCount + 1),
            puttCount: displayedHolePuttCount,
            penaltyCount: displayedHolePenaltyCount,
            currentSurface: roundCompanionCurrentSurface,
            holeScore: displayedHoleScore,
            canFinishHole: isShowingHoleConfirmation && canConfirmHoleSummary,
            isInspectingHole: isInspectingHole,
            lastMutationSource: lastRoundCompanionMutationSource,
            lastMutationAt: lastRoundCompanionMutationAt,
            connectionState: roundCompanionConnectionState,
            previewSpec: roundCompanionPreviewSpec
        )
    }

    func setDistanceUnit(_ unit: DistanceUnit) {
        guard distanceUnit != unit else { return }
        distanceUnit = unit
        publishRoundCompanionSnapshot()
        onRoundUpdated?()
    }

    func shortDistanceLabel(forMeters meters: Int) -> String {
        distanceUnit.shortLabel(forMeters: meters)
    }

    private var roundCompanionPreviewSpec: RoundCompanionPreviewSpec? {
        guard let displayedHole else {
            return nil
        }

        guard let holeBounds = RoundCompanionPreviewCorridorBounds.resolve(for: displayedHole) else {
            return nil
        }

        let origin = currentShotOriginCoordinate
            ?? .init(latitude: teeCoordinate.latitude, longitude: teeCoordinate.longitude)
        let target = planningTargetCoordinate

        return .init(
            holeBounds: holeBounds,
            originCoordinate: .init(
                latitude: origin.latitude,
                longitude: origin.longitude
            ),
            targetCoordinate: .init(
                latitude: target.latitude,
                longitude: target.longitude
            )
        )
    }

    var snapshot: Snapshot {
        .init(
            hole: hole,
            holeSessions: holeSessions,
            activeHoleIndex: activeHoleIndex,
            displayedHoleIndex: displayedHoleIndex,
            courseName: courseName,
            courseCoordinate: courseCoordinate,
            courseHoles: courseHoles,
            selectedTeeName: selectedTeeName,
            selectedTeeYards: selectedTeeYards,
            players: players,
            selectedClubName: selectedClubName,
            distanceToPinMeters: distanceToPinMeters,
            mapRotationDegrees: mapRotationDegrees,
            mapPanOffset: .init(mapPanOffset),
            planningTargetCoordinate: planningTargetCoordinate,
            reviewPlayers: reviewPlayers,
            playerLocation: playerLocation,
            ballMarkState: ballMarkState,
            lastLoggedShotOriginCoordinate: lastLoggedShotOriginCoordinate,
            lastLoggedShotOriginSource: lastLoggedShotOriginSource,
            lastLoggedShotTargetCoordinate: lastLoggedShotTargetCoordinate,
            lastLoggedShotTargetLabel: lastLoggedShotTargetLabel,
            ballMarkSuggestionBaselineCoordinate: ballMarkSuggestionBaselineCoordinate
        )
    }

    /// "Plays-Like" pin distance for the **live** hole (player → pin), with
    /// wind and temperature adjustments folded into the raw GPS yardage. Used
    /// by the legacy `leadingInstrumentMetrics` HUD and by the watch companion
    /// payload. UI surfaces should prefer `displayedPlaysLikeDistanceMeters`
    /// because it also returns a sensible value while the user is inspecting
    /// other holes.
    var playsLikeDistanceMeters: Int {
        PlaysLikeCalculator.adjustedMeters(
            baseMeters: distanceToPinMeters,
            shotBearingDegrees: Self.bearing(from: playerCoordinate, to: targetCoordinate),
            weather: weatherSnapshot
        )
    }

    /// Plays-Like for whichever hole is currently displayed (live or under
    /// inspection). The base distance is `displayedPinDistanceMeters` so the
    /// number stays meaningful when the user is peeking at other holes - we
    /// just won't have a player-position bearing for those, so wind direction
    /// is treated as "from where you'd play this hole" using the tee→pin
    /// bearing instead.
    var displayedPlaysLikeDistanceMeters: Int {
        let bearing: CLLocationDirection
        if isDisplayedHoleLive {
            bearing = Self.bearing(from: playerCoordinate, to: targetCoordinate)
        } else if let displayedTee = primaryFeatureCoordinate(for: .tee) {
            bearing = Self.bearing(from: displayedTee, to: targetCoordinate)
        } else {
            bearing = Self.bearing(from: teeCoordinate, to: targetCoordinate)
        }
        return PlaysLikeCalculator.adjustedMeters(
            baseMeters: displayedPinDistanceMeters,
            shotBearingDegrees: bearing,
            weather: weatherSnapshot
        )
    }

    var availableClubNames: [String] {
        let selectedClub = Self.canonicalClubName(selectedClubName)
        let bagClubNames = normalizedBagClubNames

        guard !bagClubNames.isEmpty else {
            guard !Self.containsClubNamed(selectedClub, in: Self.defaultClubNames) else {
                return Self.defaultClubNames
            }
            return Self.defaultClubNames + [selectedClub]
        }

        guard !Self.containsClubNamed(selectedClub, in: bagClubNames) else {
            return bagClubNames
        }
        return bagClubNames + [selectedClub]
    }

    /// Clubs the wheel UI should expose to the player.
    ///
    /// In **auto** mode this matches `availableClubNames` so the
    /// recommendation engine only considers clubs the player actually
    /// carries (their logged carry data drives the gap math).
    ///
    /// In **manual** mode we widen the set to the full standard 12-club
    /// catalog plus any custom-named bag clubs the player has added (e.g.
    /// "Driving Iron"). This way a sparse bag doesn't hide common clubs
    /// when the player wants to grab anything for a trick shot — the
    /// wheel becomes a true picker rather than a bag-shaped subset.
    var clubWheelDisplayedClubNames: [String] {
        guard !isClubAutoRecommendationEnabled else {
            return filteredAutoClubNames(
                from: availableClubNames,
                targetDistanceMeters: clubWheelTargetDistanceMeters,
                recommendedClubName: recommendedClubName,
                selectedClubName: selectedClubName,
                isPutterMode: isClubWheelInPutterMode,
                shotLoggerContext: currentShotLoggerContext
            )
        }

        let standardCanonical = Set(Self.defaultClubNames.map(Self.canonicalClubName))
        let bagClubs = normalizedBagClubNames
        let selectedClub = Self.canonicalClubName(selectedClubName)

        var seen = Set<String>()
        var result: [String] = []

        for clubName in Self.defaultClubNames {
            let canonical = Self.canonicalClubName(clubName)
            if seen.insert(canonical).inserted {
                result.append(clubName)
            }
        }

        for clubName in bagClubs {
            let canonical = Self.canonicalClubName(clubName)
            // Only append custom-named bag clubs (e.g. "Driving Iron").
            // Standard clubs are already covered above and we want to
            // preserve the canonical 12-club ordering.
            guard !standardCanonical.contains(canonical) else { continue }
            if seen.insert(canonical).inserted {
                result.append(clubName)
            }
        }

        if seen.insert(selectedClub).inserted {
            result.append(selectedClub)
        }

        return result
    }

    /// Bump-and-run / long chip: keep putter-like clubs available. Beyond this,
    /// full-swing and approach lists stay free of putters so the wheel matches intent.
    private static let autoClubWheelPutterChipMaxTargetMeters = 34

    private func filteredAutoClubNames(
        from candidates: [String],
        targetDistanceMeters: Int,
        recommendedClubName: String?,
        selectedClubName: String,
        isPutterMode: Bool,
        shotLoggerContext: ShotLoggerContext
    ) -> [String] {
        let canonicalSelected = Self.canonicalClubName(selectedClubName)
        let canonicalRecommended = recommendedClubName.map(Self.canonicalClubName)

        let phasePool: [String] = {
            let filtered = candidates.filter { name in
                !Self.shouldExcludePutterLikeFromAutoWheel(
                    clubName: name,
                    shotLoggerContext: shotLoggerContext,
                    targetMeters: targetDistanceMeters,
                    isPutterMode: isPutterMode
                )
            }
            return filtered.isEmpty ? candidates : filtered
        }()

        // In putter mode we only need a putter-like club (and always allow the
        // user's currently selected club when it isn't already listed).
        if isPutterMode {
            var result: [String] = []
            if let putterClub = candidates.first(where: { Self.isLikelyPutterCarryName($0) }) {
                result.append(putterClub)
            }
            if let selected = candidates.first(where: { Self.canonicalClubName($0) == canonicalSelected }),
               !result.contains(where: { Self.canonicalClubName($0) == canonicalSelected }) {
                result.append(selected)
            }
            return result.isEmpty ? candidates : uniquePreservingOrder(result)
        }

        // When there's no usable target distance yet, keep the list small:
        // show the long clubs first, plus selected + recommended.
        if targetDistanceMeters <= 0 {
            let sortedByCarry = phasePool.sorted { displayCarryMeters(for: $0) > displayCarryMeters(for: $1) }
            var seeded = Array(sortedByCarry.prefix(7))
            if let rec = canonicalRecommended,
               let match = candidates.first(where: { Self.canonicalClubName($0) == rec }) {
                seeded.append(match)
            }
            if let match = candidates.first(where: { Self.canonicalClubName($0) == canonicalSelected }) {
                seeded.append(match)
            }
            return uniquePreservingOrder(seeded)
        }

        // Main filter: keep clubs that are plausibly close to the target.
        // This trims out short clubs (e.g. putters) during tee shots.
        let toleranceMeters = max(25, Int(Double(targetDistanceMeters) * 0.25))
        let scored = phasePool.map { clubName -> (clubName: String, absGap: Int) in
            let gap = abs(displayCarryMeters(for: clubName) - targetDistanceMeters)
            return (clubName, gap)
        }
        let close = scored
            .filter { $0.absGap <= toleranceMeters }
            .sorted { $0.absGap < $1.absGap }
            .map(\.clubName)

        // Cap the list so the wheel stays readable.
        let capped = Array(close.prefix(9))

        var result: [String] = capped
        if let rec = canonicalRecommended,
           let match = candidates.first(where: { Self.canonicalClubName($0) == rec }) {
            result.append(match)
        }
        if let match = candidates.first(where: { Self.canonicalClubName($0) == canonicalSelected }) {
            result.append(match)
        }

        // Always keep at least a few long options if the filter got too strict.
        if result.count < 5 {
            let sortedByCarry = phasePool.sorted { displayCarryMeters(for: $0) > displayCarryMeters(for: $1) }
            result.append(contentsOf: sortedByCarry.prefix(6))
        }

        return uniquePreservingOrder(result)
    }

    /// Catalog / custom putter names that are not in `defaultClubNames` used to inherit the
    /// generic iron fallback carry; treat them like a putter for distance math and wheel UX.
    private static func isLikelyPutterCarryName(_ clubName: String) -> Bool {
        let trimmed = clubName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if canonicalClubName(trimmed).caseInsensitiveCompare("Putter") == .orderedSame {
            return true
        }
        let lower = trimmed.lowercased()
        if lower.contains("putter") { return true }
        if lower.contains("mallet") { return true }
        return false
    }

    private static func shouldExcludePutterLikeFromAutoWheel(
        clubName: String,
        shotLoggerContext: ShotLoggerContext,
        targetMeters: Int,
        isPutterMode: Bool
    ) -> Bool {
        guard !isPutterMode else { return false }
        guard isLikelyPutterCarryName(clubName) else { return false }
        switch shotLoggerContext {
        case .tee:
            return true
        case .putt:
            return false
        case .shot:
            return targetMeters > autoClubWheelPutterChipMaxTargetMeters
        }
    }

    private func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(values.count)
        for value in values {
            let canonical = Self.canonicalClubName(value)
            if seen.insert(canonical).inserted {
                result.append(value)
            }
        }
        return result
    }

    var shotLoggingTitle: String {
        if targetLabel == "Target unavailable" { return "\(pendingShotClubName) • Target unavailable" }
        return "\(pendingShotClubName) • \(shortDistanceLabel(forMeters: displayedPinDistanceMeters)) to green centre"
    }

    var currentPlayerTotalPutts: Int {
        displayedHolePuttCount
    }

    // MARK: - Shot history row classification

    /// Returns the rendering category for a logged shot. The rule is:
    /// 1. If the event was synthesised by the quick-penalty / re-tee
    ///    paths (their marker club name), it's a `.penalty`.
    /// 2. Otherwise, putts (`shotType == .putt`) get the dedicated putt
    ///    summary copy.
    /// 3. Everything else falls back to the generic shot summary.
    func shotHistoryEntryKind(for shot: ShotEvent) -> ShotHistoryEntryKind {
        if shot.clubName == Self.syntheticPenaltyClubName {
            return .penalty
        }
        if shot.shotType == .putt {
            return .putt
        }
        return .shot
    }

    /// Plain-language subtitle rendered under "Stroke N" in the shot
    /// history list. The rule per kind:
    /// - `.penalty`: the note (e.g. "Lost ball penalty"), with a
    ///    "+1 stroke" suffix and an optional "+1 drop" qualifier.
    /// - `.putt`: "Holed" or "Missed (right · long)" — direction +
    ///    categorical distance fall back gracefully when either is
    ///    unset, and a literal miss-distance in metres is appended
    ///    when present.
    /// - `.shot`: the legacy "Xm • Direction • DistanceResult" string,
    ///    extended with " · +N penalty / +N drop" when those fields
    ///    were captured alongside a real swing.
    func shotHistorySubtitle(for shot: ShotEvent) -> String {
        switch shotHistoryEntryKind(for: shot) {
        case .penalty:
            var parts: [String] = []
            if let note = shot.note, !note.isEmpty {
                parts.append(note)
            } else {
                parts.append("Penalty stroke")
            }
            parts.append("+1 stroke")
            if shot.dropCount > 0 {
                parts.append("+\(shot.dropCount) drop\(shot.dropCount == 1 ? "" : "s")")
            }
            return parts.joined(separator: " • ")

        case .putt:
            guard let detail = shot.puttDetail else {
                return "Putt"
            }
            if detail.holed {
                return "Holed"
            }
            var qualifiers: [String] = []
            if shot.direction != .hit {
                qualifiers.append(Self.shotHistoryDirectionLabel(for: shot.direction))
            }
            if shot.distanceResult != .onNumber {
                qualifiers.append(Self.shotHistoryDistanceLabel(for: shot.distanceResult))
            }
            if let meters = detail.missDistanceMeters, meters > 0 {
                qualifiers.append(distanceUnit.shortLabel(forMeters: meters))
            }
            if qualifiers.isEmpty {
                return "Missed"
            }
            return "Missed • \(qualifiers.joined(separator: " · "))"

        case .shot:
            var parts: [String] = [
                distanceUnit.shortLabel(forMeters: max(0, shot.distanceToTargetMeters)),
                Self.shotHistoryDirectionLabel(for: shot.direction),
                Self.shotHistoryDistanceLabel(for: shot.distanceResult)
            ]
            var extras: [String] = []
            if shot.penaltyCount > 0 {
                extras.append("+\(shot.penaltyCount) penalty")
            }
            if shot.dropCount > 0 {
                extras.append("+\(shot.dropCount) drop\(shot.dropCount == 1 ? "" : "s")")
            }
            let baseLine = parts.joined(separator: " • ")
            return extras.isEmpty ? baseLine : "\(baseLine) · \(extras.joined(separator: " · "))"
        }
    }

    /// Optional secondary line rendered below `shotHistorySubtitle`.
    /// Returns `nil` when there's nothing meaningful to show — the
    /// view layer should hide the row entirely in that case rather
    /// than rendering a stray empty `Text`.
    func shotHistoryDetail(for shot: ShotEvent) -> String? {
        switch shotHistoryEntryKind(for: shot) {
        case .penalty:
            return nil
        case .putt:
            // Notes and strike quality are still meaningful even on
            // putts (e.g. "stubbed it"), so surface the note when the
            // user wrote one. Strike quality is rare on putts and
            // already captured by holed/missed; we skip it here.
            return shot.note
        case .shot:
            var detail: [String] = []
            if let shotType = shot.shotType {
                detail.append(Self.shotHistoryShotTypeLabel(for: shotType))
            }
            if let strike = shot.strikeResult {
                detail.append(Self.shotHistoryStrikeLabel(for: strike))
            }
            if let note = shot.note, !note.isEmpty {
                detail.append(note)
            }
            return detail.isEmpty ? nil : detail.joined(separator: " • ")
        }
    }

    private static func shotHistoryDirectionLabel(for direction: ShotEvent.DirectionResult) -> String {
        switch direction {
        case .hit: return "Hit"
        case .left: return "Left"
        case .farLeft: return "Far left"
        case .right: return "Right"
        case .farRight: return "Far right"
        }
    }

    private static func shotHistoryDistanceLabel(for distance: ShotEvent.DistanceResult) -> String {
        switch distance {
        case .onNumber: return "On number"
        case .long: return "Long"
        case .short: return "Short"
        }
    }

    private static func shotHistoryShotTypeLabel(for shotType: ShotEvent.ShotType) -> String {
        switch shotType {
        case .teeShot: return "Tee shot"
        case .provisionalBall: return "Provisional"
        case .approach: return "Approach"
        case .layup: return "Layup"
        case .recovery: return "Recovery"
        case .chip: return "Chip"
        case .pitch: return "Pitch"
        case .bunkerShot: return "Bunker shot"
        case .putt: return "Putt"
        }
    }

    private static func shotHistoryStrikeLabel(for strike: ShotEvent.StrikeResult) -> String {
        switch strike {
        case .pure: return "Pure"
        case .thin: return "Thin"
        case .chunk: return "Chunk"
        case .top: return "Top"
        case .slice: return "Slice"
        case .hook: return "Hook"
        }
    }

    private var normalizedBagClubNames: [String] {
        let normalized = clubCarryMetersByClubName.keys
            .map(Self.canonicalClubName)
            .reduce(into: [String]()) { partialResult, clubName in
                if !Self.containsClubNamed(clubName, in: partialResult) {
                    partialResult.append(clubName)
                }
            }

        guard !normalized.isEmpty else {
            return []
        }

        let defaultIndexByName = Dictionary(
            uniqueKeysWithValues: Self.defaultClubNames.enumerated().map { offset, clubName in
                (Self.canonicalClubName(clubName), offset)
            }
        )

        return normalized.sorted { lhs, rhs in
            switch (defaultIndexByName[lhs], defaultIndexByName[rhs]) {
            case let (left?, right?):
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
        }
    }

    /// Derived contextual mode the shot logger sheet uses to tailor its UI.
    /// The mode follows the inferred lie (`pendingShotSurface`) but falls
    /// back to "tee" on the first stroke even when the surface inference is
    /// noisy, since stroke 1 is by definition a tee shot.
    var currentShotLoggerContext: ShotLoggerContext {
        switch pendingShotSurface {
        case .green:
            return .putt
        case .tee:
            return .tee
        case .fairway, .rough, .bunker:
            return pendingShotStrokeNumber == 1 ? .tee : .shot
        }
    }

    /// User-facing primary CTA copy. Adapts to the current context so the
    /// button feels like a verb, not a settings save.
    var pendingShotConfirmCTAText: String {
        switch currentShotLoggerContext {
        case .tee:
            return "Log tee shot"
        case .shot:
            return "Log shot"
        case .putt:
            switch pendingShotPuttHoled {
            case true?:
                return "Hole out"
            case false?:
                return "Log missed putt"
            case nil:
                return "Log putt"
            }
        }
    }

    /// Title for the inferred-lie banner at the top of the sheet
    /// ("From the fairway", "On the green", "Off the tee", etc.). Driven by
    /// `pendingShotSurface` so it stays in lockstep with whatever the player
    /// last accepted (or overrode).
    var pendingShotLieBannerTitle: String {
        switch pendingShotSurface {
        case .tee: return "Off the tee"
        case .fairway: return "From the fairway"
        case .rough: return "From the rough"
        case .bunker: return "From the bunker"
        case .green: return "On the green"
        }
    }

    /// Short descriptor explaining how the inferred lie was chosen — surfaces
    /// the existing `inferredShotSurfaceContext` reasoning so the player can
    /// see at a glance whether it's high-confidence (GPS inside a feature
    /// polygon) or a phase fallback they may want to override.
    var pendingShotLieBannerSubtitle: String {
        switch inferredShotSurfaceContext {
        case .mapped(let surface, _):
            switch surface {
            case .tee: return "GPS placed you on the teeing ground"
            case .fairway: return "GPS placed you on the fairway"
            case .rough: return "GPS placed you off the short grass"
            case .bunker: return "GPS placed you in a bunker"
            case .green: return "GPS placed you on the green"
            }
        case .phaseFallback:
            return "Best guess — tap to override"
        }
    }

    var availableShotSurfaces: [ShotEvent.Surface] {
        [.tee, .fairway, .rough, .bunker, .green]
    }

    var availableShotTypes: [ShotEvent.ShotType] {
        var types: [ShotEvent.ShotType] = []
        if pendingShotSurface == .tee || pendingShotStrokeNumber == 1 {
            types.append(contentsOf: [.teeShot, .provisionalBall])
        }
        types.append(contentsOf: [.approach, .layup, .recovery, .chip, .pitch, .bunkerShot, .putt])
        return types
    }

    var displayedHoleNumber: Int {
        displayedHoleSessionState.number
    }

    var canInspectPreviousHole: Bool {
        displayedHoleIndex > 0
    }

    var canInspectNextHole: Bool {
        displayedHoleIndex < (holeSessions.count - 1)
    }

    var isInspectingHole: Bool {
        displayedHoleIndex != activeHoleIndex
    }

    var isDisplayedHoleLive: Bool {
        displayedHoleIndex == activeHoleIndex && !displayedHoleSessionState.isConfirmed
    }

    var displayedPinDistanceMeters: Int {
        let raw: Int
        if isDisplayedHoleLive {
            raw = distanceToPinMeters
        } else {
            let reference = CLLocation(
                latitude: inspectionDistanceReferenceCoordinate.latitude,
                longitude: inspectionDistanceReferenceCoordinate.longitude
            )
            let pin = CLLocation(
                latitude: displayedPinTargetCoordinate.latitude,
                longitude: displayedPinTargetCoordinate.longitude
            )
            raw = Int(reference.distance(from: pin).rounded())
        }
        return clampToHoleMaxReasonableDistance(raw)
    }

    var displayedFrontDistanceMeters: Int {
        let raw = displayedGreenDistanceExtrema?.front ?? displayedPinDistanceMeters
        return clampToHoleMaxReasonableDistance(raw)
    }

    var displayedBackDistanceMeters: Int {
        let raw = displayedGreenDistanceExtrema?.back ?? displayedPinDistanceMeters
        return clampToHoleMaxReasonableDistance(raw)
    }

    /// The longest reasonable distance on the displayed hole — `tee →
    /// back of green` (with a small buffer for slight off-line lies).
    /// We use this to clamp the player→front/pin/back numbers so that
    /// a stray GPS fix or simulator location 25 km from the course
    /// shows the back of the green instead of an absurd "25,974 m".
    /// Returns `nil` when we have no hole geometry to derive a max
    /// from, in which case we leave the raw distance untouched.
    var displayedHoleMaxReasonableDistanceMeters: Int? {
        let tee = teeCoordinate
        let teeLocation = CLLocation(latitude: tee.latitude, longitude: tee.longitude)

        let greenCoordinates = currentHoleFeatures
            .filter { $0.kind == .green }
            .flatMap(\.coordinates)
        let teeToBack: Double? = greenCoordinates.map { coord in
            let coordinateLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            return teeLocation.distance(from: coordinateLocation)
        }.max()

        if let teeToBack {
            // 8% buffer absorbs slight off-line lies (e.g. wide
            // fairway shots whose distance to back-of-green is a hair
            // longer than the centre-line yardage).
            return Int((teeToBack * 1.08).rounded())
        }

        let pin = displayedPinTargetCoordinate
        let pinLocation = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
        let teeToPin = teeLocation.distance(from: pinLocation)
        guard teeToPin > 0 else { return nil }
        return Int((teeToPin * 1.08).rounded())
    }

    private func clampToHoleMaxReasonableDistance(_ meters: Int) -> Int {
        guard let max = displayedHoleMaxReasonableDistanceMeters else { return meters }
        return Swift.min(meters, max)
    }

    var selectedTeeDistanceMeters: Int? {
        guard let selectedTeeYards else {
            return nil
        }
        return Int((Double(selectedTeeYards) * 0.9144).rounded())
    }

    var canLogLiveShotOnDisplayedHole: Bool {
        isDisplayedHoleLive
    }

    var canPresentShotLogger: Bool {
        canLogLiveShotOnDisplayedHole
    }

    var canPresentHoleConfirmation: Bool {
        isDisplayedHoleLive
    }

    var canConfirmHoleSummary: Bool {
        guard
            let pendingHoleScore,
            let pendingHolePutts,
            let pendingHolePenaltyCount,
            let pendingHoleDropCount
        else {
            return false
        }
        return pendingHoleScore >= 1 &&
            pendingHolePutts >= 0 &&
            pendingHolePenaltyCount >= 0 &&
            pendingHoleDropCount >= 0
    }

    var canAdjustTargetOnDisplayedHole: Bool {
        isDisplayedHoleLive
    }

    var canMarkBallOnDisplayedHole: Bool {
        canLogLiveShotOnDisplayedHole && !hole.isOpeningShot
    }

    /// Distance (in meters) the wheel is currently recommending against. We
    /// prefer plays-like over raw pin distance because the player's club
    /// choice is the thing wind / temperature should actually nudge. When the
    /// hole is being inspected (not live) we still expose a target so the
    /// wheel can reason about it; the wheel is just disabled in that mode.
    var clubWheelTargetDistanceMeters: Int {
        max(0, displayedPlaysLikeDistanceMeters)
    }

    /// True when the wheel should treat the shot as a putt — either we're
    /// physically very close to the pin, or the player's pending shot context
    /// already says we're on the green. In putter mode the wheel highlights
    /// Putter and mutes everything else. Always returns `false` when the
    /// user has disabled auto-recommendation, since putter mode is itself a
    /// recommendation gesture.
    var isClubWheelInPutterMode: Bool {
        guard isClubAutoRecommendationEnabled else { return false }
        if pendingShotSurface == .green { return true }
        // Anything inside ~22 m is functionally a putt or a chip with the
        // putter for most amateurs; we use 22 to give a small buffer below
        // the shortest carry ring (25 m) so the threshold doesn't visually
        // fight with the closest ring.
        return clubWheelTargetDistanceMeters > 0 && clubWheelTargetDistanceMeters < 22
    }

    /// The club we recommend for the current shot. Picked as the bag club
    /// whose carry is closest to `clubWheelTargetDistanceMeters`, with a
    /// small bias toward going *up* a club (so we don't tell the player to
    /// come up short by a meter or two when the next club fits exactly).
    /// Returns `nil` when the user has disabled auto-recommendation so the
    /// wheel can render in "manual" mode without a REC ring.
    var recommendedClubName: String? {
        guard isClubAutoRecommendationEnabled else { return nil }
        guard isDisplayedHoleLive else { return nil }
        let target = clubWheelTargetDistanceMeters
        guard target > 0 else { return nil }

        if isClubWheelInPutterMode {
            return availableClubNames.first(where: { Self.isLikelyPutterCarryName($0) })
        }

        // Putter-like clubs never show up as the recommended full-swing club; they're
        // surfaced via putter mode above.
        let candidates = availableClubNames.filter { !Self.isLikelyPutterCarryName($0) }
        guard !candidates.isEmpty else { return nil }

        // Pick the smallest absolute gap, breaking ties by preferring the
        // club whose carry is *longer* than the target (better to be a
        // half-club long than to come up short).
        let scored = candidates.map { clubName -> (clubName: String, signedGap: Int, absGap: Int) in
            let carry = displayCarryMeters(for: clubName)
            let signedGap = carry - target
            return (clubName, signedGap, abs(signedGap))
        }

        let recommendation = scored.min { lhs, rhs in
            if lhs.absGap != rhs.absGap {
                return lhs.absGap < rhs.absGap
            }
            // Tie: prefer the longer club (positive signedGap wins).
            return lhs.signedGap > rhs.signedGap
        }
        return recommendation?.clubName
    }

    /// The full-swing club whose carry best matches `meters`, using the same
    /// rule as the recommendation (nearest carry, ties go to the longer club).
    /// `nil` inside putting range or when the bag has no full-swing clubs.
    func suggestedClubName(forMeters meters: Int) -> String? {
        guard meters >= 22 else { return nil }
        let candidates = availableClubNames.filter { !Self.isLikelyPutterCarryName($0) }
        return candidates
            .map { (name: $0, gap: displayCarryMeters(for: $0) - meters) }
            .min { lhs, rhs in
                abs(lhs.gap) != abs(rhs.gap) ? abs(lhs.gap) < abs(rhs.gap) : lhs.gap > rhs.gap
            }?
            .name
    }

    var clubWheelEntries: [ClubWheelEntry] {
        let target = clubWheelTargetDistanceMeters
        let recommended = recommendedClubName
        let putterMode = isClubWheelInPutterMode
        let autoEnabled = isClubAutoRecommendationEnabled

        return clubWheelDisplayedClubNames.map { clubName in
            let carry = displayCarryMeters(for: clubName)
            // Gap is still useful in manual mode — players who turn off
            // auto-recommend often *want* the gap chip to weigh up a club
            // change themselves — so we still compute it.
            let gap = target > 0 ? carry - target : nil
            let canonicalClub = Self.canonicalClubName(clubName)

            let source: ClubWheelEntry.CarrySource =
                Self.lookupClubValue(in: clubCarryMetersByClubName, clubName: clubName) != nil
                    ? .logged
                    : .baseline

            // In manual mode every club is `.viable` (no muting) and no
            // entry is marked recommended; the wheel becomes a straight
            // picker. The `relevance` helper handles this directly when
            // `isAutoRecommendationEnabled` is `false`.
            let relevance = Self.relevance(
                forClub: canonicalClub,
                gapToTarget: gap,
                isPutterMode: putterMode,
                isAutoRecommendationEnabled: autoEnabled
            )

            return ClubWheelEntry(
                id: clubName,
                clubName: clubName,
                displayCarryMeters: carry,
                gapToTargetMeters: gap,
                carrySource: source,
                relevance: relevance,
                isRecommended: autoEnabled
                    && recommended != nil
                    && clubName == recommended
            )
        }
    }

    var selectedClubWheelEntry: ClubWheelEntry {
        let selectedClub = Self.canonicalClubName(selectedClubName)
        if let match = clubWheelEntries.first(where: { $0.clubName == selectedClub }) {
            return match
        }
        let target = clubWheelTargetDistanceMeters
        let gap = target > 0 ? displayCarryMeters(for: selectedClub) - target : nil
        return ClubWheelEntry(
            id: selectedClub,
            clubName: selectedClub,
            displayCarryMeters: displayCarryMeters(for: selectedClub),
            gapToTargetMeters: gap,
            carrySource: Self.lookupClubValue(in: clubCarryMetersByClubName, clubName: selectedClub) != nil
                ? .logged
                : .baseline,
            relevance: Self.relevance(
                forClub: selectedClub,
                gapToTarget: gap,
                isPutterMode: isClubWheelInPutterMode,
                isAutoRecommendationEnabled: isClubAutoRecommendationEnabled
            ),
            isRecommended: isClubAutoRecommendationEnabled && recommendedClubName == selectedClub
        )
    }

    /// Relevance categorisation kept as a `static` helper so unit tests can
    /// exercise it without spinning up a full `LiveRoundState`.
    /// `isAutoRecommendationEnabled` short-circuits the whole heuristic to
    /// `.viable`, since the wheel must show every club at full strength
    /// when the user has opted out of the auto-suggestion.
    static func relevance(
        forClub clubName: String,
        gapToTarget: Int?,
        isPutterMode: Bool,
        isAutoRecommendationEnabled: Bool = true
    ) -> ClubWheelEntry.Relevance {
        guard isAutoRecommendationEnabled else { return .viable }

        let isPutterLike = Self.isLikelyPutterCarryName(clubName)

        if isPutterMode {
            return isPutterLike ? .viable : .mutedByPutterMode
        }

        // When the wheel doesn't have a target distance (e.g. distance is 0
        // because the loader hasn't reported a position yet) every club is
        // potentially viable - we don't have data to mute anything.
        guard let gap = gapToTarget else { return .viable }

        // Average gap between adjacent clubs in the amateur baseline is
        // ~9-12 m. We treat anything beyond ~14 m on either side as out of
        // the comfortable zone: above that you're either flying the pin or
        // coming up well short, and you should pick a different club.
        let outOfRangeThreshold = 14
        if gap > outOfRangeThreshold { return .tooLong }
        if gap < -outOfRangeThreshold { return .tooShort }
        return .viable
    }

    var showsAtBallAction: Bool {
        canMarkBallOnDisplayedHole
    }

    var ballMarkStatus: BallMarkStatus {
        guard showsAtBallAction else {
            return .hidden
        }
        return ballMarkState == nil ? .available : .marked
    }

    var shouldSuggestBallMark: Bool {
        guard showsAtBallAction else {
            return false
        }
        guard ballMarkState == nil else {
            return false
        }
        guard
            let baseline = ballMarkSuggestionBaselineCoordinate,
            let playerCoordinate = playerLocation?.coordinate
        else {
            return false
        }

        let baselineLocation = CLLocation(
            latitude: baseline.latitude,
            longitude: baseline.longitude
        )
        let playerLocation = CLLocation(
            latitude: playerCoordinate.latitude,
            longitude: playerCoordinate.longitude
        )
        return playerLocation.distance(from: baselineLocation) >= ballMarkSuggestionThresholdMeters
    }

    var currentShotOriginCoordinate: MapCoordinate? {
        switch currentShotOriginSource {
        case .tee:
            return .init(latitude: teeCoordinate.latitude, longitude: teeCoordinate.longitude)
        case .ballMark:
            return ballMarkState?.coordinate
        case .currentLocationFallback:
            return playerLocation?.coordinate
        case nil:
            return nil
        }
    }

    var currentShotOriginSource: ShotOriginSource? {
        if hole.isOpeningShot {
            return .tee
        }
        if ballMarkState != nil {
            return .ballMark
        }
        guard playerLocation != nil else {
            return nil
        }
        return .currentLocationFallback
    }

    var pendingShotOriginSource: ShotOriginSource? {
        currentShotOriginSource
    }

    var canConfirmPendingShot: Bool {
        let hasClub = !pendingShotClubName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasClub, pendingShotStrokeNumber > 0 else { return false }
        switch currentShotLoggerContext {
        case .tee, .shot:
            return pendingShotDirection != nil && pendingShotDistance != nil
        case .putt:
            // The user must explicitly choose holed-or-missed before we'll
            // accept the putt — no silent default. Direction/distance fall
            // out of that choice automatically in `confirmPendingShot`.
            return pendingShotPuttHoled != nil
        }
    }

    var pendingShotOriginLabel: String {
        switch pendingShotOriginSource {
        case .tee:
            return "Tee"
        case .ballMark:
            return "Ball Marked"
        case .currentLocationFallback:
            return "Current Location"
        case nil:
            return "Origin Pending"
        }
    }

    var pendingShotTargetLabel: String {
        targetLabel
    }

    var pendingShotDistanceLabel: String {
        shortDistanceLabel(forMeters: displayedPinDistanceMeters)
    }

    var planningCarryDistanceMeters: Int {
        let origin = shotOriginCoordinate
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let planning = CLLocation(
            latitude: planningTargetCoordinate.latitude,
            longitude: planningTargetCoordinate.longitude
        )
        return Int(originLocation.distance(from: planning).rounded())
    }

    /// The coordinate the aim line and carry distance should *originate*
    /// from. Defaults to the player's actual GPS location, but falls
    /// back to the tee whenever the player is meaningfully further from
    /// the pin than the tee is — i.e. they're behind the teebox or
    /// off-course altogether. Without this fallback the aim polyline
    /// would stretch from a stale / out-of-bounds GPS fix all the way
    /// to the pin, which isn't useful and looks broken on the map.
    var shotOriginCoordinate: CLLocationCoordinate2D {
        Self.resolvedShotOrigin(
            player: playerCoordinate,
            tee: teeCoordinate,
            pin: displayedPinTargetCoordinate
        )
    }

    var planningRemainingDistanceMeters: Int {
        let planning = CLLocation(
            latitude: planningTargetCoordinate.latitude,
            longitude: planningTargetCoordinate.longitude
        )
        let target = CLLocation(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude)
        return Int(planning.distance(from: target).rounded())
    }

    var atBallActionTitle: String {
        ballMarkStatus == .marked ? "Ball Marked" : "At Ball"
    }

    var holeInspectionEntries: [HoleInspectionEntry] {
        holeSessions.enumerated().map { index, session in
            // Putts: prefer the player's explicit override, otherwise derive
            // from logged shots. Only surface a value when there's something
            // meaningful to show (i.e. they've at least logged a stroke).
            let putts: Int?
            if let recorded = session.recordedPutts {
                putts = recorded
            } else if !session.shots.isEmpty {
                putts = Self.derivedPuttCount(for: session)
            } else {
                putts = nil
            }

            return .init(
                id: session.number,
                number: session.number,
                par: session.par,
                score: session.recordedScore,
                putts: putts,
                fairwayHit: Self.derivedFairwayInRegulation(for: session),
                greenInRegulation: Self.derivedGreenInRegulation(for: session),
                isConfirmed: session.isConfirmed,
                isDisplayed: index == displayedHoleIndex,
                isActive: index == activeHoleIndex,
                wasEditedAfterConfirmation: session.wasEditedAfterConfirmation
            )
        }
    }

    var temperatureSummaryText: String {
        guard let weatherSnapshot else {
            return "--"
        }
        return "\(weatherSnapshot.temperatureCelsius)°C"
    }

    var weatherConditionText: String {
        weatherSnapshot?.conditionDescription ?? "Live conditions unavailable"
    }

    var weatherAttributionText: String? {
        weatherSnapshot?.attributionText
    }

    // MARK: - Shot-relative wind / weather context
    //
    // The HUD and the Conditions sheet both need wind data described
    // *relative to the current shot* — a player on the tee cares far more
    // about "Tail • +6 m plays-like" than about "12 km/h NW". The
    // computed properties below take the absolute wind reading from the
    // weather snapshot, project it onto the shot bearing, and surface
    // glanceable head/cross components plus the plays-like delta the
    // existing `PlaysLikeCalculator` is already using under the hood.

    /// Coarse classification of the wind relative to the shot bearing.
    /// The view layer uses this to colour-code the chip and pick the
    /// right copy ("Tail", "Head", etc.); analytics consumers can read
    /// it without re-deriving the bearing math.
    enum WindRelativeCategory: String, Equatable, CaseIterable {
        case calm
        case head
        case tail
        case crossLeft
        case crossRight
        case headLeft
        case headRight
        case tailLeft
        case tailRight

        /// Plain-language label used in the HUD chip subtitle and on
        /// the Conditions hero card.
        var label: String {
            switch self {
            case .calm: return "Calm"
            case .head: return "Head"
            case .tail: return "Tail"
            case .crossLeft: return "Cross L"
            case .crossRight: return "Cross R"
            case .headLeft: return "Head L"
            case .headRight: return "Head R"
            case .tailLeft: return "Tail L"
            case .tailRight: return "Tail R"
            }
        }
    }

    /// The shot bearing the wind is being projected onto. Live shots
    /// use `playerCoordinate → planningTargetCoordinate` (so the
    /// classification updates as you drag the aim crosshair); when
    /// inspecting another hole we fall back to the displayed hole's
    /// `tee → pin` line so the chip stays meaningful.
    var shotBearingForWind: CLLocationDirection {
        if isDisplayedHoleLive {
            return Self.bearing(
                from: playerCoordinate,
                to: planningTargetCoordinate.clLocationCoordinate2D
            )
        }
        let tee = primaryFeatureCoordinate(for: .tee) ?? teeCoordinate
        return Self.bearing(from: tee, to: targetCoordinate)
    }

    /// Direction the wind is *moving* in, expressed as an angle relative
    /// to the shot bearing. 0° = blowing away from the player (pure tail
    /// wind, arrow points "up" in HUD-space), 180° = blowing into the
    /// player's face (head), 90° = blowing across the line to the
    /// player's right, 270° = across to the left. `nil` when the
    /// weather snapshot doesn't have a wind direction yet.
    var windRelativeMotionDegrees: Double? {
        guard let weather = weatherSnapshot else { return nil }
        let from = weather.windDirectionDegrees
            ?? PlaysLikeCalculator.compassToDegrees(weather.windCompassDirection)
        guard let from else { return nil }

        // `from` is "where the wind blows from" → reverse 180° to get
        // the direction the air is actually travelling. Then subtract
        // the shot bearing so 0° always means "with the shot".
        let motion = (from + 180) - shotBearingForWind
        let normalized = motion.truncatingRemainder(dividingBy: 360)
        return normalized < 0 ? normalized + 360 : normalized
    }

    /// Signed head-wind component in km/h. Positive values mean the
    /// wind is blowing into the player (head); negative values mean
    /// it's behind them (tail). Returns 0 when wind data is missing.
    var windHeadComponentKmh: Int {
        guard let weather = weatherSnapshot, let motion = windRelativeMotionDegrees else { return 0 }
        // motion of 180° is pure head, so head-component = -cos(motion).
        let radians = motion * .pi / 180
        let factor = -cos(radians)
        return Int((Double(weather.windSpeedKilometersPerHour) * factor).rounded())
    }

    /// Signed cross-wind component in km/h. Positive values blow to
    /// the player's right; negative to their left. Returns 0 when
    /// wind data is missing.
    var windCrossComponentKmh: Int {
        guard let weather = weatherSnapshot, let motion = windRelativeMotionDegrees else { return 0 }
        // motion of 90° is pure cross-right, so cross-component = sin(motion).
        let radians = motion * .pi / 180
        let factor = sin(radians)
        return Int((Double(weather.windSpeedKilometersPerHour) * factor).rounded())
    }

    /// Whether we have a non-trivial wind reading the HUD chip and
    /// Conditions sheet should reason about. False when there's no
    /// snapshot, when speed is below the 3 km/h "calm" threshold, or
    /// when we couldn't resolve a direction (compass unparseable and
    /// no degrees provided).
    var hasUsableWindReading: Bool {
        guard let weather = weatherSnapshot else { return false }
        guard weather.windSpeedKilometersPerHour >= 3 else { return false }
        return windRelativeMotionDegrees != nil
    }

    /// Coarse category derived from `windRelativeMotionDegrees` and
    /// the wind speed. Speeds below 3 km/h are reported as `.calm`
    /// regardless of direction so a stiff puff doesn't get classified
    /// as a "Cross R" meaningful enough to plan around.
    var windRelativeCategory: WindRelativeCategory {
        guard let weather = weatherSnapshot else { return .calm }
        guard weather.windSpeedKilometersPerHour >= 3 else { return .calm }
        guard let motion = windRelativeMotionDegrees else { return .calm }

        // Eight-way bands centred on the cardinals. 22.5° half-width on
        // the four "pure" bands (head/tail/cross-l/cross-r) keeps the
        // chip from flicker-classifying a near-pure tail as "Tail R"
        // when the wind direction wobbles by a degree or two.
        switch motion {
        case 0..<22.5, 337.5...360: return .tail
        case 22.5..<67.5: return .tailRight
        case 67.5..<112.5: return .crossRight
        case 112.5..<157.5: return .headRight
        case 157.5..<202.5: return .head
        case 202.5..<247.5: return .headLeft
        case 247.5..<292.5: return .crossLeft
        case 292.5..<337.5: return .tailLeft
        default: return .calm
        }
    }

    /// How many metres the live plays-like calculation is currently
    /// adding (positive) or subtracting (negative) from the raw pin
    /// distance because of the wind component. Useful as a "why is
    /// plays-like 158 m when pin is 152 m?" explainer in the
    /// Conditions sheet.
    var playsLikeWindDeltaMeters: Int {
        guard let weather = weatherSnapshot, distanceToPinMeters > 0 else { return 0 }
        let delta = PlaysLikeCalculator.windAdjustmentMeters(
            baseDistance: Double(distanceToPinMeters),
            shotBearingDegrees: shotBearingForWind,
            weather: weather
        )
        return Int(delta.rounded())
    }

    /// How many metres the live plays-like calculation is currently
    /// adding (positive — cool air, ball flies less) or subtracting
    /// (negative — warm air, ball flies more) because of temperature.
    var playsLikeTemperatureDeltaMeters: Int {
        guard let weather = weatherSnapshot, distanceToPinMeters > 0 else { return 0 }
        let delta = PlaysLikeCalculator.temperatureAdjustmentMeters(
            baseDistance: Double(distanceToPinMeters),
            temperatureCelsius: Double(weather.temperatureCelsius)
        )
        return Int(delta.rounded())
    }

    // MARK: - Top-bar phase descriptors
    //
    // The redesigned live-round top bar swaps its hero + flanking
    // satellites based on what the player is doing right now: pure tee
    // shot (long carry, club-pick mindset), approach / scoring (front /
    // back / plays-like / club rec), or putt (distance + stroke counter
    // only — no plays-like, no wind delta clutter).
    //
    // The view layer reads `topBarPhase` to switch composition without
    // re-deriving the math, and the helpers below give it the exact
    // strings / numbers it needs so the SwiftUI body stays declarative.

    enum TopBarPhase: String, Equatable, CaseIterable {
        case tee
        case approach
        case scoring
        case greenSide
    }

    /// Maps the existing `shotPhase` (which is also used by the shot
    /// logger and the hole-finish flow) onto the top-bar's coarse
    /// phase. We mirror it 1:1 today; pulling it through a dedicated
    /// type lets the view layer evolve independently if we later want
    /// "putt-from-fringe" variants etc.
    var topBarPhase: TopBarPhase {
        switch shotPhase {
        case .teeShot: return .tee
        case .approach: return .approach
        case .scoring: return .scoring
        case .greenSide: return .greenSide
        }
    }

    /// Combined wind + temperature plays-like delta in meters, signed.
    /// Positive = the pin "plays longer" than the GPS yardage suggests
    /// (head wind, cool air); negative = it plays shorter.
    var playsLikeDeltaSignedMeters: Int {
        playsLikeWindDeltaMeters + playsLikeTemperatureDeltaMeters
    }

    /// Whether the plays-like delta is meaningful enough to surface as
    /// a satellite line in the top-bar hero. Below ±2m we hide it so
    /// the hero doesn't carry "+0 plays" filler text every time the
    /// wind drops to a breeze.
    var hasMeaningfulPlaysLikeDelta: Bool {
        abs(playsLikeDeltaSignedMeters) >= 2
    }

    /// Subtitle line under the score headline. Live holes show the
    /// stroke counter ("Stk 2"), confirmed holes show the recorded
    /// score ("Score 4"), and pre-shot states fall back to the par
    /// number so the chip never collapses to a single line.
    var topBarScoreSubtitle: String {
        if !isDisplayedHoleLive,
           let recordedScore = displayedHoleSession.recordedScore {
            return "Score \(recordedScore)"
        }
        let strokeNumber = max(1, displayedHoleSession.strokeCount + 1)
        return "Stroke \(strokeNumber)"
    }

    /// One-line copy used by the Conditions sheet's wind hero card to
    /// spell out the head/cross breakdown when both components are
    /// non-trivial. Returns `nil` for calm winds so the view can hide
    /// the row entirely instead of rendering "0 km/h head · 0 km/h
    /// cross".
    var windComponentBreakdownText: String? {
        let head = windHeadComponentKmh
        let cross = windCrossComponentKmh
        if head == 0 && cross == 0 { return nil }

        var parts: [String] = []
        if head != 0 {
            parts.append("\(abs(head)) km/h \(head > 0 ? "head" : "tail")")
        }
        if cross != 0 {
            parts.append("\(abs(cross)) km/h cross \(cross > 0 ? "R" : "L")")
        }
        return parts.joined(separator: " · ")
    }

    var playerCoordinate: CLLocationCoordinate2D {
        playerLocation?.coordinate.clLocationCoordinate2D ?? courseCoordinate.clLocationCoordinate2D
    }

    var displayedHoleSession: HoleSession {
        displayedHoleSessionState
    }

    var displayedHole: SwingPalCourse.Hole? {
        courseHoles.first(where: { $0.number == displayedHoleSessionState.number })
    }

    private var displayedHoleSessionState: HoleSession {
        guard holeSessions.indices.contains(displayedHoleIndex) else {
            return hole
        }
        return displayedHoleIndex == activeHoleIndex ? hole : holeSessions[displayedHoleIndex]
    }

    private var displayedHolePuttCount: Int {
        displayedHoleSessionState.recordedPutts ?? Self.derivedPuttCount(for: displayedHoleSessionState)
    }

    private var displayedHolePenaltyCount: Int {
        displayedHoleSessionState.recordedPenaltyCount ?? Self.derivedPenaltyCount(for: displayedHoleSessionState)
    }

    private var displayedHoleScore: Int {
        displayedHoleSessionState.totalScore
    }

    /// Round-level scoring totals. Only confirmed holes contribute, so the
    /// chip stays steady mid-hole and only "ticks over" on hole confirmation -
    /// which matches how every paid caddie app surfaces the running score.
    var roundScoreToPar: Int {
        holeSessions.reduce(0) { partialResult, session in
            guard session.isConfirmed, let score = session.recordedScore else {
                return partialResult
            }
            return partialResult + (score - session.par)
        }
    }

    var roundConfirmedHoleCount: Int {
        holeSessions.reduce(0) { partial, session in
            partial + (session.isConfirmed && session.recordedScore != nil ? 1 : 0)
        }
    }

    /// Compact "+2" / "E" / "-1" representation of the running score, ready
    /// for direct use in the top panel chip.
    var roundScoreToParDisplay: String {
        let value = roundScoreToPar
        if value == 0 { return "E" }
        return value > 0 ? "+\(value)" : "\(value)"
    }

    /// Round-level "FIR / 14" style fraction (par 3s never count toward the
    /// denominator). Returned as `(hits, applicable)`; consumers decide how
    /// to render it. We only count holes that are confirmed AND have a
    /// derived FIR signal, so unlogged holes don't artificially deflate the
    /// percentage.
    var roundFairwaysInRegulation: (hit: Int, applicable: Int) {
        holeSessions.reduce((hit: 0, applicable: 0)) { totals, session in
            guard session.isConfirmed,
                  let fir = Self.derivedFairwayInRegulation(for: session)
            else { return totals }
            return (
                hit: totals.hit + (fir ? 1 : 0),
                applicable: totals.applicable + 1
            )
        }
    }

    var roundGreensInRegulation: (hit: Int, applicable: Int) {
        holeSessions.reduce((hit: 0, applicable: 0)) { totals, session in
            guard session.isConfirmed,
                  let gir = Self.derivedGreenInRegulation(for: session)
            else { return totals }
            return (
                hit: totals.hit + (gir ? 1 : 0),
                applicable: totals.applicable + 1
            )
        }
    }

    var roundTotalPutts: Int {
        holeSessions.reduce(0) { partial, session in
            guard session.isConfirmed else { return partial }
            return partial + (session.recordedPutts ?? Self.derivedPuttCount(for: session))
        }
    }

    private var roundCompanionCurrentSurface: String {
        if isShowingShotLogger {
            return pendingShotSurface.rawValue
        }
        if let surface = displayedHoleSessionState.shots.last?.surface {
            return surface.rawValue
        }
        return suggestedShotSurface.rawValue
    }

    var teeCoordinate: CLLocationCoordinate2D {
        if let teeCoordinate = primaryFeatureCoordinate(for: .tee) {
            return teeCoordinate
        }

        return offsetCoordinate(
            from: courseCoordinate.clLocationCoordinate2D,
            northMeters: -170,
            eastMeters: -20
        )
    }

    var targetCoordinate: CLLocationCoordinate2D {
        Self.pinCoordinate(
            for: courseCoordinate.clLocationCoordinate2D,
            features: currentHoleFeatures
        )
    }

    var currentHoleFeatures: [SwingPalCourse.Hole.Feature] {
        displayedHole?.features ?? []
    }

    /// Bounding box for **the entire course** (union of every hole's feature
    /// coordinates with a generous buffer). This is what the live `Map` clamps its
    /// camera centre to, so the user can pinch out to see all 18 holes at once -
    /// previously the bounds were locked to the active hole and you couldn't zoom
    /// out past it.
    var courseBounds: SwingPalCourse.Hole.Bounds {
        let allCoordinates = courseHoles.flatMap { $0.features.flatMap(\.coordinates) }
        if let bounds = SwingPalCourse.Hole.bounds(containing: allCoordinates, bufferMeters: 120) {
            return bounds
        }
        return currentHoleBounds
    }

    /// Approximate diagonal of the course in meters - used to compute the camera's
    /// maximum zoom-out distance so a user can pull back and see the whole course
    /// plus a bit of surrounding context.
    var courseDiagonalMeters: Double {
        let bounds = courseBounds
        let southWest = CLLocation(latitude: bounds.minLatitude, longitude: bounds.minLongitude)
        let northEast = CLLocation(latitude: bounds.maxLatitude, longitude: bounds.maxLongitude)
        return southWest.distance(from: northEast)
    }

    var currentHoleBounds: SwingPalCourse.Hole.Bounds {
        if let bounds = displayedHole?.bounds {
            return bounds
        }

        return SwingPalCourse.Hole.bounds(
            containing: [
                .init(latitude: teeCoordinate.latitude, longitude: teeCoordinate.longitude),
                .init(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude),
                .init(latitude: playerCoordinate.latitude, longitude: playerCoordinate.longitude)
            ],
            bufferMeters: 24
        )!
    }

    var displayedHoleViewportBounds: SwingPalCourse.Hole.HoleViewportBounds {
        if let viewportBounds = displayedHole?.viewportBounds {
            return viewportBounds
        }
        return .init(bounds: currentHoleBounds)
    }

    var displayedHoleRegion: MKCoordinateRegion {
        let bounds = currentHoleBounds
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: bounds.center.latitude,
                longitude: bounds.center.longitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: bounds.latitudeDelta,
                longitudeDelta: bounds.longitudeDelta
            )
        )
    }

    /// Raw parameters for the 3D pitched camera that looks from behind the tee box
    /// down the fairway toward the green. Exposed as a simple struct so the SwiftUI
    /// view layer can construct an actual `MapCamera` (which lives in the SwiftUI
    /// overlay for MapKit) without forcing this state class to import SwiftUI.
    ///
    /// The view should map this onto:
    /// `MapCamera(centerCoordinate: spec.center, distance: spec.distance, heading: spec.heading, pitch: spec.pitch)`
    struct TeePerspectiveCameraSpec: Equatable {
        let center: CLLocationCoordinate2D
        let distance: CLLocationDistance
        let heading: CLLocationDirection
        let pitch: Double

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.center.latitude == rhs.center.latitude
                && lhs.center.longitude == rhs.center.longitude
                && lhs.distance == rhs.distance
                && lhs.heading == rhs.heading
                && lhs.pitch == rhs.pitch
        }
    }

    /// Default presentation framing for the live round. We bias the camera anchor
    /// 45% from tee to pin so the tee sits near the bottom of the frame and the
    /// green floats in the upper third, with some approach terrain visible beyond
    /// the green for context. Pitch of 55° is high enough to read like a real 3D
    /// on-course view without putting the horizon so close that the green becomes
    /// a tiny smudge.
    var teePerspectiveCameraSpec: TeePerspectiveCameraSpec {
        Self.teePerspectiveCameraSpec(
            teeCoordinate: teeCoordinate,
            targetCoordinate: targetCoordinate
        )
    }

    static func teePerspectiveCameraSpec(
        teeCoordinate: CLLocationCoordinate2D,
        targetCoordinate: CLLocationCoordinate2D
    ) -> TeePerspectiveCameraSpec {
        let teeLocation = CLLocation(latitude: teeCoordinate.latitude, longitude: teeCoordinate.longitude)
        let pinLocation = CLLocation(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude)
        let teePinDistance = teeLocation.distance(from: pinLocation)

        let bias = 0.45
        let center = CLLocationCoordinate2D(
            latitude: teeCoordinate.latitude + (targetCoordinate.latitude - teeCoordinate.latitude) * bias,
            longitude: teeCoordinate.longitude + (targetCoordinate.longitude - teeCoordinate.longitude) * bias
        )

        // `distance` is the camera's straight-line altitude. With a 55° pitch the visible
        // ground extent is significantly wider than `distance`, so we don't need to multiply
        // by the 1.4-1.5x we'd use for a flat region. A 600-700m floor keeps short par 3s
        // from looking like the camera is buried in the tee box.
        return TeePerspectiveCameraSpec(
            center: center,
            distance: max(teePinDistance * 2.4, 650),
            heading: bearing(from: teeCoordinate, to: targetCoordinate),
            pitch: 55
        )
    }

    /// Tight, slightly-pitched camera framing centred on the current hole's
    /// green. Returned as `nil` when the displayed hole has no traced green
    /// polygon (so the launcher tile can disable itself). The camera orients
    /// the green "ahead" of the player by reusing the shot-origin → green
    /// bearing, mirroring how `teePerspectiveCameraSpec` orients the hole.
    var greenInspectionCameraSpec: TeePerspectiveCameraSpec? {
        Self.greenInspectionCameraSpec(
            features: currentHoleFeatures,
            shotOriginCoordinate: shotOriginCoordinate
        )
    }

    /// Whether the launcher's "View green" tile should be enabled. Mirrors
    /// `greenInspectionCameraSpec != nil` and additionally disables itself
    /// when the user is inspecting a non-active hole — the inspect view
    /// already gives them a hole-level frame, and we don't want to confuse
    /// the camera state machine.
    var canInspectGreen: Bool {
        greenInspectionCameraSpec != nil
    }

    static func greenInspectionCameraSpec(
        features: [SwingPalCourse.Hole.Feature],
        shotOriginCoordinate: CLLocationCoordinate2D
    ) -> TeePerspectiveCameraSpec? {
        guard let greenFeature = features.first(where: { $0.kind == .green }),
              let centroid = centroid(for: greenFeature) else {
            return nil
        }

        // Bbox diagonal is a fast, deterministic stand-in for "how big is
        // this green". Real greens range from ~18 m diameter (small,
        // tucked) up to ~45 m (large, undulating); we use the diagonal so
        // long oblong greens get a slightly wider frame than circular
        // ones of the same area.
        let coordinates = greenFeature.coordinates
        let minLat = coordinates.map(\.latitude).min() ?? centroid.latitude
        let maxLat = coordinates.map(\.latitude).max() ?? centroid.latitude
        let minLon = coordinates.map(\.longitude).min() ?? centroid.longitude
        let maxLon = coordinates.map(\.longitude).max() ?? centroid.longitude
        let southWest = CLLocation(latitude: minLat, longitude: minLon)
        let northEast = CLLocation(latitude: maxLat, longitude: maxLon)
        let greenDiagonalMeters = southWest.distance(from: northEast)

        // 4.0× diagonal keeps the green dominant (~25-30% of the frame's
        // ground extent at 50° pitch) with enough surrounding context to
        // read bunkers, run-offs, and the approach apron. The 130 m floor
        // covers degenerate test geometry; the 220 m ceiling stops huge
        // plateau greens from zooming too far out.
        let distance = min(max(greenDiagonalMeters * 4.0, 130), 220)

        return TeePerspectiveCameraSpec(
            center: centroid,
            distance: distance,
            heading: bearing(from: shotOriginCoordinate, to: centroid),
            // 50° is shallow enough to read break and depth, while still
            // giving the green a 3D presence rather than a flat top-down
            // map. The standard tee perspective uses 55°; we ease off a
            // touch for green inspection so the back of the green isn't
            // foreshortened into invisibility.
            pitch: 50
        )
    }

    /// Pans/zoom limits for the live map while the user is in “view green”
    /// mode: the camera centre must stay within the green’s bounding box
    /// (plus `bufferMeters`) so the player can’t pan off into the
    /// surrounding hole. `nil` when the displayed hole has no green feature.
    var greenInspectionPanLimits: GreenInspectionPanLimits? {
        Self.greenInspectionPanLimits(features: currentHoleFeatures, bufferMeters: 55)
    }

    static func greenInspectionPanLimits(
        features: [SwingPalCourse.Hole.Feature],
        bufferMeters: CLLocationDistance
    ) -> GreenInspectionPanLimits? {
        guard let greenFeature = features.first(where: { $0.kind == .green }),
              !greenFeature.coordinates.isEmpty
        else { return nil }

        let coordinates = greenFeature.coordinates
        let minLat = coordinates.map(\.latitude).min()!
        let maxLat = coordinates.map(\.latitude).max()!
        let minLon = coordinates.map(\.longitude).min()!
        let maxLon = coordinates.map(\.longitude).max()!
        let midLat = (minLat + maxLat) / 2
        let latPad = bufferMeters / 111_320.0
        let lonPad = bufferMeters / (111_320.0 * cos(midLat * .pi / 180.0))

        let sw = CLLocationCoordinate2D(
            latitude: minLat - latPad,
            longitude: minLon - lonPad
        )
        let ne = CLLocationCoordinate2D(
            latitude: maxLat + latPad,
            longitude: maxLon + lonPad
        )

        let swPoint = MKMapPoint(sw)
        let nePoint = MKMapPoint(ne)
        let origin = MKMapPoint(
            x: min(swPoint.x, nePoint.x),
            y: min(swPoint.y, nePoint.y)
        )
        let size = MKMapSize(
            width: max(abs(nePoint.x - swPoint.x), 1),
            height: max(abs(nePoint.y - swPoint.y), 1)
        )
        let paddedGreenRect = MKMapRect(origin: origin, size: size)

        let cornerSW = CLLocation(latitude: minLat, longitude: minLon)
        let cornerNE = CLLocation(latitude: maxLat, longitude: maxLon)
        let greenDiagonal = cornerSW.distance(from: cornerNE)

        let minimumCameraDistance: CLLocationDistance = 75
        let maximumCameraDistance: CLLocationDistance = min(
            max(greenDiagonal * 5.0, 200),
            420
        )

        return GreenInspectionPanLimits(
            paddedGreenMapRect: paddedGreenRect,
            minimumCameraDistance: minimumCameraDistance,
            maximumCameraDistance: maximumCameraDistance
        )
    }

    /// Initial bearing in degrees (0=north, clockwise) from `start` to `end`.
    /// Used to orient the perspective camera so the green is consistently "ahead"
    /// regardless of which compass direction the hole runs, and to compute the
    /// head/tail-wind component for plays-like distance adjustments.
    static func bearing(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> CLLocationDirection {
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let deltaLon = (end.longitude - start.longitude) * .pi / 180
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let radians = atan2(y, x)
        let degrees = radians * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    /// A camera region that frames the current hole's tee toward the bottom of the screen with the
    /// green visible toward the top. Used as the destination camera frame when advancing to the next
    /// hole, so the player feels the camera "follow" them to the next starting point.
    var nextHoleTeeFramingRegion: MKCoordinateRegion {
        let tee = teeCoordinate
        let pin = targetCoordinate

        let teeLocation = CLLocation(latitude: tee.latitude, longitude: tee.longitude)
        let pinLocation = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
        let distance = teeLocation.distance(from: pinLocation)

        let bias = 0.55
        let center = CLLocationCoordinate2D(
            latitude: tee.latitude + (pin.latitude - tee.latitude) * bias,
            longitude: tee.longitude + (pin.longitude - tee.longitude) * bias
        )

        let latitudinalMeters = max(distance * 1.4, 380)
        let longitudinalMeters = max(distance * 1.0, 240)

        // No longer clamped to `currentHoleBounds` - the live `Map` now uses
        // `courseBounds` for `centerCoordinateBounds`, which keeps the camera within
        // the course as a whole. Clamping tee framing to a single hole's bounds
        // squashed the framing on short holes (e.g. wanted 380m latitudinal but
        // the hole bbox was only ~200m, so we'd never see the green at full size).
        return MKCoordinateRegion(
            center: center,
            latitudinalMeters: latitudinalMeters,
            longitudinalMeters: longitudinalMeters
        )
    }

    var currentTargetZone: SwingPalCourse.Hole.TargetZone {
        let currentHole = displayedHole
        let primaryKinds: [SwingPalCourse.Hole.FeatureKind] = [.fairway, .layup, .green]

        if let targetZone = currentHole?.targetZone(
            combining: primaryKinds,
            bufferMeters: 16
        ) {
            return targetZone
        }

        return .init(bounds: currentHoleBounds)
    }

    var liveDistanceToSelectedTargetMeters: Int {
        guard locationStatus == .ready else {
            return distanceToPinMeters
        }
        let player = CLLocation(latitude: playerCoordinate.latitude, longitude: playerCoordinate.longitude)
        let target = CLLocation(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude)
        return Int(player.distance(from: target).rounded())
    }

    var recommendedMapRegion: MKCoordinateRegion {
        guard !isInspectingHole else {
            return displayedHoleRegion
        }
        return recenterViewportRegion
    }

    var recenterViewportRegion: MKCoordinateRegion {
        let player = CLLocation(latitude: playerCoordinate.latitude, longitude: playerCoordinate.longitude)
        let selectedTarget = CLLocation(
            latitude: planningTargetCoordinate.latitude,
            longitude: planningTargetCoordinate.longitude
        )
        let distance = player.distance(from: selectedTarget)

        let center = CLLocationCoordinate2D(
            latitude: (playerCoordinate.latitude + planningTargetCoordinate.latitude) / 2,
            longitude: (playerCoordinate.longitude + planningTargetCoordinate.longitude) / 2
        )

        let latitudinalMeters = max(distance * 1.45, 320)
        let longitudinalMeters = max(distance * 1.1, 220)

        let desiredRegion = MKCoordinateRegion(
            center: center,
            latitudinalMeters: latitudinalMeters,
            longitudinalMeters: longitudinalMeters
        )
        return constrainedToCurrentHoleBounds(desiredRegion)
    }

    var startupMapRegion: MKCoordinateRegion {
        guard locationStatus == .ready else {
            return courseStartupMapRegion
        }

        return recommendedMapRegion
    }

    var preferredMapRegion: MKCoordinateRegion {
        guard !isInspectingHole else {
            return displayedHoleRegion
        }
        return locationStatus == .ready ? recommendedMapRegion : startupMapRegion
    }

    var playerLocationStatusText: String {
        if let playerLocation, locationStatus == .ready {
            let accuracy = distanceUnit.scalarValue(fromMeters: playerLocation.horizontalAccuracyMeters)
            return "GPS ±\(accuracy)\(distanceUnit.shortSuffix) • heading \(Int(playerLocation.headingDegrees.rounded()))°"
        }
        switch locationStatus {
        case .locating, .requestingPermission:
            return "GPS warming up"
        case .permissionDenied:
            return "Location blocked • enable in Settings"
        case .unavailable:
            return "Location unavailable"
        case .ready:
            return "GPS warming up"
        }
    }

    private var displayedPinTargetCoordinate: CLLocationCoordinate2D {
        Self.pinCoordinate(
            for: courseCoordinate.clLocationCoordinate2D,
            features: currentHoleFeatures
        )
    }

    private var inspectionDistanceReferenceCoordinate: CLLocationCoordinate2D {
        teeCoordinate
    }

    /// Front-of-green / back-of-green distances in metres.
    ///
    /// We deliberately **anchor** on `displayedPinDistanceMeters`
    /// and only read the *physical size* of the green polygon
    /// from geometry — never the absolute distance from
    /// `playerCoordinate`. Earlier versions measured each green
    /// vertex from `playerCoordinate`, but `playerCoordinate`
    /// falls back to the course centroid when GPS is unavailable
    /// (simulator / cold start), which produced front == back ==
    /// "distance from course centre to green" while PIN happily
    /// reported the GPS-or-heuristic value. The three numbers
    /// were sourced from different reference frames and would
    /// never agree — e.g. on Medway hole 1: PIN 152m, Front
    /// 388m, Back 388m.
    ///
    /// New model:
    /// 1. Compute the tee→pin axis (`lineUnit`).
    /// 2. For each green polygon vertex, take the signed offset
    ///    *from the pin centroid* projected onto that axis.
    ///    Negative = closer to the player than the pin (front),
    ///    positive = further (back).
    /// 3. `front = pin + min(offsets)` (negative offset shrinks),
    ///    `back  = pin + max(offsets)` (positive offset grows).
    /// 4. Clamp both to ≥ 0 so a giant "way off course" pin
    ///    distance can't produce nonsensical negative front
    ///    numbers.
    ///
    /// Net effect: regardless of whether the player is at the
    /// tee, off-course in the simulator, or live-tracking via
    /// GPS, Front/Pin/Back always bracket each other tightly
    /// with the actual green's physical depth.
    private var displayedGreenDistanceExtrema: (front: Int, back: Int)? {
        let greenCoordinates = currentHoleFeatures
            .filter { $0.kind == .green }
            .flatMap(\.coordinates)

        guard !greenCoordinates.isEmpty else {
            return nil
        }

        let referenceCoordinate = isDisplayedHoleLive ? playerCoordinate : inspectionDistanceReferenceCoordinate
        let pinVector = localMeterVector(from: referenceCoordinate, to: displayedPinTargetCoordinate)
        let lineLength = max(pinVector.length, 1)
        let lineUnit = CGPoint(x: pinVector.x / lineLength, y: pinVector.y / lineLength)

        let pinCoordinate = displayedPinTargetCoordinate
        var signedOffsetsFromPin: [Double] = greenCoordinates.map { coordinate in
            let coordinateCL = CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            let pinToVertex = localMeterVector(from: pinCoordinate, to: coordinateCL)
            return Double(dot(pinToVertex, lineUnit))
        }

        guard !signedOffsetsFromPin.isEmpty else {
            return nil
        }

        // Robustness: some course assets include a handful of stray vertices
        // far from the actual green outline (e.g. traced from a multipolygon
        // relation with an extra segment). Using raw min/max would create an
        // absurd “green depth” and can drive Front down to 0 m. When the
        // projected depth is suspiciously large, trim the extremes.
        signedOffsetsFromPin.sort()
        let depth = (signedOffsetsFromPin.last ?? 0) - (signedOffsetsFromPin.first ?? 0)
        let trimmedOffsets: ArraySlice<Double>
        if depth > 80, signedOffsetsFromPin.count >= 8 {
            let trimCount = max(1, Int(Double(signedOffsetsFromPin.count) * 0.1))
            trimmedOffsets = signedOffsetsFromPin.dropFirst(trimCount).dropLast(trimCount)
        } else {
            trimmedOffsets = signedOffsetsFromPin[...]
        }

        guard let frontOffset = trimmedOffsets.min(),
              let backOffset = trimmedOffsets.max() else {
            return nil
        }

        let pinDistance = Double(displayedPinDistanceMeters)
        let front = max(0, pinDistance + frontOffset)
        let back = max(0, pinDistance + backOffset)

        // Keep ordering stable even with rounding.
        let frontMeters = Int(front.rounded())
        let backMeters = max(frontMeters, Int(back.rounded()))
        return (front: frontMeters, back: backMeters)
    }

    var shotPhase: ShotPhase {
        if distanceToPinMeters <= 30 {
            return .greenSide
        }

        if distanceToPinMeters <= 100 {
            return .scoring
        }

        if hole.strokeCount == 0 && distanceToPinMeters > 110 {
            return .teeShot
        }

        return .approach
    }

    var shotFocus: String {
        switch shotPhase {
        case .teeShot:
            return "Pick a confident starting line."
        case .approach:
            return "Commit to a full carry number."
        case .scoring:
            return "Favor control over raw distance."
        case .greenSide:
            return "Land it soft and take out pace."
        }
    }

    var targetLabel: String {
        currentHoleFeatures.contains { $0.kind == .green && !$0.coordinates.isEmpty }
            ? "Green centre"
            : "Target unavailable"
    }

    init(
        hole: HoleSession,
        courseName: String = "Royal Melbourne",
        courseCoordinate: MapCoordinate = .init(latitude: -37.9742, longitude: 145.0338),
        courseHoles: [SwingPalCourse.Hole] = [],
        holeFeatures: [SwingPalCourse.Hole.Feature] = [],
        selectedTeeName: String? = nil,
        selectedTeeYards: Int? = nil,
        players: [RoundPlayerDraft] = [.init(name: "You", kind: .selfPlayer)],
        clubCarryMetersByClubName: [String: Int] = [:],
        clubAutoRecommendationEnabled: Bool = true,
        roundCompanionSync: RoundCompanionSyncing = NoOpRoundCompanionSync(),
        weatherLoader: RoundWeatherLoading = PreviewRoundWeatherLoader(),
        locationProvider: RoundLocationProviding = PreviewRoundLocationProvider()
    ) {
        let resolvedCourseHoles = courseHoles.isEmpty ? [.init(number: hole.number, par: hole.par, features: holeFeatures)] : courseHoles
        let resolvedActiveHoleIndex = resolvedCourseHoles.firstIndex(where: { $0.number == hole.number }) ?? 0
        self.hole = hole
        self.displayedHoleIndex = resolvedActiveHoleIndex
        self.courseName = courseName
        self.courseCoordinate = courseCoordinate
        self.courseHoles = resolvedCourseHoles
        self.selectedTeeName = selectedTeeName
        self.selectedTeeYards = selectedTeeYards
        self.players = players
        self.clubCarryMetersByClubName = clubCarryMetersByClubName
        self.roundCompanionSync = roundCompanionSync
        self.weatherLoader = weatherLoader
        self.locationProvider = locationProvider
        self.activeHoleIndex = resolvedActiveHoleIndex
        self.isClubAutoRecommendationEnabled = clubAutoRecommendationEnabled
        self.pendingShotClubName = Self.canonicalClubName("Driver")
        self.pendingShotStrokeNumber = max(1, hole.strokeCount + 1)
        self.holeSessions = resolvedCourseHoles.map { courseHole in
            if courseHole.number == hole.number {
                return hole
            }
            return HoleSession(number: courseHole.number, par: courseHole.par)
        }
        self.planningTargetCoordinate = Self.initialPlanningTargetCoordinate(
            courseCoordinate: courseCoordinate.clLocationCoordinate2D,
            features: self.courseHoles.first(where: { $0.number == hole.number })?.features ?? holeFeatures,
            playerCoordinate: locationProvider.currentSnapshot?.coordinate.clLocationCoordinate2D ?? courseCoordinate.clLocationCoordinate2D
        )
        storedReviewPlayers = players.map {
            PlayerScoreState(
                name: $0.name,
                isGuest: $0.kind == .guest,
                status: .pending
            )
        }
        playerLocation = locationProvider.currentSnapshot
        locationStatus = locationProvider.currentStatus
        refreshLivePinDistanceFromCurrentLocationIfPossible()
        locationProvider.setUpdateHandler { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.playerLocation = snapshot
            }
        }
        locationProvider.setStatusHandler { [weak self] status in
            DispatchQueue.main.async {
                self?.locationStatus = status
            }
        }
        locationProvider.startUpdating()
    }

    convenience init(
        snapshot: Snapshot,
        clubCarryMetersByClubName: [String: Int] = [:],
        clubAutoRecommendationEnabled: Bool = true,
        roundCompanionSync: RoundCompanionSyncing = NoOpRoundCompanionSync(),
        weatherLoader: RoundWeatherLoading = PreviewRoundWeatherLoader(),
        locationProvider: RoundLocationProviding = PreviewRoundLocationProvider()
    ) {
        let resolvedHole = snapshot.holeSessions[snapshot.activeHoleIndex]
        self.init(
            hole: resolvedHole,
            courseName: snapshot.courseName,
            courseCoordinate: snapshot.courseCoordinate,
            courseHoles: snapshot.courseHoles,
            selectedTeeName: snapshot.selectedTeeName,
            selectedTeeYards: snapshot.selectedTeeYards,
            players: snapshot.players,
            clubCarryMetersByClubName: clubCarryMetersByClubName,
            clubAutoRecommendationEnabled: clubAutoRecommendationEnabled,
            roundCompanionSync: NoOpRoundCompanionSync(),
            weatherLoader: weatherLoader,
            locationProvider: locationProvider
        )
        isCompanionSyncSuppressed = true
        activeHoleIndex = snapshot.activeHoleIndex
        holeSessions = snapshot.holeSessions
        hole = resolvedHole
        displayedHoleIndex = snapshot.displayedHoleIndex
        selectedClubName = Self.canonicalClubName(snapshot.selectedClubName)
        distanceToPinMeters = snapshot.distanceToPinMeters
        mapRotationDegrees = snapshot.mapRotationDegrees
        mapPanOffset = snapshot.mapPanOffset.cgSize
        planningTargetCoordinate = snapshot.planningTargetCoordinate
        storedReviewPlayers = snapshot.reviewPlayers
        playerLocation = snapshot.playerLocation ?? locationProvider.currentSnapshot
        refreshLivePinDistanceFromCurrentLocationIfPossible()
        ballMarkState = snapshot.ballMarkState
        lastLoggedShotOriginCoordinate = snapshot.lastLoggedShotOriginCoordinate
        lastLoggedShotOriginSource = snapshot.lastLoggedShotOriginSource
        lastLoggedShotTargetCoordinate = snapshot.lastLoggedShotTargetCoordinate
        lastLoggedShotTargetLabel = snapshot.lastLoggedShotTargetLabel
        ballMarkSuggestionBaselineCoordinate = snapshot.ballMarkSuggestionBaselineCoordinate
        self.roundCompanionSync = roundCompanionSync
        isCompanionSyncSuppressed = false
        publishRoundCompanionSnapshot()
    }

    deinit {
        locationProvider.stopUpdating()
    }

    func attachRoundCompanionSync(_ sync: RoundCompanionSyncing) {
        roundCompanionSync = sync
        publishRoundCompanionSnapshot()
    }

    func applyCompanionAction(_ action: RoundCompanionAction, source: RoundCompanionMutationSource) {
        performRoundCompanionMutation(source: source) {
            switch action {
            case .changeClub(let name):
                selectClub(named: name)
            case .logShot(let direction, let distance, let surface):
                logShot(
                    clubName: selectedClubName,
                    distanceToTargetMeters: displayedPinDistanceMeters,
                    strokeNumber: max(1, hole.strokeCount + 1),
                    surface: Self.watchSurface(from: surface) ?? suggestedShotSurface,
                    direction: ShotEvent.DirectionResult(rawValue: direction) ?? .hit,
                    distanceResult: ShotEvent.DistanceResult(rawValue: distance) ?? .onNumber
                )
            case .addPenalty:
                hole.recordedPenaltyCount = displayedHolePenaltyCount + 1
            case .markDrop:
                hole.recordedDropCount = (hole.recordedDropCount ?? derivedHoleDropCount) + 1
            case .addPutt:
                logShot(
                    clubName: "Putter",
                    distanceToTargetMeters: displayedPinDistanceMeters,
                    strokeNumber: max(1, hole.strokeCount + 1),
                    surface: .green,
                    direction: .hit,
                    distanceResult: .onNumber,
                    shotType: .putt,
                    puttDetail: .init(
                        puttCount: displayedHolePuttCount + 1,
                        firstPuttDistanceMeters: nil
                    )
                )
            case .finishHole:
                if !isShowingHoleConfirmation {
                    presentHoleConfirmation()
                }
                _ = confirmCurrentHole()
            case .undoLastAction:
                if !hole.shots.isEmpty {
                    hole.shots.removeLast()
                } else if let recordedPenaltyCount = hole.recordedPenaltyCount, recordedPenaltyCount > 0 {
                    hole.recordedPenaltyCount = recordedPenaltyCount - 1
                } else if let recordedDropCount = hole.recordedDropCount, recordedDropCount > 0 {
                    hole.recordedDropCount = recordedDropCount - 1
                }
            case .recenterTarget:
                resetViewport()
            }
        }
    }

    func selectClub(named clubName: String) {
        let canonicalClubName = Self.canonicalClubName(clubName)
        guard Self.containsClubNamed(canonicalClubName, in: availableClubNames) else { return }
        selectedClubName = canonicalClubName
    }

    func selectClubFromWheel(named clubName: String) {
        guard isDisplayedHoleLive else { return }
        let canonicalClubName = Self.canonicalClubName(clubName)
        // Validate against the wheel's displayed set: in manual mode this
        // includes the full standard catalog so the player can pick a
        // standard club that isn't in their bag yet. The selection then
        // flows through `availableClubNames`'s "selected club fallback"
        // branch which keeps the canonical club in scope downstream.
        guard Self.containsClubNamed(canonicalClubName, in: clubWheelDisplayedClubNames) else { return }
        selectedClubName = canonicalClubName
        dismissClubWheel()
    }

    func presentClubWheel() {
        guard isDisplayedHoleLive else { return }
        launcherDetent = .collapsed
        isShowingClubWheel = true
    }

    func dismissClubWheel() {
        guard isShowingClubWheel else { return }
        isShowingClubWheel = false
    }

    /// Toggle the wheel's "smart recommendation" mode. When `false` the wheel
    /// stops muting out-of-range clubs, drops the REC badge, and disables
    /// the auto-putter switch — every club becomes a first-class citizen and
    /// the player picks whatever they want without the assist.
    func setClubAutoRecommendationEnabled(_ isEnabled: Bool) {
        guard isClubAutoRecommendationEnabled != isEnabled else { return }
        isClubAutoRecommendationEnabled = isEnabled
        onClubAutoRecommendationPreferenceChanged?(isEnabled)
        if isEnabled, let rec = recommendedClubName {
            // Match the wheel's REC chip as soon as auto mode is on (picker stays open).
            selectClub(named: rec)
        }
    }

    func toggleClubAutoRecommendation() {
        setClubAutoRecommendationEnabled(!isClubAutoRecommendationEnabled)
    }

    func presentShotLogger() {
        guard canPresentShotLogger else { return }
        pendingShotClubName = selectedClubName
        pendingShotStrokeNumber = max(1, hole.strokeCount + 1)
        pendingShotPenaltyCount = 0
        pendingShotDropCount = 0
        pendingShotSurface = suggestedShotSurface
        pendingShotDirection = nil
        pendingShotDistance = nil
        pendingShotStrike = nil
        pendingShotType = nil
        pendingShotPuttCount = nil
        pendingShotFirstPuttDistanceMeters = nil
        pendingShotPuttHoled = nil
        pendingShotPuttMissDirection = nil
        pendingShotPuttMissDistance = nil
        pendingShotPuttMissDistanceMeters = nil
        pendingShotNote = nil
        isShowingShotLoggerAddDetail = false
        isShowingClubWheel = false
        launcherDetent = .collapsed
        isShowingShotLogger = true
    }

    func dismissShotLogger() {
        isShowingShotLogger = false
    }

    func presentHoleConfirmation() {
        guard canPresentHoleConfirmation else { return }
        // Coerce putt/penalty/drop totals to 0 when no putts have been
        // logged so `canConfirmHoleSummary` (and therefore the watch's
        // `canFinishHole` companion flag + the sheet's confirm button)
        // reads `true` immediately. Players can still adjust the
        // steppers if their actual totals differ.
        // With nothing logged yet, start the count at par rather than a hole-in-one.
        pendingHoleScore = hole.totalScore > 0 ? hole.totalScore : max(hole.par, 1)
        pendingHolePutts = hole.recordedPutts ?? (derivedHolePuttCount ?? 0)
        pendingHolePenaltyCount = hole.recordedPenaltyCount ?? derivedHolePenaltyCount
        pendingHoleDropCount = hole.recordedDropCount ?? derivedHoleDropCount
        pendingHoleShotOutcomeSummary = hole.recordedShotOutcomeSummary ?? derivedHoleShotOutcomeSummary
        pendingHoleClubCorrectionSummary = hole.recordedClubCorrectionSummary ?? derivedHoleClubCorrectionSummary
        pendingHoleNotes = hole.recordedNotes
        launcherDetent = .collapsed
        isShowingHoleConfirmation = true
        notifyRoundUpdated()
    }

    func dismissHoleConfirmation() {
        guard isShowingHoleConfirmation else { return }
        isShowingHoleConfirmation = false
        notifyRoundUpdated()
    }

    func selectShotSurface(_ surface: ShotEvent.Surface) {
        pendingShotSurface = surface
    }

    func selectShotDirection(_ direction: ShotEvent.DirectionResult) {
        pendingShotDirection = direction
    }

    func selectShotDistance(_ distance: ShotEvent.DistanceResult) {
        pendingShotDistance = distance
    }

    func selectShotStrike(_ strike: ShotEvent.StrikeResult) {
        pendingShotStrike = strike
    }

    func setPendingShotStrike(_ strike: ShotEvent.StrikeResult?) {
        pendingShotStrike = strike
    }

    func overridePendingShotClubName(_ clubName: String) {
        pendingShotClubName = Self.canonicalClubName(clubName)
    }

    func setPendingShotStrokeNumber(_ strokeNumber: Int) {
        pendingShotStrokeNumber = max(1, strokeNumber)
    }

    func setPendingShotPenaltyCount(_ count: Int) {
        pendingShotPenaltyCount = max(0, count)
    }

    func setPendingShotDropCount(_ count: Int) {
        pendingShotDropCount = max(0, count)
    }

    func setPendingShotType(_ shotType: ShotEvent.ShotType?) {
        pendingShotType = shotType
        if shotType == .putt {
            if pendingShotPuttCount == nil {
                pendingShotPuttCount = 1
            }
            if pendingShotFirstPuttDistanceMeters == nil {
                pendingShotFirstPuttDistanceMeters = 0
            }
        } else {
            pendingShotPuttCount = nil
            pendingShotFirstPuttDistanceMeters = nil
        }
    }

    func setPendingShotPuttCount(_ count: Int?) {
        guard let count else {
            pendingShotPuttCount = nil
            return
        }
        pendingShotPuttCount = max(1, count)
    }

    func setPendingShotFirstPuttDistanceMeters(_ distance: Int?) {
        guard let distance else {
            pendingShotFirstPuttDistanceMeters = nil
            return
        }
        pendingShotFirstPuttDistanceMeters = max(0, distance)
    }

    func setPendingShotNote(_ note: String?) {
        pendingShotNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Toggle the putt holed/missed state. Calling with `nil` resets the
    /// choice so the confirm-gate goes back to "must pick"; calling with
    /// `true` clears any miss-distance the user may have already typed in
    /// (since "holed" implies no miss to record).
    func setPendingShotPuttHoled(_ holed: Bool?) {
        pendingShotPuttHoled = holed
        if holed == true {
            pendingShotPuttMissDirection = nil
            pendingShotPuttMissDistance = nil
            pendingShotPuttMissDistanceMeters = nil
        }
    }

    func setPendingShotPuttMissDirection(_ direction: ShotEvent.DirectionResult?) {
        pendingShotPuttMissDirection = direction
    }

    func setPendingShotPuttMissDistance(_ distance: ShotEvent.DistanceResult?) {
        pendingShotPuttMissDistance = distance
    }

    /// Convenience setter used by the circular putt-miss outcome dial: a
    /// single tap on a sector picks both axes at once. Passing `nil` for
    /// either axis clears it (i.e. tapping the same sector again
    /// deselects the putt-miss outcome).
    func setPendingShotPuttMissOutcome(
        direction: ShotEvent.DirectionResult?,
        distance: ShotEvent.DistanceResult?
    ) {
        pendingShotPuttMissDirection = direction
        pendingShotPuttMissDistance = distance
    }

    func setPendingShotPuttMissDistanceMeters(_ distance: Int?) {
        guard let distance else {
            pendingShotPuttMissDistanceMeters = nil
            return
        }
        pendingShotPuttMissDistanceMeters = max(0, distance)
    }

    /// Open or close the "Add detail" disclosure on the redesigned sheet.
    /// Driven by the view layer; kept here so the choice survives sheet
    /// resizing and detent transitions.
    func setShotLoggerAddDetailVisibility(_ isVisible: Bool) {
        isShowingShotLoggerAddDetail = isVisible
    }

    func toggleShotLoggerAddDetailVisibility() {
        isShowingShotLoggerAddDetail.toggle()
    }

    func setPendingHoleScore(_ score: Int?) {
        guard let score else {
            pendingHoleScore = nil
            notifyRoundUpdated()
            return
        }
        pendingHoleScore = max(1, score)
        notifyRoundUpdated()
    }

    func setPendingHolePutts(_ putts: Int?) {
        guard let putts else {
            pendingHolePutts = nil
            notifyRoundUpdated()
            return
        }
        pendingHolePutts = max(0, putts)
        notifyRoundUpdated()
    }

    func setPendingHolePenaltyCount(_ penaltyCount: Int?) {
        guard let penaltyCount else {
            pendingHolePenaltyCount = nil
            notifyRoundUpdated()
            return
        }
        pendingHolePenaltyCount = max(0, penaltyCount)
        notifyRoundUpdated()
    }

    func setPendingHoleDropCount(_ dropCount: Int?) {
        guard let dropCount else {
            pendingHoleDropCount = nil
            notifyRoundUpdated()
            return
        }
        pendingHoleDropCount = max(0, dropCount)
        notifyRoundUpdated()
    }

    func setPendingHoleShotOutcomeSummary(_ summary: String?) {
        pendingHoleShotOutcomeSummary = summary?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    func setPendingHoleClubCorrectionSummary(_ summary: String?) {
        pendingHoleClubCorrectionSummary = summary?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    func setPendingHoleNotes(_ notes: String?) {
        pendingHoleNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    func markBall() {
        guard canMarkBallOnDisplayedHole, let playerLocation else { return }
        ballMarkState = .init(
            coordinate: playerLocation.coordinate,
            headingDegrees: playerLocation.headingDegrees,
            recordedAt: .now
        )
    }

    func confirmPendingShot() {
        guard canConfirmPendingShot else { return }

        switch currentShotLoggerContext {
        case .tee, .shot:
            guard
                let direction = pendingShotDirection,
                let distanceResult = pendingShotDistance
            else { return }

            let puttDetail: ShotEvent.PuttDetail?
            if let pendingShotPuttCount {
                puttDetail = .init(
                    puttCount: pendingShotPuttCount,
                    firstPuttDistanceMeters: pendingShotFirstPuttDistanceMeters
                )
            } else {
                puttDetail = nil
            }

            logShot(
                clubName: pendingShotClubName,
                distanceToTargetMeters: displayedPinDistanceMeters,
                strokeNumber: pendingShotStrokeNumber,
                penaltyCount: pendingShotPenaltyCount,
                dropCount: pendingShotDropCount,
                surface: pendingShotSurface,
                direction: direction,
                distanceResult: distanceResult,
                shotType: pendingShotType,
                strikeResult: pendingShotStrike,
                puttDetail: puttDetail,
                note: pendingShotNote
            )

        case .putt:
            // Putt-context: holed/missed is a binary the user must pick. We
            // synthesise the legacy `direction` / `distanceResult` fields
            // from that choice + miss-distance so the existing analytics
            // pipeline keeps working without churn.
            guard let holed = pendingShotPuttHoled else { return }
            let missDirection = pendingShotPuttMissDirection
            let missDistance = pendingShotPuttMissDistance
            let missMeters = pendingShotPuttMissDistanceMeters

            let direction: ShotEvent.DirectionResult
            let distanceResult: ShotEvent.DistanceResult
            if holed {
                direction = .hit
                distanceResult = .onNumber
            } else {
                // The putt-miss outcome dial sets direction + categorical
                // distance together; either axis being `nil` falls back to
                // the neutral "right at the cup" value so existing
                // analytics queries keep returning a usable distribution.
                direction = missDirection ?? .hit
                distanceResult = missDistance ?? .onNumber
            }

            let runningPuttCount = max(1, displayedHolePuttCount + 1)
            let firstPuttDistance = pendingShotFirstPuttDistanceMeters
                ?? (runningPuttCount == 1 ? max(0, distanceToPinMeters) : nil)

            let puttDetail = ShotEvent.PuttDetail(
                puttCount: runningPuttCount,
                firstPuttDistanceMeters: firstPuttDistance,
                holed: holed,
                missDistanceMeters: holed ? nil : missMeters
            )

            logShot(
                clubName: pendingShotClubName,
                distanceToTargetMeters: displayedPinDistanceMeters,
                strokeNumber: pendingShotStrokeNumber,
                penaltyCount: pendingShotPenaltyCount,
                dropCount: pendingShotDropCount,
                surface: .green,
                direction: direction,
                distanceResult: distanceResult,
                shotType: .putt,
                strikeResult: pendingShotStrike,
                puttDetail: puttDetail,
                note: pendingShotNote
            )

            // Holed putt = hole is over from the player's perspective.
            // Seed the hole-level pending fields from derived helpers
            // and surface a one-tap confirmation pill at the top of
            // the map so they don't have to dig through the launcher.
            if holed {
                seedPendingHoleSummaryFromDerivedValues()
                isShowingHoleConfirmationPill = true
            }
        }

        distanceToPinMeters = max(0, distanceToPinMeters - 32)
        isShowingShotLogger = false
        shotLogConfirmationCount += 1
    }

    /// Populate the `pendingHole*` state from entered values or the per-shot
    /// stream. Used by the holed-putt auto-seed and by
    /// `confirmCurrentHoleFromDerivedValues` so both surfaces produce
    /// identical aggregate values.
    private func seedPendingHoleSummaryFromDerivedValues() {
        pendingHoleScore = max(hole.totalScore, 1)
        pendingHolePutts = hole.recordedPutts ?? derivedHolePuttCount ?? 0
        pendingHolePenaltyCount = hole.recordedPenaltyCount ?? derivedHolePenaltyCount
        pendingHoleDropCount = hole.recordedDropCount ?? derivedHoleDropCount
        pendingHoleShotOutcomeSummary = nil
        pendingHoleClubCorrectionSummary = nil
        pendingHoleNotes = hole.recordedNotes
    }

    /// One-tap path used by the post-holed-putt pill: seeds the
    /// pending hole summary from derived per-shot data and confirms
    /// immediately. Returns the same `Bool` as `confirmCurrentHole()`
    /// so callers can react to a no-op (e.g. validation failed).
    @discardableResult
    func confirmCurrentHoleFromDerivedValues() -> Bool {
        guard isDisplayedHoleLive else { return false }
        seedPendingHoleSummaryFromDerivedValues()
        isShowingHoleConfirmationPill = false
        return confirmCurrentHole()
    }

    func dismissHoleConfirmationPill() {
        isShowingHoleConfirmationPill = false
    }

    // MARK: - Undo last shot

    var canUndoLastShot: Bool {
        isDisplayedHoleLive && !hole.shots.isEmpty && lastShotUndoSnapshot != nil
    }

    /// Stages the undo confirmation popover. Returns the preview the
    /// view layer can render in the alert/sheet, or `nil` when there
    /// is nothing to undo.
    @discardableResult
    func presentUndoConfirmation() -> LoggedShotPreview? {
        guard canUndoLastShot, let lastShot = hole.shots.last else { return nil }
        let preview = LoggedShotPreview(
            clubName: lastShot.clubName,
            surface: lastShot.surface,
            strokeNumber: lastShot.strokeNumber,
            isPutt: lastShot.shotType == .putt,
            createdAt: lastShot.createdAt
        )
        pendingUndoPreview = preview
        return preview
    }

    func dismissUndoConfirmation() {
        pendingUndoPreview = nil
    }

    /// Roll back the most recent shot. Restores distance-to-pin,
    /// last-logged-shot ribbon state, and the ball-mark suggestion
    /// baseline so the live HUD looks the same as it did pre-shot.
    /// Surfaces a `lastUndoneShotPreview` so the view layer can flash
    /// an "Undid 7-iron · fairway" toast.
    @discardableResult
    func confirmUndoLastShot() -> LoggedShotPreview? {
        pendingUndoPreview = nil
        guard canUndoLastShot,
              let snapshot = lastShotUndoSnapshot,
              let removed = hole.shots.last else { return nil }
        hole.shots.removeLast()
        distanceToPinMeters = snapshot.previousDistanceToPinMeters
        lastLoggedShotOriginCoordinate = snapshot.previousLastLoggedShotOriginCoordinate
        lastLoggedShotOriginSource = snapshot.previousLastLoggedShotOriginSource
        lastLoggedShotTargetCoordinate = snapshot.previousLastLoggedShotTargetCoordinate
        lastLoggedShotTargetLabel = snapshot.previousLastLoggedShotTargetLabel
        ballMarkState = snapshot.previousBallMarkState
        ballMarkSuggestionBaselineCoordinate = snapshot.previousBallMarkSuggestionBaselineCoordinate
        storedReviewPlayers = snapshot.previousReviewPlayers

        lastShotUndoSnapshot = nil
        // Removing the holed putt obviously voids the "confirm hole?"
        // pill that was seeded on its log.
        isShowingHoleConfirmationPill = false

        let preview = LoggedShotPreview(
            clubName: removed.clubName,
            surface: removed.surface,
            strokeNumber: removed.strokeNumber,
            isPutt: removed.shotType == .putt,
            createdAt: removed.createdAt
        )
        lastUndoneShotPreview = preview
        notifyRoundUpdated()
        return preview
    }

    func acknowledgeUndoneShotPreview() {
        lastUndoneShotPreview = nil
    }

    // MARK: - Quick penalty

    var canLogQuickPenalty: Bool { isDisplayedHoleLive }

    func presentQuickPenaltyPicker() {
        guard canLogQuickPenalty else { return }
        isShowingQuickPenaltyPicker = true
    }

    func dismissQuickPenaltyPicker() {
        isShowingQuickPenaltyPicker = false
    }

    /// Logs a synthetic +1 penalty event so the score, penalty tally,
    /// and (where relevant) drop count reflect the relief without
    /// asking the player to drag through the full shot logger.
    func logQuickPenalty(_ type: QuickPenaltyType) {
        guard canLogQuickPenalty else { return }
        isShowingQuickPenaltyPicker = false
        let nextStroke = max(1, hole.strokeCount + 1)
        logShot(
            clubName: Self.syntheticPenaltyClubName,
            distanceToTargetMeters: displayedPinDistanceMeters,
            strokeNumber: nextStroke,
            penaltyCount: 1,
            dropCount: type.dropCount,
            surface: pendingShotSurface,
            direction: .hit,
            distanceResult: .onNumber,
            shotType: nil,
            strikeResult: nil,
            puttDetail: nil,
            note: type.noteText
        )
    }

    // MARK: - Re-tee

    var canRetee: Bool { isDisplayedHoleLive }

    func presentReteeConfirmation() {
        guard canRetee else { return }
        isShowingReteeConfirmation = true
    }

    func dismissReteeConfirmation() {
        isShowingReteeConfirmation = false
    }

    /// Quick OB-style recovery: logs a +1 penalty stroke and resets
    /// the pending shot scaffolding so the player's next confirm goes
    /// in as a fresh tee shot. The replay shot itself is logged by the
    /// player as normal.
    func confirmRetee() {
        guard canRetee else { return }
        isShowingReteeConfirmation = false
        let nextStroke = max(1, hole.strokeCount + 1)
        logShot(
            clubName: Self.syntheticPenaltyClubName,
            distanceToTargetMeters: displayedPinDistanceMeters,
            strokeNumber: nextStroke,
            penaltyCount: 1,
            dropCount: 0,
            surface: .tee,
            direction: .hit,
            distanceResult: .onNumber,
            shotType: nil,
            strikeResult: nil,
            puttDetail: nil,
            note: "Re-tee"
        )
        pendingShotSurface = .tee
        pendingShotDirection = nil
        pendingShotDistance = nil
        pendingShotStrike = nil
        pendingShotType = nil
        pendingShotStrokeNumber = max(1, hole.strokeCount + 1)
    }

    func logShot(
        clubName: String,
        distanceToTargetMeters: Int,
        strokeNumber: Int = 1,
        penaltyCount: Int = 0,
        dropCount: Int = 0,
        surface: ShotEvent.Surface = .fairway,
        direction: ShotEvent.DirectionResult = .hit,
        distanceResult: ShotEvent.DistanceResult = .onNumber,
        shotType: ShotEvent.ShotType? = nil,
        strikeResult: ShotEvent.StrikeResult? = nil,
        puttDetail: ShotEvent.PuttDetail? = nil,
        note: String? = nil
    ) {
        // Capture the pre-shot snapshot so a single-level undo can
        // restore distance / map / ball-mark state if the player
        // immediately realises they fat-fingered the logger.
        lastShotUndoSnapshot = ShotUndoSnapshot(
            previousDistanceToPinMeters: distanceToPinMeters,
            previousLastLoggedShotOriginCoordinate: lastLoggedShotOriginCoordinate,
            previousLastLoggedShotOriginSource: lastLoggedShotOriginSource,
            previousLastLoggedShotTargetCoordinate: lastLoggedShotTargetCoordinate,
            previousLastLoggedShotTargetLabel: lastLoggedShotTargetLabel,
            previousBallMarkState: ballMarkState,
            previousBallMarkSuggestionBaselineCoordinate: ballMarkSuggestionBaselineCoordinate,
            previousReviewPlayers: reviewPlayers
        )
        // Logging a fresh shot supersedes any pending "Undid X" toast
        // and any post-holed-putt "Confirm hole?" pill, since the
        // player is clearly still playing the hole.
        lastUndoneShotPreview = nil
        isShowingHoleConfirmationPill = false

        let originCoordinate = currentShotOriginCoordinate
        let originSource = currentShotOriginSource
        ballMarkSuggestionBaselineCoordinate = originCoordinate ?? playerLocation?.coordinate
        lastLoggedShotOriginCoordinate = originCoordinate
        lastLoggedShotOriginSource = originSource
        lastLoggedShotTargetCoordinate = .init(latitude: planningTargetCoordinate.latitude, longitude: planningTargetCoordinate.longitude)
        lastLoggedShotTargetLabel = targetLabel
        hole.shots.append(.init(
            clubName: clubName,
            distanceToTargetMeters: distanceToTargetMeters,
            strokeNumber: strokeNumber,
            penaltyCount: penaltyCount,
            dropCount: dropCount,
            surface: surface,
            direction: direction,
            distanceResult: distanceResult,
            shotType: shotType,
            strikeResult: strikeResult,
            puttDetail: puttDetail,
            note: note
        ))

        clearBallMarkIfNeededAfterLogging(used: originSource)
    }

    func inspectHole(at index: Int) {
        guard holeSessions.indices.contains(index) else { return }
        isShowingClubWheel = false
        displayedHoleIndex = index
    }

    func inspectPreviousHole() {
        inspectHole(at: max(0, displayedHoleIndex - 1))
    }

    func inspectNextHole() {
        inspectHole(at: min(holeSessions.count - 1, displayedHoleIndex + 1))
    }

    /// Snap the displayed hole back to the live/active hole. No-op when the
    /// user is already on the active hole. The recenter button uses this so
    /// pressing "scope" while peeking at another hole returns the player to
    /// the hole they're actually playing.
    func returnToActiveHole() {
        guard displayedHoleIndex != activeHoleIndex else { return }
        inspectHole(at: activeHoleIndex)
    }

    @discardableResult
    func confirmCurrentHole() -> Bool {
        guard canConfirmHoleSummary else { return false }

        let previousHole = hole
        hole.recordedScore = pendingHoleScore
        hole.recordedPutts = pendingHolePutts
        hole.recordedPenaltyCount = pendingHolePenaltyCount
        hole.recordedDropCount = pendingHoleDropCount
        hole.recordedShotOutcomeSummary = pendingHoleShotOutcomeSummary?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        hole.recordedClubCorrectionSummary = pendingHoleClubCorrectionSummary?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        hole.recordedNotes = pendingHoleNotes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        hole.isConfirmed = true
        if previousHole.isConfirmed, holeSummaryChanged(from: previousHole, to: hole) {
            hole.wasEditedAfterConfirmation = true
        } else if previousHole.wasEditedAfterConfirmation {
            hole.wasEditedAfterConfirmation = true
        } else {
            hole.wasEditedAfterConfirmation = false
        }

        isShowingHoleConfirmation = false
        isShowingHoleConfirmationPill = false
        // Confirming a hole resets the single-level undo so the player
        // can't accidentally pop a shot off a hole that's already been
        // written into round history.
        lastShotUndoSnapshot = nil
        lastUndoneShotPreview = nil
        pendingUndoPreview = nil
        _ = advanceToNextHole()
        return true
    }

    func updateInspectedHoleScore(_ score: Int) {
        guard score > 0 else { return }
        guard holeSessions.indices.contains(displayedHoleIndex) else { return }
        guard displayedHoleIndex <= activeHoleIndex else { return }

        if displayedHoleIndex == activeHoleIndex {
            let previousHole = hole
            hole.recordedScore = score
            updateHoleAuditFlagIfNeeded(previous: previousHole)
            return
        }

        let previousHole = holeSessions[displayedHoleIndex]
        holeSessions[displayedHoleIndex].recordedScore = score
        updateHoleAuditFlagIfNeeded(
            previous: previousHole,
            at: displayedHoleIndex
        )
        notifyRoundUpdated()
    }

    func updateInspectedHolePutts(_ putts: Int) {
        guard holeSessions.indices.contains(displayedHoleIndex) else { return }
        guard displayedHoleIndex <= activeHoleIndex else { return }

        if displayedHoleIndex == activeHoleIndex {
            let previousHole = hole
            hole.recordedPutts = max(0, putts)
            updateHoleAuditFlagIfNeeded(previous: previousHole)
            return
        }

        let previousHole = holeSessions[displayedHoleIndex]
        holeSessions[displayedHoleIndex].recordedPutts = max(0, putts)
        updateHoleAuditFlagIfNeeded(
            previous: previousHole,
            at: displayedHoleIndex
        )
        notifyRoundUpdated()
    }

    func updateInspectedHoleClubCorrectionSummary(_ summary: String?) {
        guard holeSessions.indices.contains(displayedHoleIndex) else { return }
        guard displayedHoleIndex <= activeHoleIndex else { return }

        let normalizedSummary = summary?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        if displayedHoleIndex == activeHoleIndex {
            let previousHole = hole
            hole.recordedClubCorrectionSummary = normalizedSummary
            updateHoleAuditFlagIfNeeded(previous: previousHole)
            return
        }

        let previousHole = holeSessions[displayedHoleIndex]
        holeSessions[displayedHoleIndex].recordedClubCorrectionSummary = normalizedSummary
        updateHoleAuditFlagIfNeeded(
            previous: previousHole,
            at: displayedHoleIndex
        )
        notifyRoundUpdated()
    }

    func makeCurrentHoleEditDraft() -> CurrentHoleEditDraft {
        // Default to derived per-shot values when the hole hasn't been
        // confirmed yet, mirroring `presentHoleConfirmation`. Without
        // this, opening "Edit current hole" mid-hole would show 0 for
        // putts/penalties/drops and silently overwrite the per-shot
        // truth on save.
        .init(
            score: max(hole.totalScore, 1),
            putts: hole.recordedPutts ?? (derivedHolePuttCount ?? 0),
            penaltyCount: hole.recordedPenaltyCount ?? derivedHolePenaltyCount,
            dropCount: hole.recordedDropCount ?? derivedHoleDropCount,
            shotOutcomeSummary: hole.recordedShotOutcomeSummary ?? "",
            clubCorrectionSummary: hole.recordedClubCorrectionSummary ?? "",
            notes: hole.recordedNotes ?? ""
        )
    }

    func applyCurrentHoleEditDraft(_ draft: CurrentHoleEditDraft) {
        let previousHole = hole
        hole.recordedScore = max(1, draft.score)
        hole.recordedPutts = max(0, draft.putts)
        hole.recordedPenaltyCount = max(0, draft.penaltyCount)
        hole.recordedDropCount = max(0, draft.dropCount)
        hole.recordedShotOutcomeSummary = draft.shotOutcomeSummary
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        hole.recordedClubCorrectionSummary = draft.clubCorrectionSummary
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        hole.recordedNotes = draft.notes
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        updateHoleAuditFlagIfNeeded(previous: previousHole)
    }

    func setMapPan(to offset: CGSize) {
        mapPanOffset = CGSize(
            width: min(max(offset.width, -panLimit), panLimit),
            height: min(max(offset.height, -panLimit), panLimit)
        )
    }

    func setMapRotation(to degrees: Double) {
        var normalized = degrees.truncatingRemainder(dividingBy: 360)
        if normalized > 180 {
            normalized -= 360
        } else if normalized < -180 {
            normalized += 360
        }
        mapRotationDegrees = normalized
    }

    func resetViewport() {
        setMapPan(to: .zero)
        setMapRotation(to: 0)
        resetPlanningTarget()
    }

    func movePlanningTarget(to coordinate: CLLocationCoordinate2D) {
        guard canAdjustTargetOnDisplayedHole else { return }
        planningTargetCoordinate = clampedPlanningCoordinate(for: coordinate)
    }

    func movePlanningTarget(to coordinate: MapCoordinate) {
        movePlanningTarget(to: coordinate.clLocationCoordinate2D)
    }

    /// Puts the aim where a shot of `carryMeters` lands on the line from the
    /// ball to the pin, or on the pin when the club reaches it. This is the
    /// default plan for whichever club is in hand; dragging the ring overrides it.
    func placePlanningTarget(atCarryMeters carryMeters: Int) {
        guard canAdjustTargetOnDisplayedHole, carryMeters > 0 else { return }
        let origin = shotOriginCoordinate
        let pin = targetCoordinate
        let length = HoleMapGeometry.distance(origin, pin)
        guard length > 1 else { return }
        let point = HoleMapGeometry.coordinate(
            from: origin,
            bearing: HoleMapGeometry.bearing(from: origin, to: pin),
            distance: min(Double(carryMeters), length)
        )
        planningTargetCoordinate = clampedPlanningCoordinate(for: point)
    }

    func refreshWeather() async {
        do {
            let snapshot = try await weatherLoader.fetchCurrentWeather()
            await MainActor.run {
                weatherSnapshot = snapshot
            }
        } catch {
            await MainActor.run {
                weatherSnapshot = nil
            }
        }
    }

    private func clearBallMarkIfNeededAfterLogging(used originSource: ShotOriginSource?) {
        if originSource == .ballMark {
            ballMarkState = nil
        }
    }

    private var derivedHolePuttCount: Int? {
        let puttShotCount = Self.derivedPuttCount(for: hole)
        return puttShotCount > 0 ? puttShotCount : nil
    }

    private var derivedHolePenaltyCount: Int {
        Self.derivedPenaltyCount(for: hole)
    }

    private var derivedHoleDropCount: Int {
        hole.shots.reduce(0) { partialResult, shot in
            partialResult + shot.dropCount
        }
    }

    private var derivedHoleShotOutcomeSummary: String? {
        let summaries = hole.shots.enumerated().map { index, shot in
            let direction = shot.direction.rawValue.replacingOccurrences(of: "(?<!^)([A-Z])", with: " $1", options: .regularExpression)
            let distance = shot.distanceResult.rawValue.replacingOccurrences(of: "(?<!^)([A-Z])", with: " $1", options: .regularExpression)
            var components = ["#\(index + 1)", shot.clubName, direction.lowercased(), distance.lowercased()]
            if let strikeResult = shot.strikeResult {
                components.append(strikeResult.rawValue)
            }
            return components.joined(separator: " ")
        }

        return summaries.isEmpty ? nil : summaries.joined(separator: "\n")
    }

    private var derivedHoleClubCorrectionSummary: String? {
        let clubsUsed = hole.shots.map { Self.canonicalClubName($0.clubName) }
        let distinctClubs = clubsUsed.reduce(into: [String]()) { partialResult, clubName in
            guard !Self.containsClubNamed(clubName, in: partialResult) else { return }
            partialResult.append(clubName)
        }
        return distinctClubs.isEmpty ? nil : distinctClubs.joined(separator: ", ")
    }

    private func holeSummaryChanged(from previous: HoleSession, to updated: HoleSession) -> Bool {
        previous.recordedScore != updated.recordedScore ||
        previous.recordedPutts != updated.recordedPutts ||
        previous.recordedPenaltyCount != updated.recordedPenaltyCount ||
        previous.recordedDropCount != updated.recordedDropCount ||
        previous.recordedShotOutcomeSummary != updated.recordedShotOutcomeSummary ||
        previous.recordedClubCorrectionSummary != updated.recordedClubCorrectionSummary ||
        previous.recordedNotes != updated.recordedNotes
    }

    private func updateHoleAuditFlagIfNeeded(previous: HoleSession) {
        if previous.isConfirmed {
            hole.wasEditedAfterConfirmation = previous.wasEditedAfterConfirmation
                || holeSummaryChanged(from: previous, to: hole)
        } else {
            hole.wasEditedAfterConfirmation = false
        }
    }

    private func updateHoleAuditFlagIfNeeded(previous: HoleSession, at index: Int) {
        guard holeSessions.indices.contains(index) else { return }
        if previous.isConfirmed {
            holeSessions[index].wasEditedAfterConfirmation = previous.wasEditedAfterConfirmation
                || holeSummaryChanged(from: previous, to: holeSessions[index])
        } else {
            holeSessions[index].wasEditedAfterConfirmation = false
        }
    }

    private func displayCarryMeters(for clubName: String) -> Int {
        if let playerCarry = Self.lookupClubValue(in: clubCarryMetersByClubName, clubName: clubName) {
            return playerCarry
        }
        if Self.isLikelyPutterCarryName(clubName) {
            return Self.amateurBaselineCarryMetersByClubName["Putter"] ?? 10
        }
        if let amateurCarry = Self.lookupClubValue(
            in: Self.amateurBaselineCarryMetersByClubName,
            clubName: clubName
        ) {
            return amateurCarry
        }
        return Self.fallbackCarryMeters
    }

    private static func canonicalClubName(_ clubName: String) -> String {
        let trimmed = clubName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "7i" }
        if let knownClub = defaultClubNames.first(where: {
            $0.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return knownClub
        }
        return trimmed
    }

    private static func containsClubNamed(_ clubName: String, in clubs: [String]) -> Bool {
        clubs.contains { candidate in
            candidate.caseInsensitiveCompare(clubName) == .orderedSame
        }
    }

    private static func lookupClubValue(in values: [String: Int], clubName: String) -> Int? {
        if let exactValue = values[clubName] {
            return exactValue
        }
        let canonicalClubName = canonicalClubName(clubName)
        if let canonicalValue = values[canonicalClubName] {
            return canonicalValue
        }
        return values.first { key, _ in
            key.caseInsensitiveCompare(clubName) == .orderedSame
        }?.value
    }

    @discardableResult
    func advanceToNextHole() -> Bool {
        guard let currentIndex = courseHoles.firstIndex(where: { $0.number == hole.number }) else {
            return false
        }
        let nextIndex = courseHoles.index(after: currentIndex)
        guard nextIndex < courseHoles.endIndex else {
            return false
        }

        activeHoleIndex = nextIndex
        displayedHoleIndex = nextIndex
        hole = holeSessions[nextIndex]
        distanceToPinMeters = 152
        selectedClubName = "7i"
        isShowingClubWheel = false
        launcherDetent = .collapsed
        ballMarkState = nil
        ballMarkSuggestionBaselineCoordinate = nil
        lastLoggedShotOriginCoordinate = nil
        lastLoggedShotOriginSource = nil
        lastLoggedShotTargetCoordinate = nil
        lastLoggedShotTargetLabel = nil
        // Hole transition voids the single-level undo so the player
        // can't reach back into the previous hole's shot stream.
        lastShotUndoSnapshot = nil
        lastUndoneShotPreview = nil
        pendingUndoPreview = nil
        isShowingHoleConfirmationPill = false
        setMapPan(to: .zero)
        setMapRotation(to: 0)
        resetPlanningTarget()
        refreshLivePinDistanceFromCurrentLocationIfPossible(fallbackMeters: 152)
        return true
    }

    private func resetPlanningTarget() {
        planningTargetCoordinate = Self.defaultPlanningTargetCoordinate(
            playerCoordinate: playerCoordinate,
            pinCoordinate: targetCoordinate,
            holeBounds: currentHoleBounds
        )
    }

    private func refreshLivePinDistanceFromCurrentLocationIfPossible(fallbackMeters: Int? = nil) {
        guard isDisplayedHoleLive else { return }
        guard let snapshot = playerLocation else {
            if let fallbackMeters {
                distanceToPinMeters = fallbackMeters
            }
            return
        }

        let player = CLLocation(
            latitude: snapshot.coordinate.latitude,
            longitude: snapshot.coordinate.longitude
        )
        let pin = CLLocation(
            latitude: targetCoordinate.latitude,
            longitude: targetCoordinate.longitude
        )
        let measuredMeters = Int(player.distance(from: pin).rounded())
        guard measuredMeters > 0 else {
            if let fallbackMeters {
                distanceToPinMeters = fallbackMeters
            }
            return
        }
        distanceToPinMeters = measuredMeters
    }

    private func syncActiveHoleSession() {
        guard holeSessions.indices.contains(activeHoleIndex) else { return }
        holeSessions[activeHoleIndex] = hole
    }

    private var suggestedShotSurface: ShotEvent.Surface {
        inferredShotSurfaceContext.surface
    }

    private enum ShotSurfaceContext {
        case mapped(surface: ShotEvent.Surface, featureLabel: String)
        case phaseFallback(surface: ShotEvent.Surface, phase: ShotPhase)

        var surface: ShotEvent.Surface {
            switch self {
            case .mapped(let surface, _), .phaseFallback(let surface, _):
                return surface
            }
        }
    }

    private var inferredShotSurfaceContext: ShotSurfaceContext {
        let coordinate = playerCoordinate
        let prioritizedKinds: [SwingPalCourse.Hole.FeatureKind] = [.tee, .bunker, .green, .fairway]

        for kind in prioritizedKinds {
            guard let feature = currentHoleFeatures.first(where: { $0.kind == kind }) else { continue }
            guard Self.featureContainsCoordinate(feature, coordinate: coordinate) else { continue }

            switch kind {
            case .tee:
                return .mapped(surface: .tee, featureLabel: feature.label)
            case .fairway:
                return .mapped(surface: .fairway, featureLabel: feature.label)
            case .green:
                return .mapped(surface: .green, featureLabel: feature.label)
            case .bunker:
                return .mapped(surface: .bunker, featureLabel: feature.label)
            case .water, .layup:
                continue
            }
        }

        switch shotPhase {
        case .teeShot:
            return .phaseFallback(surface: .tee, phase: .teeShot)
        case .greenSide:
            return .phaseFallback(surface: .green, phase: .greenSide)
        case .approach:
            return .phaseFallback(surface: .fairway, phase: .approach)
        case .scoring:
            return .phaseFallback(surface: .fairway, phase: .scoring)
        }
    }

    /// Where an aim at `coordinate` would be kept: inside the displayed hole.
    func clampedPlanningTarget(for coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        clampedPlanningCoordinate(for: coordinate).clLocationCoordinate2D
    }

    private func clampedPlanningCoordinate(for coordinate: CLLocationCoordinate2D) -> MapCoordinate {
        let rawCoordinate = SwingPalCourse.Coordinate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        let clamped = currentHoleBounds.clamped(rawCoordinate)
        return .init(latitude: clamped.latitude, longitude: clamped.longitude)
    }

    private func constrainedToCurrentHoleBounds(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
        let bounds = currentHoleBounds
        let latitudeDelta = min(region.span.latitudeDelta, bounds.latitudeDelta)
        let longitudeDelta = min(region.span.longitudeDelta, bounds.longitudeDelta)

        let clampedLatitude: Double
        let minLatitudeCenter = bounds.minLatitude + (latitudeDelta / 2)
        let maxLatitudeCenter = bounds.maxLatitude - (latitudeDelta / 2)
        if minLatitudeCenter <= maxLatitudeCenter {
            clampedLatitude = min(max(region.center.latitude, minLatitudeCenter), maxLatitudeCenter)
        } else {
            clampedLatitude = bounds.center.latitude
        }

        let clampedLongitude: Double
        let minLongitudeCenter = bounds.minLongitude + (longitudeDelta / 2)
        let maxLongitudeCenter = bounds.maxLongitude - (longitudeDelta / 2)
        if minLongitudeCenter <= maxLongitudeCenter {
            clampedLongitude = min(max(region.center.longitude, minLongitudeCenter), maxLongitudeCenter)
        } else {
            clampedLongitude = bounds.center.longitude
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: clampedLatitude, longitude: clampedLongitude),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    private func localMeterVector(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> CGPoint {
        let northMeters = (end.latitude - start.latitude) * 111_111
        let longitudeScale = max(cos(start.latitude * .pi / 180), 0.1)
        let eastMeters = (end.longitude - start.longitude) * (111_111 * longitudeScale)
        return CGPoint(x: eastMeters, y: northMeters)
    }

    private func dot(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        (lhs.x * rhs.x) + (lhs.y * rhs.y)
    }

    private func offsetCoordinate(
        from coordinate: CLLocationCoordinate2D,
        northMeters: Double,
        eastMeters: Double
    ) -> CLLocationCoordinate2D {
        let latitudeDelta = northMeters / 111_111
        let longitudeScale = max(cos(coordinate.latitude * .pi / 180), 0.1)
        let longitudeDelta = eastMeters / (111_111 * longitudeScale)
        return CLLocationCoordinate2D(
            latitude: coordinate.latitude + latitudeDelta,
            longitude: coordinate.longitude + longitudeDelta
        )
    }

    private func notifyRoundUpdated() {
        lastRoundCompanionMutationSource = activeRoundCompanionMutationSourceContext ?? .phone
        lastRoundCompanionMutationAt = .now
        publishRoundCompanionSnapshot()
        onRoundUpdated?()
    }

    private func publishRoundCompanionSnapshot() {
        guard !isCompanionSyncSuppressed else { return }
        roundCompanionSync.publish(snapshot: roundCompanionSnapshot)
    }

    private var courseStartupMapRegion: MKCoordinateRegion {
        let tee = CLLocation(latitude: teeCoordinate.latitude, longitude: teeCoordinate.longitude)
        let target = CLLocation(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude)
        let distance = tee.distance(from: target)

        let center = CLLocationCoordinate2D(
            latitude: (teeCoordinate.latitude + targetCoordinate.latitude) / 2,
            longitude: (teeCoordinate.longitude + targetCoordinate.longitude) / 2
        )

        let latitudinalMeters = max(distance * 1.5, 360)
        let longitudinalMeters = max(distance * 1.2, 260)

        return MKCoordinateRegion(
            center: center,
            latitudinalMeters: latitudinalMeters,
            longitudinalMeters: longitudinalMeters
        )
    }

    private func primaryFeatureCoordinate(for kind: SwingPalCourse.Hole.FeatureKind) -> CLLocationCoordinate2D? {
        currentHoleFeatures.first(where: { $0.kind == kind }).flatMap(Self.centroid(for:))
    }

    private func performRoundCompanionMutation(
        source: RoundCompanionMutationSource,
        _ mutation: () -> Void
    ) {
        activeRoundCompanionMutationSourceContext = source
        defer { activeRoundCompanionMutationSourceContext = nil }
        mutation()
    }

    private static func watchSurface(from rawValue: String?) -> ShotEvent.Surface? {
        guard let rawValue else { return nil }
        return ShotEvent.Surface(rawValue: rawValue)
    }

    static func derivedPuttCount(for hole: HoleSession) -> Int {
        let puttCounts = hole.shots.compactMap(\.puttDetail?.puttCount)
        if let explicitPuttCount = puttCounts.last {
            return explicitPuttCount
        }

        return hole.shots.filter { shot in
            shot.surface == .green || shot.shotType == .putt
        }.count
    }

    private static func derivedPenaltyCount(for hole: HoleSession) -> Int {
        hole.shots.reduce(0) { partialResult, shot in
            partialResult + shot.penaltyCount
        }
    }

    /// Was the tee shot's resting position in the fairway? Surface of the shot
    /// taken on stroke 2 *is* the surface the ball came to rest on after
    /// stroke 1, so we use that as the FIR signal. Returns `nil` when the
    /// hole is a par 3 (FIR doesn't apply) or when the player hasn't logged
    /// stroke 2 yet (so we can render a blank state instead of a false miss).
    static func derivedFairwayInRegulation(for hole: HoleSession) -> Bool? {
        guard hole.par >= 4 else { return nil }
        guard let secondShot = hole.shots.first(where: { $0.strokeNumber == 2 }) else {
            return nil
        }
        return secondShot.surface == .fairway
    }

    /// Did the player reach the green by `par - 2` strokes? In standard golf
    /// stat terms this is "Green in Regulation". We detect it by looking for
    /// any logged shot whose surface is `.green` and whose `strokeNumber` is
    /// at most `par - 1` - that shot is necessarily a putt or chip *from* the
    /// green, which means the previous stroke (≤ par - 2) finished on the
    /// putting surface. Returns `nil` when the player hasn't logged enough
    /// shots to make the call yet.
    static func derivedGreenInRegulation(for hole: HoleSession) -> Bool? {
        guard hole.par >= 3 else { return nil }
        let regulationStroke = max(1, hole.par - 1)
        let strokesPlayed = hole.shots.map(\.strokeNumber).max() ?? 0
        guard strokesPlayed >= regulationStroke else { return nil }
        return hole.shots.contains { shot in
            shot.surface == .green && shot.strokeNumber <= regulationStroke
        }
    }

    private static func initialPlanningTargetCoordinate(
        courseCoordinate: CLLocationCoordinate2D,
        features: [SwingPalCourse.Hole.Feature],
        playerCoordinate: CLLocationCoordinate2D
    ) -> MapCoordinate {
        let pin = pinCoordinate(for: courseCoordinate, features: features)
        let tee = teeCoordinate(for: courseCoordinate, features: features)
        // When the player's location is way off-course (simulator stuck
        // in Cupertino, stale fix, etc.) the player↔pin midpoint lands
        // somewhere absurd. Fall back to the tee in that case so the
        // crosshair lands on the hole instead of in the ocean.
        let origin = resolvedShotOrigin(
            player: playerCoordinate,
            tee: tee,
            pin: pin
        )
        return .init(
            latitude: (origin.latitude + pin.latitude) / 2,
            longitude: (origin.longitude + pin.longitude) / 2
        )
    }

    /// Picks the appropriate origin coordinate for the aim line and
    /// any derived geometry (initial planning target, carry distance,
    /// etc). Player coordinate when they're sensibly on the hole, tee
    /// coordinate when they're meaningfully behind it. Shared by the
    /// instance `shotOriginCoordinate` and the static factories so the
    /// fallback rule stays in lockstep.
    static func resolvedShotOrigin(
        player: CLLocationCoordinate2D,
        tee: CLLocationCoordinate2D,
        pin: CLLocationCoordinate2D,
        toleranceMeters: Double = 8
    ) -> CLLocationCoordinate2D {
        let teeLocation = CLLocation(latitude: tee.latitude, longitude: tee.longitude)
        let pinLocation = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
        let playerLocation = CLLocation(latitude: player.latitude, longitude: player.longitude)
        let teeToPin = teeLocation.distance(from: pinLocation)
        let playerToPin = playerLocation.distance(from: pinLocation)
        if playerToPin > teeToPin + toleranceMeters {
            return tee
        }
        return player
    }

    static func defaultPlanningTargetCoordinate(
        playerCoordinate: CLLocationCoordinate2D,
        pinCoordinate: CLLocationCoordinate2D,
        holeBounds: SwingPalCourse.Hole.Bounds
    ) -> MapCoordinate {
        let raw = SwingPalCourse.Coordinate(
            latitude: (playerCoordinate.latitude + pinCoordinate.latitude) / 2,
            longitude: (playerCoordinate.longitude + pinCoordinate.longitude) / 2
        )
        let clamped = holeBounds.clamped(raw)
        return .init(latitude: clamped.latitude, longitude: clamped.longitude)
    }

    static func pinCoordinate(
        for courseCoordinate: CLLocationCoordinate2D,
        features: [SwingPalCourse.Hole.Feature]
    ) -> CLLocationCoordinate2D {
        if let greenCoordinate = features.first(where: { $0.kind == .green }).flatMap(centroid(for:)) {
            return greenCoordinate
        }
        return offsetCoordinateStatic(from: courseCoordinate, northMeters: 186, eastMeters: 34)
    }

    /// Static counterpart to `teeCoordinate` for use from class
    /// factories that don't have access to instance state.
    static func teeCoordinate(
        for courseCoordinate: CLLocationCoordinate2D,
        features: [SwingPalCourse.Hole.Feature]
    ) -> CLLocationCoordinate2D {
        if let teeCoordinate = features.first(where: { $0.kind == .tee }).flatMap(centroid(for:)) {
            return teeCoordinate
        }
        return offsetCoordinateStatic(from: courseCoordinate, northMeters: -170, eastMeters: -20)
    }

    private static func centroid(for feature: SwingPalCourse.Hole.Feature) -> CLLocationCoordinate2D? {
        guard !feature.coordinates.isEmpty else {
            return nil
        }

        let latitude = feature.coordinates.map(\.latitude).reduce(0, +) / Double(feature.coordinates.count)
        let longitude = feature.coordinates.map(\.longitude).reduce(0, +) / Double(feature.coordinates.count)
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func featureContainsCoordinate(
        _ feature: SwingPalCourse.Hole.Feature,
        coordinate: CLLocationCoordinate2D
    ) -> Bool {
        guard feature.coordinates.count >= 3 else {
            return false
        }

        var contains = false
        var previous = feature.coordinates.last!

        for current in feature.coordinates {
            let latitudeCrosses = (current.latitude > coordinate.latitude) != (previous.latitude > coordinate.latitude)
            let denominator = previous.latitude - current.latitude
            let safeDenominator = abs(denominator) < 0.0000001 ? 0.0000001 : denominator
            let projectedLongitude = ((previous.longitude - current.longitude) * (coordinate.latitude - current.latitude) / safeDenominator) + current.longitude

            if latitudeCrosses && coordinate.longitude < projectedLongitude {
                contains.toggle()
            }

            previous = current
        }

        return contains
    }

    private static func offsetCoordinateStatic(
        from coordinate: CLLocationCoordinate2D,
        northMeters: Double,
        eastMeters: Double
    ) -> CLLocationCoordinate2D {
        let latitudeDelta = northMeters / 111_111
        let longitudeScale = max(cos(coordinate.latitude * .pi / 180), 0.1)
        let longitudeDelta = eastMeters / (111_111 * longitudeScale)
        return CLLocationCoordinate2D(
            latitude: coordinate.latitude + latitudeDelta,
            longitude: coordinate.longitude + longitudeDelta
        )
    }
}

private extension LiveRoundState.MapCoordinate {
    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

private extension CGPoint {
    var length: CGFloat {
        sqrt((x * x) + (y * y))
    }

    var normalized: CGPoint {
        let length = max(length, 0.0001)
        return CGPoint(x: x / length, y: y / length)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

/// Pure helper that turns a raw GPS distance into a "plays-like" yardage by
/// folding in head/tail wind and air-density (temperature) effects. Designed
/// to be conservative: modern launch monitors put the wind effect on a 150 m
/// shot at roughly 0.4 % of distance per km/h of head/tail component, and the
/// temperature effect at roughly 0.2 % per °C below a 20°C baseline. Elevation
/// is *not* yet modelled because we don't have hole-by-hole elevation data.
enum PlaysLikeCalculator {
    /// Reference air temperature; ball travels further in warmer, thinner air.
    static let baselineTemperatureCelsius: Double = 20

    /// Fraction of base distance added per km/h of *head* wind component.
    /// Negative values (tail wind) shorten the shot symmetrically.
    static let headWindFractionPerKmh: Double = 0.004

    /// Fraction of base distance added per °C the air is *cooler* than
    /// `baselineTemperatureCelsius` (cooler = denser = shorter ball flight).
    static let coolerAirFractionPerCelsius: Double = 0.002

    static func adjustedMeters(
        baseMeters: Int,
        shotBearingDegrees: CLLocationDirection,
        weather: RoundWeatherSnapshot?
    ) -> Int {
        guard baseMeters > 0 else { return baseMeters }
        let base = Double(baseMeters)

        var adjusted = base
        if let weather {
            adjusted += windAdjustmentMeters(
                baseDistance: base,
                shotBearingDegrees: shotBearingDegrees,
                weather: weather
            )
            adjusted += temperatureAdjustmentMeters(
                baseDistance: base,
                temperatureCelsius: Double(weather.temperatureCelsius)
            )
        }

        // Snap negative excursions back to 1m - a "plays-like" of 0 or below
        // is meaningless and would surface as "0m" on the HUD.
        return max(1, Int(adjusted.rounded()))
    }

    static func windAdjustmentMeters(
        baseDistance: Double,
        shotBearingDegrees: CLLocationDirection,
        weather: RoundWeatherSnapshot
    ) -> Double {
        let windFromDegrees = weather.windDirectionDegrees
            ?? compassToDegrees(weather.windCompassDirection)
        guard let windFromDegrees, weather.windSpeedKilometersPerHour > 0 else {
            return 0
        }

        // Head-wind component is the projection of the wind vector onto the
        // *opposite* of the shot direction. Wind direction is reported as
        // "from where it blows", so wind aligned with the shot bearing means
        // the wind is hitting the player in the face -> positive head wind.
        let delta = (windFromDegrees - shotBearingDegrees) * .pi / 180
        let headWindKmh = Double(weather.windSpeedKilometersPerHour) * cos(delta)
        return baseDistance * headWindFractionPerKmh * headWindKmh
    }

    static func temperatureAdjustmentMeters(
        baseDistance: Double,
        temperatureCelsius: Double
    ) -> Double {
        let coolerThanBaseline = baselineTemperatureCelsius - temperatureCelsius
        return baseDistance * coolerAirFractionPerCelsius * coolerThanBaseline
    }

    /// Converts a 16-point compass abbreviation (N, NNE, …, NNW) into degrees.
    /// Returns `nil` for unknown strings so callers can fall back gracefully.
    static func compassToDegrees(_ compass: String) -> Double? {
        let table: [String: Double] = [
            "N": 0, "NNE": 22.5, "NE": 45, "ENE": 67.5,
            "E": 90, "ESE": 112.5, "SE": 135, "SSE": 157.5,
            "S": 180, "SSW": 202.5, "SW": 225, "WSW": 247.5,
            "W": 270, "WNW": 292.5, "NW": 315, "NNW": 337.5
        ]
        return table[compass.uppercased()]
    }
}
