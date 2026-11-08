import Foundation

// Pure presentation and delivery logic for the Watch companion. Kept free of
// SwiftUI and WatchConnectivity so it compiles into the unit-test target too.

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
