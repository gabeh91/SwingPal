import Foundation
import Combine
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Watch end of the round link. The iPhone owns the round; this store renders
/// its snapshots and sends requests, reporting each as saved only once the
/// iPhone's receipt comes back.
final class WatchRoundCompanionStore: NSObject, ObservableObject {
    @Published private(set) var snapshot: RoundCompanionSnapshot?
    @Published private(set) var isSnapshotUnreadable = false
    @Published private(set) var snapshotReceivedAt: Date?
    @Published private(set) var link: WatchCompanionLink = .unavailable
    @Published private(set) var outbox = WatchCompanionOutbox()
    @Published private(set) var feedback: WatchActionFeedback?

    #if canImport(WatchConnectivity)
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    #endif

    override init() {
        super.init()
        #if canImport(WatchConnectivity)
        guard let session else { return }
        session.delegate = self
        session.activate()
        #endif
    }

    func presentation(at date: Date = .now) -> WatchRoundPresentation {
        WatchRoundPresentation(
            snapshot: snapshot,
            isUnreadable: isSnapshotUnreadable,
            link: link,
            outbox: outbox,
            snapshotAge: snapshotReceivedAt.map { date.timeIntervalSince($0) }
        )
    }

    func send(_ action: RoundCompanionAction) {
        guard let snapshot else {
            feedback = .init(tone: .refused, message: WatchActionFeedback.refusalMessage(.noActiveRound))
            return
        }
        let envelope = RoundCompanionActionEnvelope(action: action, holeNumber: snapshot.holeNumber)

        #if canImport(WatchConnectivity)
        guard let session, session.activationState == .activated else {
            feedback = .unreachable
            return
        }
        guard let data = try? JSONEncoder().encode(envelope) else { return }

        if session.isReachable {
            outbox.add(envelope, delivery: .sending)
            session.sendMessageData(data, replyHandler: { [weak self] reply in
                DispatchQueue.main.async { self?.handleReply(reply, for: envelope) }
            }, errorHandler: { [weak self] _ in
                // The message may or may not have arrived; the iPhone ignores
                // a second copy of the same envelope.
                DispatchQueue.main.async { self?.queue(envelope, using: session) }
            })
        } else {
            outbox.add(envelope, delivery: .sending)
            queue(envelope, using: session)
        }
        #else
        feedback = .unreachable
        #endif
    }

    func clearFeedback(_ id: UUID) {
        guard feedback?.id == id else { return }
        feedback = nil
    }

    // MARK: Receipts

    private func handleReply(_ reply: Data, for envelope: RoundCompanionActionEnvelope) {
        let receipt = (try? JSONDecoder().decode(RoundCompanionActionReceipt.self, from: reply))
            ?? .init(actionID: envelope.id, outcome: .unsupportedVersion)
        resolve([receipt])
    }

    private func resolve(_ receipts: [RoundCompanionActionReceipt]) {
        let resolved = outbox.resolve(receipts: receipts)
        if let (entry, receipt) = resolved.last {
            feedback = .resolved(entry.envelope.action, receipt: receipt)
        }
    }

    #if canImport(WatchConnectivity)
    private func queue(_ envelope: RoundCompanionActionEnvelope, using session: WCSession) {
        guard outbox.contains(envelope.id) else { return }
        guard let userInfo = try? RoundCompanionContextPayload.userInfo(for: envelope) else {
            _ = outbox.discard(envelope.id)
            feedback = .unreachable
            return
        }
        outbox.markQueued(envelope.id)
        session.transferUserInfo(userInfo)
        feedback = .queued(envelope.action)
    }
    #endif

    // MARK: Snapshots

    /// `isCached` marks the context replayed at launch, which may be old; its
    /// age then comes from when the iPhone last updated it.
    private func apply(context: [String: Any], receivedAt date: Date, isCached: Bool = false) {
        switch RoundCompanionContextPayload.content(from: context) {
        case .snapshot(let snapshot):
            self.snapshot = snapshot
            isSnapshotUnreadable = false
            snapshotReceivedAt = isCached ? min(snapshot.lastMutationAt, date) : date
            resolve(snapshot.receipts)
        case .noRound:
            snapshot = nil
            isSnapshotUnreadable = false
            snapshotReceivedAt = nil
            outbox = .init()
        case .unreadable:
            snapshot = nil
            isSnapshotUnreadable = true
            snapshotReceivedAt = nil
        }
    }

    #if canImport(WatchConnectivity)
    private func refreshLink(_ session: WCSession) {
        if session.activationState != .activated {
            link = .unavailable
        } else {
            link = session.isReachable ? .live : .outOfReach
        }
    }
    #endif
}

#if canImport(WatchConnectivity)
extension WatchRoundCompanionStore: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let context = session.receivedApplicationContext
        DispatchQueue.main.async {
            self.refreshLink(session)
            self.apply(context: context, receivedAt: .now, isCached: true)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.refreshLink(session) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.refreshLink(session)
            self.apply(context: applicationContext, receivedAt: .now)
        }
    }
}
#endif
