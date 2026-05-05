import Foundation

enum SocialPostOwnership: Equatable, Hashable {
    case currentUser
    case friend
}

enum SocialPostDestinationKind: Equatable, Hashable {
    case analysis
    case scorecard
}

struct SocialPost: Identifiable, Equatable, Hashable {
    let id: UUID
    let playerName: String
    let courseName: String
    let ownership: SocialPostOwnership
    let subtitle: String
    let scoreSummary: String
    let kindLabel: String
    let highlight: String
    let metadataPills: [String]
    let actionTitle: String
    let symbolName: String
    let destinationKind: SocialPostDestinationKind
    let roundSummary: RoundHistorySummary

    var title: String {
        "\(playerName) played \(courseName)"
    }

    init(
        id: UUID = UUID(),
        playerName: String,
        courseName: String,
        ownership: SocialPostOwnership,
        subtitle: String,
        scoreSummary: String,
        kindLabel: String,
        highlight: String,
        metadataPills: [String],
        actionTitle: String,
        symbolName: String,
        destinationKind: SocialPostDestinationKind,
        roundSummary: RoundHistorySummary
    ) {
        self.id = id
        self.playerName = playerName
        self.courseName = courseName
        self.ownership = ownership
        self.subtitle = subtitle
        self.scoreSummary = scoreSummary
        self.kindLabel = kindLabel
        self.highlight = highlight
        self.metadataPills = metadataPills
        self.actionTitle = actionTitle
        self.symbolName = symbolName
        self.destinationKind = destinationKind
        self.roundSummary = roundSummary
    }
}
