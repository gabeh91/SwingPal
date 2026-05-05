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
}
