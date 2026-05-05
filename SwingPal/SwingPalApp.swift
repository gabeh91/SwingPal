import SwiftUI

@main
struct SwingPalApp: App {
    @State private var isShowingSplash = true
    @StateObject private var appState: AppState
    @StateObject private var authViewModel: AuthViewModel
    private let authService: AuthService

    init() {
        let service = SwingPalAuthServiceFactory.make()
        let state = AppState()
        state.attachAuthService(service)
        _appState = StateObject(wrappedValue: state)
        _authViewModel = StateObject(wrappedValue: AuthViewModel(
            authService: service,
            appleCoordinatorFactory: { AppleSignInCoordinator() }
        ))
        authService = service
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                rootContent

                if isShowingSplash {
                    SwingPalSplashView()
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97)),
                                removal: .move(edge: .top)
                                    .combined(with: .opacity)
                                    .combined(with: .scale(scale: 0.96))
                            )
                        )
                        .zIndex(1)
                }
            }
            .preferredColorScheme(appState.appearanceMode.preferredColorScheme)
            .animation(.spring(response: 0.52, dampingFraction: 0.84), value: isShowingSplash)
            .onOpenURL { url in
                Task { await authService.handleAuthCallback(url: url) }
            }
            .task {
                await splashSequence()
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch appState.authState {
        case .authenticated:
            AppShellView(appState: appState)
        case .guest:
            AuthFlowView(viewModel: authViewModel)
                .transition(.opacity)
        }
    }

    @MainActor
    private func splashSequence() async {
        guard isShowingSplash else { return }
        try? await Task.sleep(for: .milliseconds(950))
        withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
            isShowingSplash = false
        }
    }
}

/// Resolves which `AuthService` to use at launch. If `SUPABASE_URL` /
/// `SUPABASE_ANON_KEY` are present we use the real `SupabaseAuthService`;
/// otherwise we fall back to `MockAuthService` so debug builds work
/// without backend wiring.
enum SwingPalAuthServiceFactory {
    @MainActor
    static func make() -> AuthService {
        guard let config = SupabaseConfig.loadFromEnvironment() else {
            return MockAuthService()
        }
        return SupabaseAuthService(config: config)
    }
}

private struct SwingPalSplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showMark = false

    private var backgroundBase: Color {
        colorScheme == .dark
            ? Color(red: 0.05, green: 0.08, blue: 0.07)
            : Color(red: 0.95, green: 0.96, blue: 0.92)
    }

    private var backgroundGlowTop: Color {
        colorScheme == .dark
            ? Color(red: 0.18, green: 0.30, blue: 0.22).opacity(0.52)
            : Color(red: 0.84, green: 0.92, blue: 0.80).opacity(0.78)
    }

    private var backgroundGlowBottom: Color {
        colorScheme == .dark
            ? Color(red: 0.10, green: 0.15, blue: 0.13).opacity(0.72)
            : Color(red: 0.97, green: 0.95, blue: 0.89).opacity(0.66)
    }

    private var primaryText: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.96)
            : ShellTokens.ColorRole.textPrimary
    }

    private var secondaryText: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.78)
            : ShellTokens.ColorRole.textSecondary
    }

    private var cardTint: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white.opacity(0.52)
    }

    private var cardBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color.white.opacity(0.42)
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: ShellTokens.Spacing.x24) {
                Group {
                    if colorScheme == .dark {
                        // Same pre-rendered asset as `LaunchScreen.storyboard` (reliable on all devices).
                        Image("LaunchScreenIcon")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 38, style: .continuous)
                                .fill(cardTint)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                                        .stroke(cardBorder, lineWidth: 1)
                                }
                                .frame(width: 164, height: 164)
                                .shadow(color: Color.black.opacity(0.10), radius: 18, y: 10)

                            SwingPalLaunchLogoView(size: 124)
                        }
                    }
                }
                .scaleEffect(showMark ? 1.0 : 0.92)

                VStack(spacing: ShellTokens.Spacing.x10) {
                    Text("SwingPal")
                        .font(ShellTokens.Typography.mastheadTitle)
                        .foregroundStyle(primaryText)

                    Text("Power Up your golf game")
                        .font(ShellTokens.Typography.lead)
                        .foregroundStyle(secondaryText)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, ShellTokens.Spacing.x24)
                .opacity(showMark ? 1.0 : 0.0)
                .offset(y: showMark ? 0 : 10)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                showMark = true
            }
        }
    }

    private var background: some View {
        ZStack {
            backgroundBase

            LinearGradient(
                colors: [
                    backgroundGlowTop,
                    backgroundBase,
                    backgroundGlowBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(ShellTokens.ColorRole.pine500.opacity(colorScheme == .dark ? 0.16 : 0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 42)
                .offset(x: 156, y: -176)

            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.03 : 0.22))
                .frame(width: 240, height: 240)
                .blur(radius: 36)
                .offset(x: -142, y: 188)
        }
    }
}
