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
    }

    @Published var step: Step = .entry
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var displayName: String = ""
    @Published var isBusy: Bool = false
    @Published var errorMessage: String?

    private let authService: AuthService
    private let appleCoordinatorFactory: () -> AppleSignInCoordinator

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
        step = next
    }

    func submitEmail() async {
        guard canSubmitEmail else { return }
        let mode: Mode
        if case .email(let m) = step { mode = m } else { return }

        await run {
            switch mode {
            case .signIn:
                try await self.authService.signIn(email: self.email, password: self.password)
            case .signUp:
                try await self.authService.signUp(
                    email: self.email,
                    password: self.password,
                    displayName: self.displayName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? nil
                        : self.displayName.trimmingCharacters(in: .whitespaces)
                )
            }
        }
    }

    func submitMagicLink() async {
        guard canSubmitMagicLink else { return }
        let trimmed = email
        await run {
            try await self.authService.sendMagicLink(email: trimmed)
            await MainActor.run {
                self.step = .magicLinkSent(email: trimmed)
            }
        }
    }

    func submitForgotPassword() async {
        guard canSubmitForgotPassword else { return }
        let trimmed = email
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

    private func run(_ work: @escaping () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await work()
        } catch let error as AuthServiceError {
            errorMessage = error.localizedDescription
        } catch is CancellationError {
            errorMessage = AuthServiceError.userCancelled.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains(".") else { return false }
        return trimmed.count >= 5
    }
}
