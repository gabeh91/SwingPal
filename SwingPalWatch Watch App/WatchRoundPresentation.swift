import Foundation

// Pure presentation and delivery logic for the Watch companion. Kept free of
// SwiftUI and WatchConnectivity so it compiles into the unit-test target too.

// MARK: - Outbox

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

// MARK: - Feedback

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

// MARK: - Link state

enum WatchCompanionLink: Equatable {
    /// iPhone reachable for live messages.
    case live
    /// Session active but the iPhone is out of reach; actions queue.
    case outOfReach
    /// WatchConnectivity unavailable or not activated.
    case unavailable
}

// MARK: - Screen model

/// Everything the Watch screens show, derived from the latest snapshot.
struct WatchRoundPresentation: Equatable {
    enum Phase: Equatable {
        /// No round has been shared yet, or the round ended.
        case noRound
        /// The snapshot could not be read; the apps are out of step.
        case incompatible
        case live
        /// Every hole is on the card; saving happens on the iPhone.
        case roundComplete
    }

    let phase: Phase
    let snapshot: RoundCompanionSnapshot?
    let link: WatchCompanionLink
    let outboxQueued: Int
    let outboxSending: Int
    /// Seconds since the snapshot arrived, used to call out stale yardage.
    let snapshotAge: TimeInterval?

    init(
        snapshot: RoundCompanionSnapshot?,
        isUnreadable: Bool = false,
        link: WatchCompanionLink,
        outbox: WatchCompanionOutbox = .init(),
        snapshotAge: TimeInterval? = nil
    ) {
        self.snapshot = snapshot
        self.link = link
        self.outboxQueued = outbox.queuedCount
        self.outboxSending = outbox.sendingCount
        self.snapshotAge = snapshotAge
        if isUnreadable {
            phase = .incompatible
        } else if let snapshot {
            phase = snapshot.isRoundComplete ? .roundComplete : .live
        } else {
            phase = .noRound
        }
    }

    static let staleAfterSeconds: TimeInterval = 90

    private var unit: DistanceUnit { snapshot?.distanceUnit ?? .meters }

    // MARK: Header

    var folioText: String {
        guard let snapshot else { return "––" }
        return String(format: "%02d", snapshot.holeNumber)
    }

    var parText: String {
        guard let snapshot else { return "" }
        return "Par \(snapshot.par)"
    }

    var courseText: String { snapshot?.courseName ?? "" }

    var roundToParText: String {
        guard let snapshot, snapshot.confirmedHoleCount > 0 else { return "E" }
        return WatchBookLabels.toPar(snapshot.roundScoreToPar)
    }

    /// One quiet line under the header. Empty while everything is healthy.
    var statusLine: String? {
        if outboxQueued > 0 {
            return outboxQueued == 1 ? "1 action waiting for iPhone" : "\(outboxQueued) actions waiting for iPhone"
        }
        switch link {
        case .live:
            if let snapshot, let inspected = snapshot.inspectedHoleNumber {
                return "iPhone is showing hole \(inspected)"
            }
            return nil
        case .outOfReach:
            return isStale ? "iPhone out of reach · yardage may be old" : "iPhone out of reach"
        case .unavailable:
            return "iPhone not connected"
        }
    }

    var isStale: Bool {
        guard let snapshotAge else { return false }
        return link != .live && snapshotAge > Self.staleAfterSeconds
    }

    // MARK: Yardage

    var hasYardage: Bool { snapshot?.yardage != nil }

    var centreText: String {
        guard let yardage = snapshot?.yardage else { return "—" }
        return "\(unit.scalarValue(fromMeters: yardage.centreMeters))"
    }

    var frontText: String {
        guard let yardage = snapshot?.yardage else { return "—" }
        return "\(unit.scalarValue(fromMeters: yardage.frontMeters))"
    }

    var backText: String {
        guard let yardage = snapshot?.yardage else { return "—" }
        return "\(unit.scalarValue(fromMeters: yardage.backMeters))"
    }

    var unitSuffix: String { unit.shortSuffix }

    var playsLikeText: String? {
        guard let playsLike = snapshot?.yardage?.playsLikeMeters else { return nil }
        return "Plays \(unit.scalarValue(fromMeters: playsLike))"
    }

    /// Why there is no yardage, written as the phone writes it.
    var yardageNote: String {
        guard let snapshot else { return "" }
        switch snapshot.yardageStatus {
        case .live: return "Green centre"
        case .noLocation: return "Waiting for GPS"
        case .noGreen: return "No green mapped"
        case .inspectingOtherHole: return "iPhone on hole \(snapshot.inspectedHoleNumber ?? snapshot.holeNumber)"
        }
    }

    var yardageAccessibilityLabel: String {
        guard let yardage = snapshot?.yardage else { return yardageNote }
        let suffix = unit == .yards ? "yards" : "metres"
        var label = "Green centre \(unit.scalarValue(fromMeters: yardage.centreMeters)) \(suffix). Front \(unit.scalarValue(fromMeters: yardage.frontMeters)), back \(unit.scalarValue(fromMeters: yardage.backMeters))."
        if let playsLike = yardage.playsLikeMeters {
            label += " Plays like \(unit.scalarValue(fromMeters: playsLike))."
        }
        return label
    }

    // MARK: Equipment

    var clubCode: String { WatchBookLabels.club(snapshot?.selectedClubName ?? "—") }

    var selectedClub: RoundCompanionClub? {
        guard let snapshot else { return nil }
        return snapshot.clubs.first { $0.name.caseInsensitiveCompare(snapshot.selectedClubName) == .orderedSame }
    }

    var carryText: String? {
        guard let club = selectedClub else { return nil }
        return "\(unit.scalarValue(fromMeters: club.carryMeters)) \(unit.shortSuffix)"
    }

    var carrySourceText: String? {
        guard let club = selectedClub else { return nil }
        return club.isEstimated ? "Estimated" : "From your bag"
    }

    /// Clubs longest to shortest, as the phone's club sequence reads.
    var clubsByCarry: [RoundCompanionClub] {
        (snapshot?.clubs ?? []).sorted { lhs, rhs in
            lhs.carryMeters != rhs.carryMeters ? lhs.carryMeters > rhs.carryMeters : lhs.name < rhs.name
        }
    }

    func carryLabel(for club: RoundCompanionClub) -> String {
        "\(unit.scalarValue(fromMeters: club.carryMeters)) \(unit.shortSuffix)"
    }

    // MARK: Hole state

    var strokeText: String {
        guard let snapshot else { return "" }
        return "Stroke \(snapshot.strokeNumber)"
    }

    var holeTallyText: String {
        guard let snapshot else { return "" }
        var parts = ["\(snapshot.holeScore) so far"]
        if snapshot.puttCount > 0 { parts.append(snapshot.puttCount == 1 ? "1 putt" : "\(snapshot.puttCount) putts") }
        if snapshot.penaltyCount > 0 { parts.append(snapshot.penaltyCount == 1 ? "1 penalty" : "\(snapshot.penaltyCount) penalties") }
        return parts.joined(separator: " · ")
    }

    var isInspectingOnPhone: Bool { snapshot?.inspectedHoleNumber != nil }

    /// Shot entry needs the live hole on screen and the phone's forms closed.
    var canRecordShots: Bool {
        guard phase == .live, let snapshot else { return false }
        return snapshot.inspectedHoleNumber == nil && !snapshot.isPhoneBusy && link != .unavailable
    }

    var recordBlockedReason: String? {
        guard phase == .live, let snapshot else { return nil }
        if link == .unavailable { return "iPhone not connected" }
        if snapshot.inspectedHoleNumber != nil { return "iPhone is showing another hole" }
        if snapshot.isPhoneBusy { return "Finish on iPhone first" }
        return nil
    }

    var logShotTitle: String {
        switch snapshot?.shotContext {
        case .tee: return "Log tee shot"
        case .putt: return "Log putt"
        case .shot, .none: return "Log shot"
        }
    }

    var undoTitle: String {
        guard let shot = snapshot?.lastShot else { return "Undo last shot" }
        if shot.isPenalty { return "Undo penalty" }
        return "Undo \(WatchBookLabels.club(shot.clubName))"
    }

    var undoDetail: String? {
        guard let shot = snapshot?.lastShot, !shot.isPenalty else { return nil }
        return shot.isPutt ? "Putt" : "From the \(WatchBookLabels.surface(shot.surface).lowercased())"
    }

    var ballMarkTitle: String {
        snapshot?.ballMark == .marked ? "Ball marked" : "At ball"
    }
}

// MARK: - Labels

enum WatchBookLabels {
    /// The phone's club codes: Dr, 7i, PW, Pt.
    static func club(_ name: String) -> String {
        switch name.lowercased() {
        case "driver": return "Dr"
        case "putter": return "Pt"
        case "pitching wedge": return "PW"
        case "gap wedge", "approach wedge": return "GW"
        case "sand wedge": return "SW"
        case "lob wedge": return "LW"
        default:
            return name.replacingOccurrences(of: "-iron", with: "i", options: .caseInsensitive)
                .replacingOccurrences(of: " Iron", with: "i", options: .caseInsensitive)
                .replacingOccurrences(of: "-wood", with: "w", options: .caseInsensitive)
                .replacingOccurrences(of: "-hybrid", with: "h", options: .caseInsensitive)
        }
    }

    static func surface(_ surface: RoundCompanionSurface) -> String {
        switch surface {
        case .tee: return "Tee"
        case .fairway: return "Fairway"
        case .rough: return "Rough"
        case .bunker: return "Bunker"
        case .green: return "Green"
        }
    }

    static func surfaceSymbol(_ surface: RoundCompanionSurface) -> String {
        switch surface {
        case .tee: return "flag.fill"
        case .fairway: return "leaf.fill"
        case .rough: return "leaf"
        case .bunker: return "circle.dotted"
        case .green: return "circle.circle.fill"
        }
    }

    static func penalty(_ penalty: RoundCompanionPenalty) -> (title: String, detail: String, symbol: String) {
        switch penalty {
        case .lostBall: return ("Lost ball", "Stroke and distance", "questionmark.circle.fill")
        case .outOfBounds: return ("Out of bounds", "Stroke and distance", "rectangle.dashed")
        case .unplayable: return ("Unplayable lie", "+1 · drop", "leaf.fill")
        case .water: return ("Water hazard", "+1 · drop", "water.waves")
        }
    }

    static func toPar(_ value: Int) -> String {
        value == 0 ? "E" : value > 0 ? "+\(value)" : "\(value)"
    }

    static func scoreName(score: Int, par: Int) -> String {
        switch score - par {
        case ...(-3): return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double bogey"
        case 3: return "Triple bogey"
        default: return "+\(score - par)"
        }
    }

    static func shotConfirmTitle(context: RoundCompanionShotContext, puttHoled: Bool?) -> String {
        switch context {
        case .tee: return "Log tee shot"
        case .shot: return "Log shot"
        case .putt:
            switch puttHoled {
            case true?: return "Hole out"
            case false?: return "Log missed putt"
            case nil: return "Log putt"
            }
        }
    }
}

// MARK: - Shot outcome dial

/// The phone's eight-sector landing dial, clockwise from long (north).
enum WatchShotOutcome: Int, CaseIterable, Identifiable {
    case long
    case longRight
    case right
    case shortRight
    case short
    case shortLeft
    case left
    case longLeft

    var id: Int { rawValue }

    var midAngleDegrees: Double { Double(rawValue) * 45 }

    var label: String {
        switch self {
        case .long: return "Long"
        case .longRight: return "Long R"
        case .right: return "Right"
        case .shortRight: return "Short R"
        case .short: return "Short"
        case .shortLeft: return "Short L"
        case .left: return "Left"
        case .longLeft: return "Long L"
        }
    }

    var spokenLabel: String {
        switch self {
        case .long: return "Long"
        case .longRight: return "Long right"
        case .right: return "Right"
        case .shortRight: return "Short right"
        case .short: return "Short"
        case .shortLeft: return "Short left"
        case .left: return "Left"
        case .longLeft: return "Long left"
        }
    }

    var distance: RoundCompanionDistance {
        switch self {
        case .long, .longRight, .longLeft: return .long
        case .short, .shortRight, .shortLeft: return .short
        case .right, .left: return .onNumber
        }
    }

    var hasLateralMiss: Bool {
        switch self {
        case .long, .short: return false
        default: return true
        }
    }

    func direction(far: Bool) -> RoundCompanionDirection {
        switch self {
        case .longRight, .right, .shortRight: return far ? .farRight : .right
        case .longLeft, .left, .shortLeft: return far ? .farLeft : .left
        case .long, .short: return .hit
        }
    }

    /// The sector under an angle measured clockwise from north, in degrees.
    static func sector(atDegrees degrees: Double) -> WatchShotOutcome {
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let index = Int(((normalized + 22.5) / 45).rounded(.down)) % 8
        return WatchShotOutcome(rawValue: index) ?? .long
    }
}

/// What the Watch logger has chosen so far. `nil` outcome with `isCentre`
/// means a centre hit.
struct WatchShotDraft: Equatable {
    var clubName: String
    var surface: RoundCompanionSurface
    var outcome: WatchShotOutcome? = nil
    var isCentre: Bool = false
    var isFar: Bool = false
    var isProvisional: Bool = false

    var isComplete: Bool { isCentre || outcome != nil }

    var entry: RoundCompanionShotEntry? {
        if isCentre {
            return .init(clubName: clubName, surface: surface, direction: .hit, distance: .onNumber, isProvisional: isProvisional)
        }
        guard let outcome else { return nil }
        return .init(
            clubName: clubName,
            surface: surface,
            direction: outcome.direction(far: isFar),
            distance: outcome.distance,
            isProvisional: isProvisional
        )
    }

    var summary: String {
        if isCentre { return "Centre" }
        guard let outcome else { return "Where did it finish?" }
        return isFar && outcome.hasLateralMiss ? "\(outcome.spokenLabel), far" : outcome.spokenLabel
    }
}

struct WatchPuttDraft: Equatable {
    var holed: Bool? = nil
    var miss: WatchShotOutcome? = nil

    var entry: RoundCompanionPuttEntry? {
        guard let holed else { return nil }
        guard !holed, let miss else { return .init(holed: holed) }
        return .init(holed: false, missDirection: miss.direction(far: false), missDistance: miss.distance)
    }
}
