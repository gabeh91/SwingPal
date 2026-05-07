import SwiftUI
import AuthenticationServices

/// Full-screen auth flow shown when the user is signed out. Wraps the
/// existing AppShell visual language (pine palette, splash gradient)
/// so it feels of a piece with the launch screen.
struct AuthFlowView: View {
    @StateObject var viewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var palette: AuthPalette { AuthPalette.forColorScheme(colorScheme) }

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView {
                VStack(spacing: ShellTokens.Spacing.x24) {
                    header

                    Group {
                        switch viewModel.step {
                        case .entry:
                            entryStep
                        case .email(let mode):
                            emailStep(mode: mode)
                        case .magicLink:
                            magicLinkStep
                        case .forgotPassword:
                            forgotPasswordStep
                        case .magicLinkSent(let email):
                            confirmationStep(
                                title: "Check your inbox",
                                detail: "We sent a magic link to **\(email)**. Tap it from this device to finish signing in.",
                                buttonTitle: "Back",
                                buttonAction: { viewModel.goTo(.entry) }
                            )
                        case .passwordResetSent(let email):
                            confirmationStep(
                                title: "Reset link sent",
                                detail: "If an account exists for **\(email)** we just emailed a password-reset link.",
                                buttonTitle: "Back to sign in",
                                buttonAction: { viewModel.goTo(.email(.signIn)) }
                            )
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }
                }
                .padding(.horizontal, ShellTokens.Spacing.x24)
                .padding(.top, ShellTokens.Spacing.x40)
                .padding(.bottom, ShellTokens.Spacing.x32)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: viewModel.step)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            palette.backgroundBase
            LinearGradient(
                colors: [palette.glowTop, palette.backgroundBase, palette.glowBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(ShellTokens.ColorRole.pine500.opacity(colorScheme == .dark ? 0.16 : 0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 42)
                .offset(x: 156, y: -176)

            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.04 : 0.22))
                .frame(width: 240, height: 240)
                .blur(radius: 36)
                .offset(x: -142, y: 188)
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ShellTokens.Spacing.x12) {
            SwingPalLaunchLogoView(size: 84)

            VStack(spacing: 6) {
                Text(headerTitle)
                    .font(ShellTokens.Typography.stageTitle)
                    .foregroundStyle(palette.primaryText)
                    .multilineTextAlignment(.center)
                Text(headerSubtitle)
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
    }

    private var headerTitle: String {
        switch viewModel.step {
        case .entry: return "Welcome to SwingPal"
        case .email(.signIn): return "Sign in"
        case .email(.signUp): return "Create your account"
        case .magicLink: return "Magic link sign-in"
        case .forgotPassword: return "Reset your password"
        case .magicLinkSent: return "Almost there"
        case .passwordResetSent: return "Check your email"
        }
    }

    private var headerSubtitle: String {
        switch viewModel.step {
        case .entry:
            return "Sign in to save rounds, sync your bag, and connect with your golf circle."
        case .email(.signIn):
            return "Use the email and password you signed up with."
        case .email(.signUp):
            return "Create an account to save your rounds and follow friends."
        case .magicLink:
            return "We'll email you a one-tap link — no password needed."
        case .forgotPassword:
            return "Enter your account email and we'll send a reset link."
        case .magicLinkSent, .passwordResetSent:
            return "You can close this screen and tap the link from your inbox."
        }
    }

    // MARK: - Entry step (provider buttons)

    private var entryStep: some View {
        cardContainer {
            VStack(spacing: ShellTokens.Spacing.x12) {
                appleButton
                googleButton
                divider
                primaryButton(
                    title: "Sign in with email",
                    systemImage: "envelope.fill",
                    style: .primary
                ) {
                    viewModel.goTo(.email(.signIn))
                }
                secondaryButton(
                    title: "Email me a magic link",
                    systemImage: "link"
                ) {
                    viewModel.goTo(.magicLink)
                }
                secondaryButton(
                    title: "Create new account",
                    systemImage: "person.crop.circle.badge.plus"
                ) {
                    viewModel.goTo(.email(.signUp))
                }
            }
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn, onRequest: { _ in }, onCompletion: { _ in })
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .allowsHitTesting(false)
            .overlay {
                Button {
                    Task { await viewModel.signInWithApple() }
                } label: {
                    Color.clear
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sign in with Apple")
            }
            .opacity(viewModel.isBusy ? 0.6 : 1.0)
            .disabled(viewModel.isBusy)
    }

    private var googleButton: some View {
        Button {
            Task { await viewModel.signInWithGoogle() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "g.circle.fill")
                    .font(.title3.weight(.semibold))
                Text("Continue with Google")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(palette.primaryText)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .opacity(viewModel.isBusy ? 0.6 : 1.0)
        .disabled(viewModel.isBusy)
    }

    private var divider: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundStyle(palette.border.opacity(0.7))
            Text("OR").font(.caption.weight(.semibold)).foregroundStyle(palette.tertiaryText)
            Rectangle().frame(height: 1).foregroundStyle(palette.border.opacity(0.7))
        }
    }

    // MARK: - Email step

    @ViewBuilder
    private func emailStep(mode: AuthViewModel.Mode) -> some View {
        cardContainer {
            VStack(spacing: ShellTokens.Spacing.x12) {
                if mode == .signUp {
                    fieldRow {
                        TextField("Display name (optional)", text: $viewModel.displayName)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                    }
                }
                fieldRow {
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(mode == .signUp ? .username : .emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                fieldRow {
                    SecureField(mode == .signUp ? "Choose a password" : "Password", text: $viewModel.password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                }

                primaryButton(
                    title: mode == .signUp ? "Create account" : "Sign in",
                    systemImage: nil,
                    style: .primary,
                    isLoading: viewModel.isBusy,
                    isEnabled: viewModel.canSubmitEmail
                ) {
                    Task { await viewModel.submitEmail() }
                }

                if mode == .signIn {
                    Button("Forgot password?") {
                        viewModel.goTo(.forgotPassword)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.accent)
                }

                bottomSwitchRow(
                    text: mode == .signIn ? "New to SwingPal?" : "Already have an account?",
                    actionTitle: mode == .signIn ? "Create account" : "Sign in",
                    action: {
                        viewModel.goTo(.email(mode == .signIn ? .signUp : .signIn))
                    }
                )
            }
        }
    }

    // MARK: - Magic link

    private var magicLinkStep: some View {
        cardContainer {
            VStack(spacing: ShellTokens.Spacing.x12) {
                fieldRow {
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                primaryButton(
                    title: "Send magic link",
                    systemImage: "paperplane.fill",
                    style: .primary,
                    isLoading: viewModel.isBusy,
                    isEnabled: viewModel.canSubmitMagicLink
                ) {
                    Task { await viewModel.submitMagicLink() }
                }
                Button("Back") { viewModel.goTo(.entry) }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.accent)
            }
        }
    }

    // MARK: - Forgot password

    private var forgotPasswordStep: some View {
        cardContainer {
            VStack(spacing: ShellTokens.Spacing.x12) {
                fieldRow {
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                primaryButton(
                    title: "Send reset link",
                    systemImage: "key.fill",
                    style: .primary,
                    isLoading: viewModel.isBusy,
                    isEnabled: viewModel.canSubmitForgotPassword
                ) {
                    Task { await viewModel.submitForgotPassword() }
                }
                Button("Back") { viewModel.goTo(.email(.signIn)) }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.accent)
            }
        }
    }

    // MARK: - Confirmation step

    private func confirmationStep(
        title: String,
        detail: LocalizedStringKey,
        buttonTitle: String,
        buttonAction: @escaping () -> Void
    ) -> some View {
        cardContainer {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                Image(systemName: "envelope.badge.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(palette.accent)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                primaryButton(
                    title: buttonTitle,
                    systemImage: nil,
                    style: .secondary,
                    action: buttonAction
                )
            }
        }
    }

    // MARK: - Primitives

    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(ShellTokens.Spacing.x20)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.cardTint)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            }
            .shadow(color: palette.shadow, radius: 18, y: 10)
    }

    private func fieldRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.body)
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            }
    }

    private enum ButtonStyleVariant { case primary, secondary }

    @ViewBuilder
    private func primaryButton(
        title: String,
        systemImage: String?,
        style: ButtonStyleVariant,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().controlSize(.regular)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(style == .primary ? Color.white : palette.primaryText)
            .background {
                let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                if style == .primary {
                    shape.fill(palette.accent)
                } else {
                    shape.fill(palette.surface)
                }
            }
            .overlay {
                if style == .secondary {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(isEnabled && !isLoading ? 1.0 : 0.55)
        .disabled(!isEnabled || isLoading)
    }

    private func secondaryButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        primaryButton(title: title, systemImage: systemImage, style: .secondary, action: action)
    }

    private func bottomSwitchRow(text: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
            Button(actionTitle, action: action)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.accent)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(palette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.red.opacity(0.30), lineWidth: 1)
        }
    }
}

struct AuthFlowModalView: View {
    let onDismiss: () -> Void

    @StateObject private var viewModel: AuthViewModel

    init(authService: AuthService, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        _viewModel = StateObject(
            wrappedValue: AuthViewModel(
                authService: authService,
                appleCoordinatorFactory: { AppleSignInCoordinator() }
            )
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AuthFlowView(viewModel: viewModel)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(width: 42, height: 42)
                    .background(Color.black.opacity(0.18), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, ShellTokens.Spacing.x20)
            .padding(.leading, ShellTokens.Spacing.x20)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct AuthPalette {
    let backgroundBase: Color
    let glowTop: Color
    let glowBottom: Color
    let cardTint: Color
    let surface: Color
    let border: Color
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    let accent: Color
    let shadow: Color

    static func forColorScheme(_ scheme: ColorScheme) -> AuthPalette {
        switch scheme {
        case .dark:
            return .init(
                backgroundBase: Color(red: 0.05, green: 0.08, blue: 0.07),
                glowTop: Color(red: 0.18, green: 0.30, blue: 0.22).opacity(0.54),
                glowBottom: Color(red: 0.10, green: 0.15, blue: 0.13).opacity(0.72),
                cardTint: Color.white.opacity(0.08),
                surface: Color.white.opacity(0.06),
                border: Color.white.opacity(0.22),
                primaryText: Color.white.opacity(0.96),
                secondaryText: Color.white.opacity(0.78),
                tertiaryText: Color.white.opacity(0.55),
                accent: ShellTokens.ColorRole.pine500,
                shadow: Color.black.opacity(0.34)
            )
        default:
            return .init(
                backgroundBase: Color(red: 0.95, green: 0.96, blue: 0.92),
                glowTop: Color(red: 0.84, green: 0.92, blue: 0.80).opacity(0.78),
                glowBottom: Color(red: 0.97, green: 0.95, blue: 0.89).opacity(0.66),
                cardTint: Color.white.opacity(0.62),
                surface: Color.white.opacity(0.92),
                border: Color.white.opacity(0.45),
                primaryText: ShellTokens.ColorRole.textPrimary,
                secondaryText: ShellTokens.ColorRole.textSecondary,
                tertiaryText: ShellTokens.ColorRole.textTertiary,
                accent: ShellTokens.ColorRole.pine700,
                shadow: Color.black.opacity(0.10)
            )
        }
    }
}
