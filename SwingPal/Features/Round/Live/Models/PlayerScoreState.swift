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

