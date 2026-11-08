import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

@main
struct SwingPalWatchApp: App {
    @StateObject private var companionStore = WatchRoundCompanionStore()

    var body: some Scene {
        WindowGroup {
            WatchRoundRootView(store: companionStore)
                .onChange(of: companionStore.feedback?.id) { _, _ in
                    guard let feedback = companionStore.feedback else { return }
                    WatchRoundHaptics.play(feedback.tone)
                }
        }
    }
}

/// Haptics follow the iPhone's answer, not the tap: success only once a
/// change is saved, a failure buzz when it was refused.
private enum WatchRoundHaptics {
    static func play(_ tone: WatchActionFeedback.Tone) {
        #if canImport(WatchKit)
        let hapticType: WKHapticType
        switch tone {
        case .saved: hapticType = .success
        case .finished: hapticType = .notification
        case .queued: hapticType = .click
        case .refused: hapticType = .failure
        }
        WKInterfaceDevice.current().play(hapticType)
        #endif
    }
}
