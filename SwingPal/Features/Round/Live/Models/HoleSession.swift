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
    var derivedScore: Int {
        let puttShots = shots.filter { $0.puttDetail != nil || $0.shotType == .putt || $0.surface == .green }
        let putts = puttShots.compactMap(\.puttDetail?.puttCount).last ?? puttShots.count
        let penalties = recordedPenaltyCount ?? shots.reduce(0) { $0 + $1.penaltyCount }
        return shots.count - puttShots.count + putts + penalties
    }

    var totalScore: Int { recordedScore ?? derivedScore }
}
