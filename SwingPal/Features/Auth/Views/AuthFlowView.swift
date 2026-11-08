import SwiftUI
import AuthenticationServices

/// Full-screen auth flow shown when the user is signed out: the front page
/// of the book, with the mark, ruled lines to write on and the stamp.
struct AuthFlowView: View {
    @StateObject var viewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView {
                VStack(spacing: 28) {
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
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 32)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(Book.ink)
        .tint(Book.stamp)
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: viewModel.step)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        Book.paper.ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            SwingPalMarkTile(size: 84)

            VStack(spacing: 6) {
                Text(headerTitle)
                    .font(Book.Typeface.display)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Book.pencil)
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
            VStack(spacing: 10) {
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
            .frame(height: 56)
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
                Text("Continue with Google")
            }
        }
        .buttonStyle(BookStampButtonStyle(prominent: false))
        .opacity(viewModel.isBusy ? 0.6 : 1.0)
        .disabled(viewModel.isBusy)
    }

    private var divider: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Book.rule).frame(height: 1)
            BookNote("or")
            Rectangle().fill(Book.rule).frame(height: 1)
        }
        .padding(.vertical, 6)
        .accessibilityHidden(true)
    }

    // MARK: - Email step

    @ViewBuilder
    private func emailStep(mode: AuthViewModel.Mode) -> some View {
        cardContainer {
            VStack(spacing: 18) {
                if mode == .signUp {
                    fieldRow("Name") {
                        TextField("Display name (optional)", text: $viewModel.displayName)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                    }
                }
                fieldRow("Email") {
                    TextField("Your email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(mode == .signUp ? .username : .emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                fieldRow("Password") {
                    SecureField(mode == .signUp ? "Choose a password" : "Your password", text: $viewModel.password)
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
                    .foregroundStyle(Book.stamp)
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
            VStack(spacing: 18) {
                fieldRow("Email") {
                    TextField("Your email", text: $viewModel.email)
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
                    .foregroundStyle(Book.stamp)
            }
        }
    }

    // MARK: - Forgot password

    private var forgotPasswordStep: some View {
        cardContainer {
            VStack(spacing: 18) {
                fieldRow("Email") {
                    TextField("Your email", text: $viewModel.email)
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
                    .foregroundStyle(Book.stamp)
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
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "envelope")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Book.stamp)
                Text(title)
                    .font(Book.Typeface.heading)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Book.pencil)
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

    /// The step's content, written straight on the page.
    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .frame(maxWidth: .infinity)
    }

    /// A labelled line to write on.
    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            BookNote(label)
            content()
                .font(.body)
                .bookRuledField()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    ProgressView().tint(style == .primary ? Book.onStamp : Book.ink)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(BookStampButtonStyle(prominent: style == .primary))
        .opacity(isLoading ? 0.8 : 1.0)
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
                .foregroundStyle(Book.pencil)
            Button(actionTitle, action: action)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Book.stamp)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Book.warning)
            Text(message)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Book.leaf, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Book.warning.opacity(0.6), lineWidth: 1)
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
                    .foregroundStyle(Book.ink)
                    .frame(width: 44, height: 44)
                    .background(Book.leaf, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Book.rule, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            .padding(.leading, 20)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
