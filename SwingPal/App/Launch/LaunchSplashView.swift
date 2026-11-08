import SwiftUI

// MARK: - Launch splash
//
// Picks up exactly where LaunchScreen.storyboard leaves off (paper, the mark
// centred at 200 pt) and plays the hole once: a ball leaves the tee, runs the
// S with its line pencilled in behind it and drops at the pin while the
// wordmark is set beneath. Then the page lifts away. About 1.3 s, never loops,
// never blocks touches, and Reduce Motion skips the ball.

struct LaunchSplashView: View {
    /// Stretches every duration; the design-review fixture slows it down to inspect frames.
    var pace: Double = 1
    var onFinished: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = false

    static let markSide: CGFloat = 200

    init(pace: Double = 1, onFinished: @escaping () -> Void = {}) {
        self.pace = pace
        self.onFinished = onFinished
    }

    struct Frame {
        var ball = 0.0
        var ballScale = 0.0
        var word = 0.0
        var veil = 1.0
    }

    var body: some View {
        KeyframeAnimator(initialValue: Frame(), trigger: started) { frame in
            ZStack {
                Book.paper
                SwingPalMark(colorway: .page,
                             ballProgress: reduceMotion ? nil : frame.ball,
                             ballScale: frame.ballScale)
                    .frame(width: Self.markSide, height: Self.markSide)
                    .scaleEffect(1 + (1 - frame.veil) * 0.04)
                wordmark
                    .opacity(frame.word)
                    .offset(y: Self.markSide / 2 + 46 + (1 - frame.word) * 8)
            }
            .opacity(frame.veil)
            .ignoresSafeArea()
        } keyframes: { _ in
            let d = pace
            KeyframeTrack(\.ballScale) {
                LinearKeyframe(0, duration: 0.1 * d)
                CubicKeyframe(1, duration: 0.12 * d)
                LinearKeyframe(1, duration: 0.58 * d)
                CubicKeyframe(0, duration: 0.12 * d)
            }
            KeyframeTrack(\.ball) {
                LinearKeyframe(0, duration: 0.18 * d)
                CubicKeyframe(1, duration: 0.64 * d)
            }
            KeyframeTrack(\.word) {
                LinearKeyframe(0, duration: (reduceMotion ? 0.05 : 0.3) * d)
                CubicKeyframe(1, duration: 0.35 * d)
            }
            KeyframeTrack(\.veil) {
                LinearKeyframe(1, duration: (reduceMotion ? 0.7 : 1.02) * d)
                CubicKeyframe(0, duration: 0.28 * d)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            started = true
            try? await Task.sleep(for: .seconds(((reduceMotion ? 0.7 : 1.02) + 0.3) * pace))
            onFinished()
        }
    }

    private var wordmark: some View {
        VStack(spacing: 6) {
            Text("SwingPal")
                .font(Book.Typeface.display)
                .foregroundStyle(Book.ink)
            BookNote("Your yardage book")
        }
        .dynamicTypeSize(.large ... .xxLarge)
    }
}

#if DEBUG
#Preview("Splash") {
    LaunchSplashView(pace: 3)
}
#endif
