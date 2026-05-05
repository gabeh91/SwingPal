import SwiftUI

/// Shared app mark: SF Symbol and sizing ratios match the tab bar **Round** control in `AppShellView`.
enum SwingPalBrandMark {
    static let systemImageName = "flag.filled.and.flag.crossed"
    /// Kept in sync with `AppChromeMetrics.floatingRoundButtonSize`.
    static let roundButtonDiameter: CGFloat = 68
    static let symbolPointSize: CGFloat = 20

    static func symbolPointSize(forMarkDiameter diameter: CGFloat) -> CGFloat {
        diameter * (symbolPointSize / roundButtonDiameter)
    }
}

/// Splash mark: same pine gradient circle and symbol as the floating **Round** button (`AppShellView`).
struct SwingPalLaunchLogoView: View {
    var size: CGFloat = 124

    @Environment(\.colorScheme) private var colorScheme

    private var palette: AppTabBarPalette {
        AppTabBarPalette.forColorScheme(colorScheme)
    }

    private var shadowRadius: CGFloat { size * (14.0 / SwingPalBrandMark.roundButtonDiameter) }
    private var shadowY: CGFloat { size * (8.0 / SwingPalBrandMark.roundButtonDiameter) }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            palette.roundGradientTop,
                            palette.roundGradientBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: ShellTokens.Shadow.floating, radius: shadowRadius, y: shadowY)
                .overlay {
                    Circle()
                        .stroke(palette.roundStroke, lineWidth: 1)
                }

            Image(systemName: SwingPalBrandMark.systemImageName)
                .foregroundStyle(ShellTokens.ColorRole.textInverse)
                .font(.system(size: SwingPalBrandMark.symbolPointSize(forMarkDiameter: size), weight: .semibold))
        }
        .frame(width: size, height: size)
    }
}

#if DEBUG
#Preview("Launch logo") {
    ZStack {
        Color(red: 0.05, green: 0.08, blue: 0.07)
        SwingPalLaunchLogoView(size: 164)
    }
    .ignoresSafeArea()
}
#endif
