import XCTest
@testable import SwingPal

final class WatchCompanionTests: XCTestCase {
    // MARK: Ledger

    func testLedgerAppliesAnEnvelopeOnceAndReturnsTheSameReceiptForARedelivery() {
        let ledger = RoundCompanionActionLedger()
        let envelope = RoundCompanionActionEnvelope(action: .retee, holeNumber: 3)
        var applyCount = 0

        let first = ledger.process(envelope) { envelope in
            applyCount += 1
            return .init(actionID: envelope.id, outcome: .applied)
        }
        let second = ledger.process(envelope) { envelope in
            applyCount += 1
            return .init(actionID: envelope.id, outcome: .notAvailable)
        }

        XCTAssertEqual(applyCount, 1)
        XCTAssertEqual(first, second)
        XCTAssertEqual(ledger.recentReceipts(), [first])
    }

    func testLedgerRefusesAnotherProtocolVersionWithoutApplyingIt() {
        let ledger = RoundCompanionActionLedger()
        var envelope = RoundCompanionActionEnvelope(action: .markBall, holeNumber: 1)
        envelope.protocolVersion = 1

        let receipt = ledger.process(envelope) { _ in
            XCTFail("Should not apply")
            return .init(actionID: envelope.id, outcome: .applied)
        }

        XCTAssertEqual(receipt.outcome, .unsupportedVersion)
    }

    func testLedgerKeepsOnlyRecentReceipts() {
        let ledger = RoundCompanionActionLedger(capacity: 3)
        for _ in 0..<5 {
            _ = ledger.process(.init(action: .markBall, holeNumber: 1)) { .init(actionID: $0.id, outcome: .applied) }
        }

        XCTAssertEqual(ledger.receipts.count, 3)
        XCTAssertEqual(ledger.recentReceipts(limit: 2).count, 2)
    }

    // MARK: Payload

    func testContextRoundTripsTheSnapshot() throws {
        let snapshot = Self.snapshot()

        let context = try RoundCompanionContextPayload.context(snapshot: snapshot)

        XCTAssertEqual(RoundCompanionContextPayload.content(from: context), .snapshot(snapshot))
    }

    func testRoundEndedContextReadsAsNoRound() {
        XCTAssertEqual(RoundCompanionContextPayload.content(from: RoundCompanionContextPayload.roundEndedContext()), .noRound)
        XCTAssertEqual(RoundCompanionContextPayload.content(from: [:]), .noRound)
    }

    func testSnapshotFromAnotherProtocolVersionIsUnreadable() throws {
        var snapshot = Self.snapshot()
        snapshot.protocolVersion = 99
        let context = try RoundCompanionContextPayload.context(snapshot: snapshot)

        XCTAssertEqual(RoundCompanionContextPayload.content(from: context), .unreadable)
        XCTAssertEqual(RoundCompanionContextPayload.content(from: ["roundCompanionSnapshot": Data("{}".utf8)]), .unreadable)
    }

    func testQueuedEnvelopeRoundTripsThroughUserInfo() throws {
        let envelope = RoundCompanionActionEnvelope(
            action: .logShot(.init(clubName: "7i", surface: .rough, direction: .farRight, distance: .short)),
            holeNumber: 7
        )

        let userInfo = try RoundCompanionContextPayload.userInfo(for: envelope)

        XCTAssertEqual(RoundCompanionContextPayload.envelope(fromUserInfo: userInfo), envelope)
    }

    // MARK: Outbox

    func testOutboxResolvesEachActionOnceFromRepeatedReceipts() {
        var outbox = WatchCompanionOutbox()
        let envelope = RoundCompanionActionEnvelope(action: .undoLastShot, holeNumber: 2)
        outbox.add(envelope, delivery: .sending)
        outbox.markQueued(envelope.id)
        XCTAssertEqual(outbox.queuedCount, 1)

        let receipt = RoundCompanionActionReceipt(actionID: envelope.id, outcome: .applied)
        let first = outbox.resolve(receipts: [receipt])
        let second = outbox.resolve(receipts: [receipt])

        XCTAssertEqual(first.count, 1)
        XCTAssertTrue(second.isEmpty)
        XCTAssertTrue(outbox.isEmpty)
    }

    func testFeedbackOnlyCallsAnActionSavedWhenTheIPhoneApplied() {
        let action = RoundCompanionAction.quickPenalty(.water)
        let id = UUID()

        let saved = WatchActionFeedback.resolved(action, receipt: .init(actionID: id, outcome: .applied))
        let refused = WatchActionFeedback.resolved(action, receipt: .init(actionID: id, outcome: .holeChanged))
        let finished = WatchActionFeedback.resolved(.finishHole(score: 4, putts: 2), receipt: .init(actionID: id, outcome: .applied))

        XCTAssertEqual(saved.tone, .saved)
        XCTAssertEqual(saved.message, "Penalty added")
        XCTAssertEqual(refused.tone, .refused)
        XCTAssertEqual(refused.message, "Hole changed · not saved")
        XCTAssertEqual(finished.tone, .finished)
    }

    // MARK: Presentation

    func testPresentationWritesTheHoleAndGreenInTheRoundUnit() {
        let model = WatchRoundPresentation(snapshot: Self.snapshot(unit: .yards), link: .live)

        XCTAssertEqual(model.phase, .live)
        XCTAssertEqual(model.folioText, "05")
        XCTAssertEqual(model.parText, "Par 4")
        XCTAssertEqual(model.centreText, "164")
        XCTAssertEqual(model.frontText, "153")
        XCTAssertEqual(model.backText, "175")
        XCTAssertEqual(model.unitSuffix, "yd")
        XCTAssertEqual(model.clubCode, "7i")
        XCTAssertEqual(model.carryText, "153 yd")
        XCTAssertEqual(model.carrySourceText, "From your bag")
        XCTAssertNil(model.statusLine)
        XCTAssertTrue(model.canRecordShots)
    }

    func testPresentationSaysWhyThereIsNoYardage() {
        let model = WatchRoundPresentation(
            snapshot: Self.snapshot(yardage: nil, status: .noLocation),
            link: .live
        )

        XCTAssertFalse(model.hasYardage)
        XCTAssertEqual(model.centreText, "—")
        XCTAssertEqual(model.yardageNote, "Waiting for GPS")
    }

    func testPresentationBlocksShotEntryWhileTheIPhoneShowsAnotherHole() {
        let model = WatchRoundPresentation(
            snapshot: Self.snapshot(yardage: nil, status: .inspectingOtherHole, inspectedHole: 2),
            link: .live
        )

        XCTAssertFalse(model.canRecordShots)
        XCTAssertTrue(model.isInspectingOnPhone)
        XCTAssertEqual(model.statusLine, "iPhone is showing hole 2")
        XCTAssertEqual(model.recordBlockedReason, "iPhone is showing another hole")
    }

    func testPresentationCallsOutQueuedActionsAndStaleYardage() {
        var outbox = WatchCompanionOutbox()
        let envelope = RoundCompanionActionEnvelope(action: .markBall, holeNumber: 5)
        outbox.add(envelope, delivery: .queued)

        let queued = WatchRoundPresentation(snapshot: Self.snapshot(), link: .outOfReach, outbox: outbox)
        let stale = WatchRoundPresentation(snapshot: Self.snapshot(), link: .outOfReach, snapshotAge: 200)

        XCTAssertEqual(queued.statusLine, "1 action waiting for iPhone")
        XCTAssertTrue(stale.isStale)
        XCTAssertEqual(stale.statusLine, "iPhone out of reach · yardage may be old")
    }

    func testPresentationPhases() {
        XCTAssertEqual(WatchRoundPresentation(snapshot: nil, link: .live).phase, .noRound)
        XCTAssertEqual(WatchRoundPresentation(snapshot: nil, isUnreadable: true, link: .live).phase, .incompatible)
        XCTAssertEqual(WatchRoundPresentation(snapshot: Self.snapshot(isRoundComplete: true), link: .live).phase, .roundComplete)
    }

    func testClubsReadLongestToShortest() {
        let model = WatchRoundPresentation(snapshot: Self.snapshot(), link: .live)

        XCTAssertEqual(model.clubsByCarry.map(\.name), ["Driver", "7i", "Putter"])
    }

    func testUndoTitleNamesTheShot() {
        let model = WatchRoundPresentation(snapshot: Self.snapshot(), link: .live)

        XCTAssertEqual(model.undoTitle, "Undo Dr")
        XCTAssertEqual(model.undoDetail, "From the tee")
    }

    // MARK: Shot entry

    func testOutcomeDialMatchesThePhoneTaxonomy() {
        XCTAssertEqual(WatchShotOutcome.sector(atDegrees: 0), .long)
        XCTAssertEqual(WatchShotOutcome.sector(atDegrees: 44), .longRight)
        XCTAssertEqual(WatchShotOutcome.sector(atDegrees: 90), .right)
        XCTAssertEqual(WatchShotOutcome.sector(atDegrees: 180), .short)
        XCTAssertEqual(WatchShotOutcome.sector(atDegrees: -90), .left)
        XCTAssertEqual(WatchShotOutcome.sector(atDegrees: 350), .long)

        XCTAssertEqual(WatchShotOutcome.shortLeft.direction(far: true), .farLeft)
        XCTAssertEqual(WatchShotOutcome.shortLeft.distance, .short)
        XCTAssertEqual(WatchShotOutcome.right.distance, .onNumber)
        XCTAssertEqual(WatchShotOutcome.long.direction(far: true), .hit)
    }

    func testShotDraftBuildsTheEntryTheIPhoneLogs() {
        var draft = WatchShotDraft(clubName: "Driver", surface: .tee)
        XCTAssertNil(draft.entry)

        draft.outcome = .longRight
        draft.isFar = true
        draft.isProvisional = true
        XCTAssertEqual(draft.entry, .init(clubName: "Driver", surface: .tee, direction: .farRight, distance: .long, isProvisional: true))

        draft.outcome = nil
        draft.isCentre = true
        XCTAssertEqual(draft.entry?.direction, .hit)
        XCTAssertEqual(draft.entry?.distance, .onNumber)
    }

    func testPuttDraftNeedsHoledOrMissed() {
        var draft = WatchPuttDraft()
        XCTAssertNil(draft.entry)

        draft.holed = false
        XCTAssertEqual(draft.entry, .init(holed: false))

        draft.miss = .shortLeft
        XCTAssertEqual(draft.entry, .init(holed: false, missDirection: .left, missDistance: .short))
    }

    func testConfirmTitlesUseThePhoneVerbs() {
        XCTAssertEqual(WatchBookLabels.shotConfirmTitle(context: .tee, puttHoled: nil), "Log tee shot")
        XCTAssertEqual(WatchBookLabels.shotConfirmTitle(context: .shot, puttHoled: nil), "Log shot")
        XCTAssertEqual(WatchBookLabels.shotConfirmTitle(context: .putt, puttHoled: true), "Hole out")
        XCTAssertEqual(WatchBookLabels.shotConfirmTitle(context: .putt, puttHoled: false), "Log missed putt")
    }

    // MARK: Sketch

    func testSketchSimplificationKeepsCornersAndDropsNoise() {
        var ring: [(x: Double, y: Double)] = []
        for i in 0...40 { ring.append((Double(i) * 2.5, 0.2 * Double(i % 2))) }
        ring.append((100, 60))
        ring.append((0, 60))

        let simplified = RoundCompanionHoleSketch.simplified(ring)

        XCTAssertTrue(simplified.contains(.init(x: 0, y: 0)))
        XCTAssertTrue(simplified.contains(.init(x: 100, y: 60)))
        XCTAssertTrue(simplified.contains(.init(x: 0, y: 60)))
        XCTAssertLessThanOrEqual(simplified.count, 6)
    }

    func testSketchSimplificationCapsPointCount() {
        let circle = (0..<400).map { index -> (x: Double, y: Double) in
            let angle = Double(index) / 400 * 2 * .pi
            return (cos(angle) * 300, sin(angle) * 300)
        }

        XCTAssertLessThanOrEqual(RoundCompanionHoleSketch.simplified(circle, maxPoints: 48).count, 48)
    }

    // MARK: Fixtures

    static func snapshot(
        unit: DistanceUnit = .meters,
        yardage: RoundCompanionYardage? = .init(frontMeters: 140, centreMeters: 150, backMeters: 160),
        status: RoundCompanionYardageStatus = .live,
        inspectedHole: Int? = nil,
        isRoundComplete: Bool = false
    ) -> RoundCompanionSnapshot {
        RoundCompanionSnapshot(
            courseName: "Medway Golf Club",
            distanceUnit: unit,
            holeNumber: 5,
            par: 4,
            holeCount: 18,
            inspectedHoleNumber: inspectedHole,
            isRoundComplete: isRoundComplete,
            yardage: yardage,
            yardageStatus: status,
            selectedClubName: "7i",
            clubs: [
                .init(name: "7i", carryMeters: 140, isEstimated: false),
                .init(name: "Driver", carryMeters: 220, isEstimated: true),
                .init(name: "Putter", carryMeters: 10, isEstimated: true),
            ],
            recommendedClubName: "7i",
            shotContext: .shot,
            suggestedSurface: .fairway,
            strokeNumber: 2,
            holeScore: 1,
            puttCount: 0,
            penaltyCount: 0,
            lastShot: .init(clubName: "Driver", surface: .tee, isPutt: false, isPenalty: false),
            canUndoLastShot: true,
            ballMark: .available,
            proposedHoleScore: 1,
            proposedHolePutts: 0,
            roundScoreToPar: 2,
            confirmedHoleCount: 4,
            isPhoneBusy: false,
            sketch: nil,
            lastMutationSource: .phone,
            lastMutationAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}
