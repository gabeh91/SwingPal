import Foundation

struct PlayerScoreState: Identifiable, Equatable, Codable {
    enum Status: String, Equatable, Codable {
        case confirmed
        case pending
        case edited
    }

    let id: UUID
    let name: String
    let isGuest: Bool
    var strokes: Int?
    var status: Status

    init(
        id: UUID = UUID(),
        name: String,
        isGuest: Bool,
        strokes: Int? = nil,
        status: Status
    ) {
        self.id = id
        self.name = name
        self.isGuest = isGuest
        self.strokes = strokes
        self.status = status
    }
}

struct RoundReviewSummary: Equatable {
    let playerCount: Int
    let loggedCount: Int
    let pendingCount: Int
    let confirmedCount: Int

    var isReadyToClose: Bool {
        playerCount > 0 && pendingCount == 0
    }

    init(players: [PlayerScoreState]) {
        playerCount = players.count
        loggedCount = players.filter { $0.strokes != nil }.count
        pendingCount = players.filter { $0.status == .pending }.count
        confirmedCount = players.filter { $0.status == .confirmed }.count
    }
}
