import Foundation

struct HoleSession: Equatable, Codable {
    let number: Int
    let par: Int
    var recordedScore: Int? = nil
    var recordedPutts: Int? = nil
    var recordedPenaltyCount: Int? = nil
    var recordedDropCount: Int? = nil
    var recordedShotOutcomeSummary: String? = nil
    var recordedClubCorrectionSummary: String? = nil
    var recordedNotes: String? = nil
    var isConfirmed: Bool = false
    var wasEditedAfterConfirmation: Bool = false
    var shots: [ShotEvent] = []

    var isOpeningShot: Bool {
        shots.isEmpty
    }

    var strokeCount: Int {
        shots.count
    }

    /// Putt detail stores the running hole putt count, including legacy grouped
    /// putts. Use the latest count once. Drops never add another penalty stroke.
    /// Penalty-only events (quick penalty, re-tee) add their penalty, not a swing.
    var derivedScore: Int {
        let swings = shots.filter { !$0.isSyntheticPenalty }
        let puttShots = swings.filter(\.isPuttStroke)
        let putts = puttShots.compactMap(\.puttDetail?.puttCount).last ?? puttShots.count
        let penalties = recordedPenaltyCount ?? shots.reduce(0) { $0 + $1.penaltyCount }
        return swings.count - puttShots.count + putts + penalties
    }

    var totalScore: Int { recordedScore ?? derivedScore }
}

extension HoleSession {
    /// What happened around the green on a hole, read from its logged shots.
    struct ShortGameSummary: Equatable {
        /// Chips, pitches, bunker shots and putts from off the green.
        let shots: Int
        /// The first of them was played from sand.
        let fromSand: Bool
        /// One of them went in.
        let chippedIn: Bool
        /// Down in two or fewer from the first shot around the green.
        /// `nil` when the logged shots don't show how the hole was finished,
        /// so there's no telling.
        let upAndDown: Bool?
    }

    /// `nil` when no shot around the green was logged on the hole.
    var shortGameSummary: ShortGameSummary? {
        guard let firstIndex = shots.firstIndex(where: { $0.isShortGameShot }) else { return nil }
        let first: ShotEvent = shots[firstIndex]
        let before: [ShotEvent] = Array(shots[..<firstIndex])
        let fromThere: [ShotEvent] = Array(shots[firstIndex...])
        let offTheGreen: [ShotEvent] = fromThere.filter { !$0.isPuttStroke && !$0.isSyntheticPenalty }

        // Putts taken after the first shot around the green.
        let puttsOnTheHole: Int = recordedPutts ?? Self.puttTotal(in: shots)
        let puttsBefore: Int = Self.puttTotal(in: before)
        let putts: Int = max(0, puttsOnTheHole - puttsBefore)

        let penalties: Int = fromThere.reduce(0) { $0 + $1.penaltyCount }
        let chippedIn: Bool = offTheGreen.contains { $0.holedOut == true }
        let holedAPutt: Bool = fromThere.contains { $0.puttDetail?.holed == true }
        let showsTheFinish: Bool = chippedIn || holedAPutt || putts > 0

        // A score entered by hand that the logged shots don't add up to
        // means a stroke went unlogged somewhere, so don't guess.
        let nonPuttShots: Int = shots.filter { !$0.isPuttStroke && !$0.isSyntheticPenalty }.count
        let loggedPenalties: Int = recordedPenaltyCount ?? shots.reduce(0) { $0 + $1.penaltyCount }
        let scoreFromShots: Int = nonPuttShots + puttsOnTheHole + loggedPenalties
        let scoreAddsUp: Bool = recordedScore == nil || recordedScore == scoreFromShots

        let strokesToGetDown: Int = offTheGreen.count + putts + penalties
        let upAndDown: Bool? = (showsTheFinish && scoreAddsUp) ? strokesToGetDown <= 2 : nil
        return ShortGameSummary(
            shots: shots.filter { $0.isShortGameShot }.count,
            fromSand: first.surface == .bunker || first.shotType == .bunkerShot,
            chippedIn: chippedIn,
            upAndDown: upAndDown
        )
    }

    /// Putt entries carry the hole's running putt count, so the last one is
    /// the total. Entries without one count as a putt each.
    private static func puttTotal(in shots: [ShotEvent]) -> Int {
        let puttEvents: [ShotEvent] = shots.filter(\.isPuttStroke)
        let counts: [Int] = puttEvents.compactMap { $0.puttDetail?.puttCount }
        return counts.last ?? puttEvents.count
    }
}
