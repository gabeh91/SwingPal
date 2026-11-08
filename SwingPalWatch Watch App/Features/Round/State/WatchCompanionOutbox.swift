import Foundation

/// Actions the Watch has sent and not yet heard back about. Nothing is shown
/// as saved until the iPhone's receipt arrives, either as a message reply or
/// echoed in the next snapshot after a queued transfer.
struct WatchCompanionOutbox: Equatable {
    enum Delivery: Equatable {
        /// Sent as a live message; a reply is expected within seconds.
        case sending
        /// Handed to the system queue; it reaches the iPhone when reachable.
        case queued
    }

    struct Entry: Equatable, Identifiable {
        let envelope: RoundCompanionActionEnvelope
        var delivery: Delivery
        var id: UUID { envelope.id }
    }

    private(set) var entries: [Entry] = []

    var isEmpty: Bool { entries.isEmpty }
    var queuedCount: Int { entries.filter { $0.delivery == .queued }.count }
    var sendingCount: Int { entries.filter { $0.delivery == .sending }.count }

    mutating func add(_ envelope: RoundCompanionActionEnvelope, delivery: Delivery) {
        guard !entries.contains(where: { $0.id == envelope.id }) else { return }
        entries.append(.init(envelope: envelope, delivery: delivery))
    }

    mutating func markQueued(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].delivery = .queued
    }

    /// Removes the entry the receipt answers and returns it, or `nil` when the
    /// receipt is for something already resolved (receipts repeat in snapshots).
    mutating func resolve(_ receipt: RoundCompanionActionReceipt) -> Entry? {
        guard let index = entries.firstIndex(where: { $0.id == receipt.actionID }) else { return nil }
        return entries.remove(at: index)
    }

    mutating func resolve(receipts: [RoundCompanionActionReceipt]) -> [(Entry, RoundCompanionActionReceipt)] {
        receipts.compactMap { receipt in resolve(receipt).map { ($0, receipt) } }
    }

    /// Drops an entry that could not be handed to the system at all.
    mutating func discard(_ id: UUID) -> Entry? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        return entries.remove(at: index)
    }

    /// Queued actions for a hole the round has left will be refused by the
    /// iPhone; keep them until their receipts arrive so the golfer is told.
    func contains(_ id: UUID) -> Bool {
        entries.contains { $0.id == id }
    }
}

struct WatchActionFeedback: Equatable, Identifiable {
    enum Tone: Equatable {
        case saved
        case queued
        case refused
        case finished
    }

    let id: UUID
    let tone: Tone
    let message: String

    init(id: UUID = UUID(), tone: Tone, message: String) {
        self.id = id
        self.tone = tone
        self.message = message
    }

    static func resolved(_ action: RoundCompanionAction, receipt: RoundCompanionActionReceipt) -> WatchActionFeedback {
        guard receipt.isApplied else {
            return .init(tone: .refused, message: refusalMessage(receipt.outcome))
        }
        switch action {
        case .finishHole:
            return .init(tone: .finished, message: "On the card")
        default:
            return .init(tone: .saved, message: savedMessage(action))
        }
    }

    static func queued(_ action: RoundCompanionAction) -> WatchActionFeedback {
        .init(tone: .queued, message: "Waiting for iPhone")
    }

    static let unreachable = WatchActionFeedback(tone: .refused, message: "iPhone not available")

    static func savedMessage(_ action: RoundCompanionAction) -> String {
        switch action {
        case .selectClub(let name): return "\(WatchBookLabels.club(name)) in hand"
        case .logShot: return "Shot logged"
        case .logPutt(let entry): return entry.holed ? "Holed" : "Putt logged"
        case .quickPenalty: return "Penalty added"
        case .retee: return "Re-tee · +1"
        case .markBall: return "Ball marked"
        case .undoLastShot: return "Shot removed"
        case .finishHole: return "On the card"
        case .returnToLiveHole: return "Back on the live hole"
        }
    }

    static func refusalMessage(_ outcome: RoundCompanionActionReceipt.Outcome) -> String {
        switch outcome {
        case .applied: return ""
        case .noActiveRound: return "No round on iPhone"
        case .holeChanged: return "Hole changed · not saved"
        case .phoneBusy: return "Finish on iPhone first"
        case .inspectingOtherHole: return "iPhone is on another hole"
        case .notAvailable: return "Not available now"
        case .unsupportedVersion: return "Update SwingPal"
        }
    }
}

enum WatchCompanionLink: Equatable {
    /// iPhone reachable for live messages.
    case live
    /// Session active but the iPhone is out of reach; actions queue.
    case outOfReach
    /// WatchConnectivity unavailable or not activated.
    case unavailable
}
