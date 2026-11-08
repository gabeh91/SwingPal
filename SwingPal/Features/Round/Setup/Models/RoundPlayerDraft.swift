import Foundation

struct RoundPlayerDraft: Identifiable, Equatable, Codable {
    enum Kind: String, Equatable, Codable {
        case selfPlayer
        case guest
    }

    let id: UUID
    let name: String
    let kind: Kind

    init(id: UUID = UUID(), name: String, kind: Kind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}
