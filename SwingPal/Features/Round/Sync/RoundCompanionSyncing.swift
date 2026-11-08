import Foundation

enum DistanceUnit: String, Equatable, Codable, CaseIterable {
    case meters
    case yards

    var shortSuffix: String {
        switch self {
        case .meters: return "m"
        case .yards: return "yd"
        }
    }

    func scalarValue(fromMeters meters: Int) -> Int {
        guard meters > 0 else { return 0 }
        switch self {
        case .meters:
            return meters
        case .yards:
            return Int((Double(meters) * 1.0936133).rounded())
        }
    }

    func shortLabel(forMeters meters: Int) -> String {
        "\(scalarValue(fromMeters: meters))\(shortSuffix)"
    }

    func travelLabel(forKilometers kilometers: Double) -> String {
        switch self {
        case .meters:
            return "\(kilometers.formatted(.number.precision(.fractionLength(1)))) km"
        case .yards:
            let miles = kilometers * 0.621371
            return "\(miles.formatted(.number.precision(.fractionLength(1)))) mi"
        }
    }
}

// MARK: - Transport seams

protocol RoundCompanionSyncing: AnyObject {
    func publish(snapshot: RoundCompanionSnapshot)
    func clear()
}

protocol RoundCompanionActionReceiving: AnyObject {
    /// Called on the main queue. The handler applies the action to the active
    /// round and returns what happened, which travels back to the Watch.
    func setIncomingActionHandler(_ handler: @escaping (RoundCompanionActionEnvelope) -> RoundCompanionActionReceipt)
}

final class NoOpRoundCompanionSync: RoundCompanionSyncing {
    func publish(snapshot: RoundCompanionSnapshot) {}

    func clear() {}
}

enum RoundCompanionMutationSource: String, Equatable, Codable {
    case phone
    case watch
}

// MARK: - Shot taxonomy
//
// Mirrors `ShotEvent` raw values so the phone can map them directly. The Watch
// target does not compile the phone's round model, so these are duplicated here
// rather than shared.

enum RoundCompanionSurface: String, Equatable, Codable, CaseIterable {
    case tee
    case fairway
    case rough
    case bunker
    case green
}

enum RoundCompanionDirection: String, Equatable, Codable, CaseIterable {
    case hit
    case left
    case farLeft
    case right
    case farRight
}

enum RoundCompanionDistance: String, Equatable, Codable, CaseIterable {
    case onNumber
    case long
    case short
}

enum RoundCompanionPenalty: String, Equatable, Codable, CaseIterable {
    case lostBall
    case outOfBounds
    case unplayable
    case water
}

enum RoundCompanionShotContext: String, Equatable, Codable {
    case tee
    case shot
    case putt
}

struct RoundCompanionShotEntry: Equatable, Codable {
    let clubName: String
    let surface: RoundCompanionSurface
    let direction: RoundCompanionDirection
    let distance: RoundCompanionDistance
    var isProvisional: Bool = false
}

struct RoundCompanionPuttEntry: Equatable, Codable {
    let holed: Bool
    var missDirection: RoundCompanionDirection? = nil
    var missDistance: RoundCompanionDistance? = nil
}

// MARK: - Actions

enum RoundCompanionAction: Equatable, Codable {
    case selectClub(name: String)
    case logShot(RoundCompanionShotEntry)
    case logPutt(RoundCompanionPuttEntry)
    case quickPenalty(RoundCompanionPenalty)
    case retee
    case markBall
    case undoLastShot
    case finishHole(score: Int, putts: Int)
    case returnToLiveHole

    /// Actions that change the live hole's record. They are refused when the
    /// round has moved on since the Watch sent them.
    var isBoundToHole: Bool {
        switch self {
        case .selectClub, .returnToLiveHole:
            return false
        case .logShot, .logPutt, .quickPenalty, .retee, .markBall, .undoLastShot, .finishHole:
            return true
        }
    }
}

/// One Watch request. The id makes delivery idempotent: a message that times
/// out and is then re-sent as queued user info is applied once.
struct RoundCompanionActionEnvelope: Equatable, Codable, Identifiable {
    var protocolVersion: Int = RoundCompanionSnapshot.currentProtocolVersion
    let id: UUID
    let action: RoundCompanionAction
    /// The live hole the Watch was showing when the golfer acted.
    let holeNumber: Int

    init(id: UUID = UUID(), action: RoundCompanionAction, holeNumber: Int) {
        self.id = id
        self.action = action
        self.holeNumber = holeNumber
    }
}

struct RoundCompanionActionReceipt: Equatable, Codable {
    enum Outcome: String, Equatable, Codable {
        case applied
        /// No round is in progress on the iPhone.
        case noActiveRound
        /// The round moved to another hole before this arrived.
        case holeChanged
        /// The iPhone has the shot logger or hole score open.
        case phoneBusy
        /// The iPhone is showing a different hole; return to the live hole first.
        case inspectingOtherHole
        /// The round state does not allow it (nothing to undo, no GPS fix, ...).
        case notAvailable
        /// The Watch and iPhone apps speak different protocol versions.
        case unsupportedVersion
    }

    let actionID: UUID
    let outcome: Outcome

    var isApplied: Bool { outcome == .applied }
}

/// Remembers recent actions so a re-delivered envelope returns its original
/// receipt instead of being applied twice.
final class RoundCompanionActionLedger {
    private let capacity: Int
    private(set) var receipts: [RoundCompanionActionReceipt] = []

    init(capacity: Int = 24) {
        self.capacity = max(1, capacity)
    }

    /// The receipts worth echoing in snapshots, newest last.
    func recentReceipts(limit: Int = 8) -> [RoundCompanionActionReceipt] {
        Array(receipts.suffix(limit))
    }

    func process(
        _ envelope: RoundCompanionActionEnvelope,
        apply: (RoundCompanionActionEnvelope) -> RoundCompanionActionReceipt
    ) -> RoundCompanionActionReceipt {
        if let existing = receipts.first(where: { $0.actionID == envelope.id }) {
            return existing
        }

        let receipt: RoundCompanionActionReceipt
        if envelope.protocolVersion != RoundCompanionSnapshot.currentProtocolVersion {
            receipt = .init(actionID: envelope.id, outcome: .unsupportedVersion)
        } else {
            receipt = apply(envelope)
        }

        receipts.append(receipt)
        if receipts.count > capacity {
            receipts.removeFirst(receipts.count - capacity)
        }
        return receipt
    }
}

// MARK: - Snapshot

struct RoundCompanionYardage: Equatable, Codable {
    let frontMeters: Int
    let centreMeters: Int
    let backMeters: Int
    /// Wind/temperature adjusted centre, only when it differs meaningfully.
    var playsLikeMeters: Int? = nil
}

enum RoundCompanionYardageStatus: String, Equatable, Codable {
    /// Live GPS distances to the green.
    case live
    /// No usable location fix yet (or permission denied).
    case noLocation
    /// The course data has no green for this hole.
    case noGreen
    /// The iPhone is showing a different hole.
    case inspectingOtherHole
}

struct RoundCompanionClub: Equatable, Codable {
    let name: String
    let carryMeters: Int
    /// `true` when the carry is the amateur baseline, not the golfer's bag.
    let isEstimated: Bool
}

struct RoundCompanionShotSummary: Equatable, Codable {
    let clubName: String
    let surface: RoundCompanionSurface
    let isPutt: Bool
    let isPenalty: Bool
}

enum RoundCompanionBallMark: String, Equatable, Codable {
    case hidden
    case available
    case marked
}

/// A hole drawn as a yardage-book page: polygons in metres, already rotated so
/// the tee is at the bottom and the green at the top (y grows toward the green).
struct RoundCompanionHoleSketch: Equatable, Codable {
    enum Kind: String, Equatable, Codable {
        case fairway
        case water
        case bunker
        case green
        case tee
    }

    struct Point: Equatable, Codable {
        let x: Int
        let y: Int
    }

    struct Feature: Equatable, Codable {
        let kind: Kind
        let points: [Point]
    }

    let features: [Feature]
    var tee: Point? = nil
    var green: Point? = nil
    var player: Point? = nil
    var aim: Point? = nil

    var bounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        let all = features.flatMap(\.points)
        guard let first = all.first else { return nil }
        return all.reduce((first.x, first.y, first.x, first.y)) { box, point in
            (min(box.0, point.x), min(box.1, point.y), max(box.2, point.x), max(box.3, point.y))
        }
    }

    /// Rounds to whole metres, drops repeated points and simplifies each ring
    /// so the whole hole fits comfortably in an application context.
    static func simplified(_ points: [(x: Double, y: Double)], tolerance: Double = 1.5, maxPoints: Int = 48) -> [Point] {
        var deduped: [(x: Double, y: Double)] = []
        for point in points {
            let rounded = (x: point.x.rounded(), y: point.y.rounded())
            if let last = deduped.last, last.x == rounded.x, last.y == rounded.y { continue }
            deduped.append(rounded)
        }
        if deduped.count > 1, let first = deduped.first, let last = deduped.last, first.x == last.x, first.y == last.y {
            deduped.removeLast()
        }
        guard deduped.count > 3 else {
            return deduped.map { Point(x: Int($0.x), y: Int($0.y)) }
        }

        var currentTolerance = tolerance
        var result = douglasPeucker(deduped, tolerance: currentTolerance)
        while result.count > maxPoints {
            currentTolerance *= 1.6
            result = douglasPeucker(deduped, tolerance: currentTolerance)
        }
        return result.map { Point(x: Int($0.x), y: Int($0.y)) }
    }

    private static func douglasPeucker(_ points: [(x: Double, y: Double)], tolerance: Double) -> [(x: Double, y: Double)] {
        guard points.count > 2 else { return points }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var stack: [(Int, Int)] = [(0, points.count - 1)]
        while let (start, end) = stack.popLast() {
            guard end > start + 1 else { continue }
            var maxDistance = 0.0
            var index = start
            for i in (start + 1)..<end {
                let distance = perpendicularDistance(points[i], points[start], points[end])
                if distance > maxDistance {
                    maxDistance = distance
                    index = i
                }
            }
            if maxDistance > tolerance {
                keep[index] = true
                stack.append((start, index))
                stack.append((index, end))
            }
        }
        return points.enumerated().compactMap { keep[$0.offset] ? $0.element : nil }
    }

    private static func perpendicularDistance(
        _ point: (x: Double, y: Double),
        _ lineStart: (x: Double, y: Double),
        _ lineEnd: (x: Double, y: Double)
    ) -> Double {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else {
            return ((point.x - lineStart.x) * (point.x - lineStart.x) + (point.y - lineStart.y) * (point.y - lineStart.y)).squareRoot()
        }
        return abs(dy * point.x - dx * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x) / length
    }
}

struct RoundCompanionSnapshot: Equatable, Codable {
    static let currentProtocolVersion = 2

    var protocolVersion: Int = RoundCompanionSnapshot.currentProtocolVersion
    let courseName: String
    let distanceUnit: DistanceUnit
    /// The live hole: the one being played, even while the iPhone inspects another.
    let holeNumber: Int
    let par: Int
    let holeCount: Int
    /// Set while the iPhone is showing a hole other than the live one.
    let inspectedHoleNumber: Int?
    /// Every hole has been written on the card; the round is saved from the iPhone.
    let isRoundComplete: Bool

    let yardage: RoundCompanionYardage?
    let yardageStatus: RoundCompanionYardageStatus

    let selectedClubName: String
    let clubs: [RoundCompanionClub]
    let recommendedClubName: String?

    let shotContext: RoundCompanionShotContext
    let suggestedSurface: RoundCompanionSurface
    /// The stroke about to be played.
    let strokeNumber: Int
    let holeScore: Int
    let puttCount: Int
    let penaltyCount: Int
    let lastShot: RoundCompanionShotSummary?
    let canUndoLastShot: Bool
    let ballMark: RoundCompanionBallMark

    /// Starting values for the Watch's hole-score form.
    let proposedHoleScore: Int
    let proposedHolePutts: Int

    let roundScoreToPar: Int
    let confirmedHoleCount: Int
    /// The shot logger or hole score is open on the iPhone.
    let isPhoneBusy: Bool

    let sketch: RoundCompanionHoleSketch?

    let lastMutationSource: RoundCompanionMutationSource
    let lastMutationAt: Date
    /// Outcomes of recent Watch actions, filled in by the transport.
    var receipts: [RoundCompanionActionReceipt] = []
}

// MARK: - Application context payload

enum RoundCompanionContextPayload {
    private enum PayloadKey {
        static let snapshot = "roundCompanionSnapshot"
        static let roundEnded = "roundCompanionEnded"
        static let action = "roundCompanionAction"
    }

    enum Content: Equatable {
        case snapshot(RoundCompanionSnapshot)
        case noRound
        /// A payload this build cannot read, typically from a newer or older app.
        case unreadable
    }

    static func context(snapshot: RoundCompanionSnapshot) throws -> [String: Any] {
        [PayloadKey.snapshot: try JSONEncoder().encode(snapshot)]
    }

    /// Application context never delivers an empty dictionary as a change, so
    /// the end of a round is an explicit marker.
    static func roundEndedContext(at date: Date = .now) -> [String: Any] {
        [PayloadKey.roundEnded: date.timeIntervalSince1970]
    }

    static func content(from context: [String: Any]) -> Content {
        if let data = context[PayloadKey.snapshot] as? Data {
            guard
                let snapshot = try? JSONDecoder().decode(RoundCompanionSnapshot.self, from: data),
                snapshot.protocolVersion == RoundCompanionSnapshot.currentProtocolVersion
            else {
                return .unreadable
            }
            return .snapshot(snapshot)
        }
        return .noRound
    }

    static func userInfo(for envelope: RoundCompanionActionEnvelope) throws -> [String: Any] {
        [PayloadKey.action: try JSONEncoder().encode(envelope)]
    }

    static func envelope(fromUserInfo userInfo: [String: Any]) -> RoundCompanionActionEnvelope? {
        guard let data = userInfo[PayloadKey.action] as? Data else { return nil }
        return try? JSONDecoder().decode(RoundCompanionActionEnvelope.self, from: data)
    }
}
