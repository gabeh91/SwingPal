import SwiftUI

struct WatchFeedbackToast: View {
    let feedback: WatchActionFeedback

    private var symbol: String {
        switch feedback.tone {
        case .saved: return "checkmark"
        case .finished: return "flag.fill"
        case .queued: return "clock"
        case .refused: return "exclamationmark"
        }
    }

    var body: some View {
        Label(feedback.message, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
            .foregroundStyle(feedback.tone == .refused ? WatchBook.warning : WatchBook.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(WatchBook.leaf, in: Capsule())
            .overlay(Capsule().strokeBorder(WatchBook.rule, lineWidth: 0.5))
            .padding(.top, 2)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityAddTraits(.isStaticText)
    }
}
