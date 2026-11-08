import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    enum Mode: Equatable {
        case signIn
        case signUp
    }

    enum Step: Equatable {
        case entry
        case email(Mode)
        case magicLink
        case forgotPassword
        case magicLinkSent(email: String)
        case passwordResetSent(email: String)
        /// The account exists but the address isn't confirmed yet.
        case confirmEmail(email: String)
    }

    /// Apple and Google sign-in stay hidden until their OAuth providers are
    /// set up in Supabase.
    static let showsSocialSignIn = false

    @Published var step: Step = .entry
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var displayName: String = ""
    @Published var isBusy: Bool = false
    @Published var errorMessage: String?
    /// A short confirmation shown on the confirm-email step (e.g. "sent again").
    @Published var noticeMessage: String?

    private let authService: AuthService
    private let appleCoordinatorFactory: () -> AppleSignInCoordinator
    /// The request the screen is waiting on, so closing the sheet can stop it.
    private var inFlight: Task<Void, Never>?

    init(
        authService: AuthService,
        appleCoordinatorFactory: @escaping () -> AppleSignInCoordinator
    ) {
        self.authService = authService
        self.appleCoordinatorFactory = appleCoordinatorFactory
    }

    var canSubmitEmail: Bool {
        guard isValidEmail(email), !password.isEmpty else { return false }
        return password.count >= 6
    }

    var canSubmitMagicLink: Bool {
        isValidEmail(email)
    }

    var canSubmitForgotPassword: Bool {
        isValidEmail(email)
    }

    func goTo(_ next: Step) {
        errorMessage = nil
        noticeMessage = nil
        step = next
    }

    /// Starts a request from a button. Only one runs at a time.
    func launch(_ work: @escaping @MainActor (AuthViewModel) async -> Void) {
        inFlight?.cancel()
        inFlight = Task { [weak self] in
            guard let self else { return }
            await work(self)
        }
    }

    /// The sheet is closing: stop waiting on whatever was in flight so it
    /// can't land on a screen nobody's looking at.
    func cancelInFlight() {
        inFlight?.cancel()
        inFlight = nil
        isBusy = false
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func submitEmail() async {
        guard canSubmitEmail else { return }
        let mode: Mode
        if case .email(let m) = step { mode = m } else { return }
        let address = trimmedEmail

        await run {
            switch mode {
            case .signIn:
                do {
                    try await self.authService.signIn(email: address, password: self.password)
                } catch AuthServiceError.emailNotConfirmed {
                    self.step = .confirmEmail(email: address)
                }
            case .signUp:
                let name = self.displayName.trimmingCharacters(in: .whitespaces)
                do {
                    let outcome = try await self.authService.signUp(
                        email: address,
                        password: self.password,
                        displayName: name.isEmpty ? nil : name
                    )
                    if outcome == .confirmationRequired {
                        self.step = .confirmEmail(email: address)
                    }
                } catch AuthServiceError.emailAlreadyRegistered {
                    self.step = .email(.signIn)
                    throw AuthServiceError.underlying("You already have an account with that email. Sign in instead.")
                }
            }
        }
    }

    /// From the confirm-email step: they've tapped the link (perhaps on
    /// another device), so try signing in with what they typed.
    func signInAfterConfirming() async {
        guard case .confirmEmail(let address) = step else { return }
        guard !password.isEmpty else {
            goTo(.email(.signIn))
            return
        }
        await run {
            do {
                try await self.authService.signIn(email: address, password: self.password)
            } catch AuthServiceError.emailNotConfirmed {
                throw AuthServiceError.underlying("Not confirmed yet. Tap the link in the email first, then try again.")
            }
        }
    }

    func resendConfirmation() async {
        guard case .confirmEmail(let address) = step else { return }
        await run {
            try await self.authService.resendConfirmation(email: address)
            self.noticeMessage = "Sent again to \(address). It can take a minute to arrive."
        }
    }

    func submitMagicLink() async {
        guard canSubmitMagicLink else { return }
        let trimmed = trimmedEmail
        await run {
            try await self.authService.sendMagicLink(email: trimmed)
            await MainActor.run {
                self.step = .magicLinkSent(email: trimmed)
            }
        }
    }

    func submitForgotPassword() async {
        guard canSubmitForgotPassword else { return }
        let trimmed = trimmedEmail
        await run {
            try await self.authService.sendPasswordReset(email: trimmed)
            await MainActor.run {
                self.step = .passwordResetSent(email: trimmed)
            }
        }
    }

    func signInWithApple() async {
        await run {
            let coordinator = self.appleCoordinatorFactory()
            let credential = try await coordinator.startSignIn()
            try await self.authService.signInWithIDToken(
                provider: .apple,
                idToken: credential.idToken,
                nonce: credential.rawNonce
            )
        }
    }

    func signInWithGoogle() async {
        await run {
            try await self.authService.signInWithHostedOAuth(provider: .google)
        }
    }

    private func run(_ work: @escaping @MainActor () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        noticeMessage = nil
        defer { isBusy = false }
        do {
            try await work()
        } catch {
            // Closed mid-request: nothing to tell anyone.
            if Task.isCancelled { return }
            if error is CancellationError {
                errorMessage = AuthServiceError.userCancelled.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains(".") else { return false }
        return trimmed.count >= 5
    }
}
