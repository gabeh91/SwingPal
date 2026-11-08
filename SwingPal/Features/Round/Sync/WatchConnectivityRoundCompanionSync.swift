import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

enum WatchCompanionInstallState: Equatable {
    case unsupported
    case notPaired
    case watchAppNotInstalled
    case installedButNotReachable
    case ready

    static func resolve(
        isSupported: Bool,
        isPaired: Bool,
        isWatchAppInstalled: Bool,
        isReachable: Bool
    ) -> WatchCompanionInstallState {
        guard isSupported else {
            return .unsupported
        }

        guard isPaired else {
            return .notPaired
        }

        guard isWatchAppInstalled else {
            return .watchAppNotInstalled
        }

        return isReachable ? .ready : .installedButNotReachable
    }
}

protocol WatchCompanionStatusReporting: AnyObject {
    var installState: WatchCompanionInstallState { get }
}

/// Phone end of the Watch link. Snapshots travel as application context (the
/// Watch always sees the latest one); Watch actions arrive as messages with a
/// reply, or as queued user info when the phone was out of reach.
final class WatchConnectivityRoundCompanionSync: NSObject, RoundCompanionSyncing, RoundCompanionActionReceiving, WatchCompanionStatusReporting {
    /// GPS ticks republish the round constantly; the Watch needs at most one
    /// update a second. Action results bypass this.
    private static let minimumPublishInterval: TimeInterval = 1.0

    private let ledger = RoundCompanionActionLedger()
    private var incomingActionHandler: ((RoundCompanionActionEnvelope) -> RoundCompanionActionReceipt)?
    private var latestSnapshot: RoundCompanionSnapshot?
    private var lastDeliveredSnapshot: RoundCompanionSnapshot?
    private var lastDeliveredAt: Date = .distantPast
    private var pendingDelivery: DispatchWorkItem?
    private var needsRoundEndedDelivery = false

    override init() {
        super.init()
        activateSessionIfAvailable()
    }

    func publish(snapshot: RoundCompanionSnapshot) {
        onMain {
            self.latestSnapshot = snapshot
            self.needsRoundEndedDelivery = false
            self.scheduleDelivery(immediately: false)
        }
    }

    func clear() {
        onMain {
            self.pendingDelivery?.cancel()
            self.pendingDelivery = nil
            self.latestSnapshot = nil
            self.lastDeliveredSnapshot = nil
            self.needsRoundEndedDelivery = true
            self.deliverRoundEndedIfNeeded()
        }
    }

    func setIncomingActionHandler(_ handler: @escaping (RoundCompanionActionEnvelope) -> RoundCompanionActionReceipt) {
        incomingActionHandler = handler
    }

    var installState: WatchCompanionInstallState {
        #if canImport(WatchConnectivity) && os(iOS)
        guard WCSession.isSupported() else { return .unsupported }
        let session = WCSession.default
        return WatchCompanionInstallState.resolve(
            isSupported: true,
            isPaired: session.isPaired,
            isWatchAppInstalled: session.isWatchAppInstalled,
            isReachable: session.isReachable
        )
        #else
        return .unsupported
        #endif
    }

    // MARK: Actions

    private func handle(_ envelope: RoundCompanionActionEnvelope) -> RoundCompanionActionReceipt {
        dispatchPrecondition(condition: .onQueue(.main))
        let receipt = ledger.process(envelope) { envelope in
            incomingActionHandler?(envelope) ?? .init(actionID: envelope.id, outcome: .noActiveRound)
        }
        scheduleDelivery(immediately: true)
        return receipt
    }

    // MARK: Delivery

    private func scheduleDelivery(immediately: Bool) {
        guard latestSnapshot != nil else { return }
        let elapsed = Date().timeIntervalSince(lastDeliveredAt)
        if immediately || elapsed >= Self.minimumPublishInterval {
            pendingDelivery?.cancel()
            pendingDelivery = nil
            deliverLatestSnapshot()
            return
        }
        guard pendingDelivery == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.pendingDelivery = nil
            self?.deliverLatestSnapshot()
        }
        pendingDelivery = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (Self.minimumPublishInterval - elapsed), execute: work)
    }

    private func deliverLatestSnapshot() {
        guard var snapshot = latestSnapshot else { return }
        snapshot.receipts = ledger.recentReceipts()
        guard snapshot != lastDeliveredSnapshot else { return }
        #if canImport(WatchConnectivity)
        guard let session = readySession() else { return }
        do {
            try session.updateApplicationContext(RoundCompanionContextPayload.context(snapshot: snapshot))
            lastDeliveredSnapshot = snapshot
            lastDeliveredAt = Date()
        } catch {
            print("WatchConnectivity publish failed: \(error)")
        }
        #endif
    }

    private func deliverRoundEndedIfNeeded() {
        guard needsRoundEndedDelivery else { return }
        #if canImport(WatchConnectivity)
        guard let session = readySession() else { return }
        do {
            try session.updateApplicationContext(RoundCompanionContextPayload.roundEndedContext())
            needsRoundEndedDelivery = false
        } catch {
            print("WatchConnectivity round-end publish failed: \(error)")
        }
        #endif
    }

    private func redeliverAfterSessionChange() {
        if needsRoundEndedDelivery {
            deliverRoundEndedIfNeeded()
        } else {
            lastDeliveredSnapshot = nil
            scheduleDelivery(immediately: true)
        }
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    #if canImport(WatchConnectivity)
    private func activateSessionIfAvailable() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// The session when a paired Watch with SwingPal installed can receive context.
    private func readySession() -> WCSession? {
        guard WCSession.isSupported() else { return nil }
        let session = WCSession.default
        guard session.activationState == .activated else { return nil }
        #if os(iOS)
        let installState = WatchCompanionInstallState.resolve(
            isSupported: true,
            isPaired: session.isPaired,
            isWatchAppInstalled: session.isWatchAppInstalled,
            isReachable: session.isReachable
        )
        switch installState {
        case .unsupported, .notPaired, .watchAppNotInstalled:
            return nil
        case .installedButNotReachable, .ready:
            return session
        }
        #else
        return session
        #endif
    }
    #else
    private func activateSessionIfAvailable() {}
    #endif
}

#if canImport(WatchConnectivity)
extension WatchConnectivityRoundCompanionSync: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        onMain { self.redeliverAfterSessionChange() }
    }

    #if os(iOS)
    func sessionWatchStateDidChange(_ session: WCSession) {
        onMain { self.redeliverAfterSessionChange() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    func session(
        _ session: WCSession,
        didReceiveMessageData messageData: Data,
        replyHandler: @escaping (Data) -> Void
    ) {
        guard let envelope = try? JSONDecoder().decode(RoundCompanionActionEnvelope.self, from: messageData) else {
            // An envelope this build cannot read: the apps are out of step.
            replyHandler(Data())
            return
        }
        DispatchQueue.main.async {
            let receipt = self.handle(envelope)
            replyHandler((try? JSONEncoder().encode(receipt)) ?? Data())
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let envelope = RoundCompanionContextPayload.envelope(fromUserInfo: userInfo) else { return }
        DispatchQueue.main.async {
            _ = self.handle(envelope)
        }
    }
}
#endif
