import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

@main
struct SwingPalWatchApp: App {
    @StateObject private var companionStore = WatchRoundCompanionStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                let model = WatchRoundCompanionViewModel(
                    snapshot: companionStore.latestSnapshot,
                    connectionState: companionStore.connectionState,
                    queuedActionCount: companionStore.queuedActionCount,
                    canQueueOfflineActions: companionStore.canQueueOfflineActions,
                    actionFeedback: companionStore.lastActionFeedback
                )

                WatchRoundHomeView(store: companionStore, model: model)
                    .onChange(of: companionStore.feedbackEvent?.id) { _, _ in
                        guard let event = companionStore.feedbackEvent else { return }
                        WatchRoundHaptics.play(event.style)
                    }
            }
        }
    }
}

private enum WatchRoundHaptics {
    static func play(_ style: WatchRoundHapticStyle) {
        #if canImport(WatchKit)
        let hapticType: WKHapticType
        switch style {
        case .success:
            hapticType = .success
        case .warning:
            hapticType = .failure
        case .finish:
            hapticType = .notification
        }

        WKInterfaceDevice.current().play(hapticType)
        #endif
    }
}
