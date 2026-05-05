import Foundation
import Combine
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

enum WatchRoundSnapshotBootstrap {
    static func snapshot(
        from applicationContext: [String: Any],
        decoder: JSONDecoder = JSONDecoder()
    ) -> RoundCompanionSnapshot? {
        guard let data = applicationContext["roundCompanionSnapshot"] as? Data else {
            return nil
        }

        return try? decoder.decode(RoundCompanionSnapshot.self, from: data)
    }
}

enum WatchRoundPendingAction {
    case changeClub
    case logShot
    case addPenalty
    case markDrop
    case addPutt
    case finishHole
    case undoLastAction
}

enum WatchRoundFeedbackTrigger {
    case queued
    case confirmed
    case unavailable
}

enum WatchRoundHapticStyle {
    case success
    case warning
    case finish
}

struct WatchRoundFeedbackEvent: Equatable, Identifiable {
    let id = UUID()
    let style: WatchRoundHapticStyle
    let message: String
}

enum WatchRoundPreviewImageResolver {
    static func resolve(
        applicationContext: [String: Any],
        snapshot: RoundCompanionSnapshot
    ) -> Data? {
        RoundCompanionContextPayload.previewImageData(from: applicationContext)
    }
}

enum WatchRoundCompanionFeedbackResolver {
    static func feedbackEvent(
        for trigger: WatchRoundFeedbackTrigger,
        pendingAction: WatchRoundPendingAction
    ) -> WatchRoundFeedbackEvent {
        switch trigger {
        case .queued:
            return .init(
                style: .success,
                message: pendingAction == .finishHole ? "Finish queued" : "Action queued"
            )
        case .confirmed:
            switch pendingAction {
            case .changeClub:
                return .init(style: .success, message: "Club changed")
            case .logShot:
                return .init(style: .success, message: "Shot saved")
            case .addPenalty:
                return .init(style: .success, message: "Penalty saved")
            case .markDrop:
                return .init(style: .success, message: "Drop saved")
            case .addPutt:
                return .init(style: .success, message: "Putt saved")
            case .finishHole:
                return .init(style: .finish, message: "Hole finished")
            case .undoLastAction:
                return .init(style: .success, message: "Undo saved")
            }
        case .unavailable:
            return .init(style: .warning, message: "Phone unavailable")
        }
    }
}

#if canImport(WatchConnectivity)
final class WatchRoundCompanionStore: NSObject, ObservableObject {
    @Published private(set) var latestSnapshot: RoundCompanionSnapshot?
    @Published private(set) var latestPreviewImageData: Data?
    @Published private(set) var connectionState: RoundCompanionConnectionState = .disconnected
    @Published private(set) var queuedActionCount: Int = 0
    @Published private(set) var lastActionFeedback: String?
    @Published private(set) var feedbackEvent: WatchRoundFeedbackEvent?

    var canQueueOfflineActions: Bool {
        guard let session else { return false }
        return session.activationState == .activated || queuedActionCount > 0
    }

    private enum PayloadKey {
        static let snapshot = "roundCompanionSnapshot"
        static let action = "roundCompanionAction"
    }

    private let session: WCSession?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var pendingConfirmationAt: Date?
    private var pendingAction: WatchRoundPendingAction?

    override init() {
        if WCSession.isSupported() {
            session = WCSession.default
        } else {
            session = nil
        }

        super.init()

        guard let session else { return }
        session.delegate = self
        refreshConnectionState(using: session)
        applyExistingSnapshotIfAvailable(using: session)
        session.activate()
    }

    func send(_ action: RoundCompanionAction) {
        guard let session else {
            publishUnavailableFeedback()
            publishConnectionState(.disconnected)
            return
        }

        guard let data = try? encoder.encode(action) else {
            publishUnavailableFeedback()
            return
        }

        if session.isReachable {
            session.sendMessageData(data, replyHandler: { [weak self] _ in
                self?.publishConnectionState(.connected)
            }) { [weak self] _ in
                self?.handleImmediateSendFailure(session: session, data: data)
            }
            publishConnectionState(.connected)
        } else if session.activationState == .activated {
            queueActionForReplay(data, using: session)
        } else {
            clearOptimisticState()
            publishConnectionState(.disconnected)
        }
    }

    func sendChangeClub(named clubName: String) {
        send(.changeClub(name: clubName), pendingAction: .changeClub)
    }

    func sendQuickShot(direction: String, distance: String, surface: String? = nil) {
        send(.logShot(direction: direction, distance: distance, surface: surface), pendingAction: .logShot)
    }

    func sendAddPenalty() {
        send(.addPenalty, pendingAction: .addPenalty)
    }

    func sendMarkDrop() {
        send(.markDrop, pendingAction: .markDrop)
    }

    func sendAddPutt() {
        send(.addPutt, pendingAction: .addPutt)
    }

    func sendFinishHole() {
        send(.finishHole, pendingAction: .finishHole)
    }

    func sendUndoLastAction() {
        send(.undoLastAction, pendingAction: .undoLastAction)
    }

    private func apply(snapshot: RoundCompanionSnapshot) {
        let applySnapshot = {
            self.latestSnapshot = snapshot
            self.clearQueuedStateIfConfirmed(by: snapshot)
            if self.queuedActionCount == 0 {
                self.lastActionFeedback = nil
            }
            self.connectionState = self.resolvedConnectionState(from: snapshot)
        }

        if Thread.isMainThread {
            applySnapshot()
        } else {
            DispatchQueue.main.async(execute: applySnapshot)
        }
    }

    private func publishConnectionState(_ nextState: RoundCompanionConnectionState) {
        let update = {
            self.connectionState = nextState
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    private func publishFeedback(_ message: String) {
        let update = {
            self.lastActionFeedback = message
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    private func publishFeedbackEvent(_ event: WatchRoundFeedbackEvent) {
        let update = {
            self.feedbackEvent = event
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    private func send(_ action: RoundCompanionAction, pendingAction: WatchRoundPendingAction) {
        self.pendingAction = pendingAction
        pendingConfirmationAt = .now
        send(action)
    }

    private func refreshConnectionState(
        using session: WCSession,
        activationStateOverride: WCSessionActivationState? = nil
    ) {
        let activationState = activationStateOverride ?? session.activationState
        publishConnectionState(resolvedConnectionState(using: session, activationState: activationState))
    }

    private func queueActionForReplay(_ data: Data, using session: WCSession) {
        queuedActionCount += 1
        session.transferUserInfo([PayloadKey.action: data])
        publishConnectionState(.syncing)
        guard let pendingAction else { return }
        let event = WatchRoundCompanionFeedbackResolver.feedbackEvent(for: .queued, pendingAction: pendingAction)
        publishFeedback(event.message)
        publishFeedbackEvent(event)
    }

    private func handleImmediateSendFailure(session: WCSession, data: Data) {
        if session.activationState == .activated {
            queueActionForReplay(data, using: session)
        } else {
            publishUnavailableFeedback()
            publishConnectionState(.disconnected)
        }
    }

    private func clearQueuedStateIfConfirmed(by snapshot: RoundCompanionSnapshot) {
        guard
            let pendingConfirmationAt,
            snapshot.lastMutationSource == .watch,
            snapshot.lastMutationAt >= pendingConfirmationAt
        else {
            return
        }

        queuedActionCount = 0
        if let pendingAction {
            let event = WatchRoundCompanionFeedbackResolver.feedbackEvent(for: .confirmed, pendingAction: pendingAction)
            publishFeedback(event.message)
            publishFeedbackEvent(event)
        }
        self.pendingAction = nil
        self.pendingConfirmationAt = nil
    }

    private func clearOptimisticState() {
        let update = {
            self.lastActionFeedback = nil
            self.pendingAction = nil
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    private func resolvedConnectionState(from snapshot: RoundCompanionSnapshot?) -> RoundCompanionConnectionState {
        guard let session else {
            return queuedActionCount > 0 ? .syncing : .disconnected
        }

        return resolvedConnectionState(
            using: session,
            activationState: session.activationState,
            snapshotState: snapshot?.connectionState
        )
    }

    private func resolvedConnectionState(
        using session: WCSession,
        activationState: WCSessionActivationState,
        snapshotState: RoundCompanionConnectionState? = nil
    ) -> RoundCompanionConnectionState {
        if queuedActionCount > 0 {
            return .syncing
        }

        if session.isReachable {
            return .connected
        }

        if activationState == .activated {
            return snapshotState == .connected ? .disconnected : (snapshotState ?? .disconnected)
        }

        return .disconnected
    }

    private func publishUnavailableFeedback() {
        guard let pendingAction else { return }
        let event = WatchRoundCompanionFeedbackResolver.feedbackEvent(for: .unavailable, pendingAction: pendingAction)
        publishFeedback(event.message)
        publishFeedbackEvent(event)
    }

    private func applyExistingSnapshotIfAvailable(using session: WCSession) {
        if apply(applicationContext: session.receivedApplicationContext) {
            return
        }

        _ = apply(applicationContext: session.applicationContext)
    }

    @discardableResult
    private func apply(applicationContext: [String: Any]) -> Bool {
        guard let snapshot = WatchRoundSnapshotBootstrap.snapshot(from: applicationContext, decoder: decoder) else {
            return false
        }

        apply(snapshot: snapshot)
        publishPreviewImageData(
            WatchRoundPreviewImageResolver.resolve(
                applicationContext: applicationContext,
                snapshot: snapshot
            )
        )
        return true
    }

    private func publishPreviewImageData(_ previewImageData: Data?) {
        let update = {
            self.latestPreviewImageData = previewImageData
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }
}

extension WatchRoundCompanionStore: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        refreshConnectionState(using: session, activationStateOverride: activationState)
        applyExistingSnapshotIfAvailable(using: session)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        refreshConnectionState(using: session)
        if latestSnapshot == nil {
            applyExistingSnapshotIfAvailable(using: session)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        _ = apply(applicationContext: applicationContext)
    }
}
#endif
