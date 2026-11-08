import Foundation
import Combine

/// In-memory `AuthService` used by previews + unit tests. Mirrors the
/// shape of a Supabase response well enough to drive the auth UI flows
/// without a network. Always succeeds (or throws a configurable error).
@MainActor
final class MockAuthService: AuthService {
    enum Behaviour {
        case alwaysSucceed
        case alwaysFail(AuthServiceError)
    }

    var behaviour: Behaviour = .alwaysSucceed

    private let subject: CurrentValueSubject<AuthSessionUser?, Never>

    init(initialUser: AuthSessionUser? = nil) {
        self.subject = CurrentValueSubject<AuthSessionUser?, Never>(initialUser)
    }

    var sessionUserPublisher: AnyPublisher<AuthSessionUser?, Never> {
        subject.eraseToAnyPublisher()
    }

    var currentSessionUser: AuthSessionUser? { subject.value }

    func bootstrap() async {
        // No-op; mock just trusts the value passed in `init`.
    }

    /// When true, sign-up behaves like Supabase with email confirmation on:
    /// the account is made but nobody is signed in.
    var requiresEmailConfirmation = false
    /// Accounts that exist but haven't been confirmed; signing in to one fails.
    var unconfirmedEmails: Set<String> = []
    /// Makes sign-up and sign-in take a while, to exercise closing mid-request.
    var responseDelay: Duration = .zero
    private(set) var resentConfirmations: [String] = []

    @discardableResult
    func signUp(email: String, password: String, displayName: String?) async throws -> AuthSignUpOutcome {
        try await wait()
        try checkBehaviour()
        if requiresEmailConfirmation {
            unconfirmedEmails.insert(email)
            return .confirmationRequired
        }
        let user = AuthSessionUser(
            id: UUID().uuidString,
            email: email,
            displayName: displayName ?? Self.fallbackDisplayName(for: email)
        )
        subject.send(user)
        return .signedIn
    }

    func resendConfirmation(email: String) async throws {
        try checkBehaviour()
        resentConfirmations.append(email)
    }

    func signIn(email: String, password: String) async throws {
        try await wait()
        try checkBehaviour()
        if unconfirmedEmails.contains(email) {
            throw AuthServiceError.emailNotConfirmed
        }
        let user = AuthSessionUser(
            id: UUID().uuidString,
            email: email,
            displayName: Self.fallbackDisplayName(for: email)
        )
        subject.send(user)
    }

    func sendMagicLink(email: String) async throws {
        try checkBehaviour()
    }

    func sendPasswordReset(email: String) async throws {
        try checkBehaviour()
    }

    func signInWithIDToken(provider: AuthOAuthProvider, idToken: String, nonce: String?) async throws {
        try checkBehaviour()
        let user = AuthSessionUser(
            id: UUID().uuidString,
            email: nil,
            displayName: provider == .apple ? "Apple Player" : "Google Player"
        )
        subject.send(user)
    }

    func signInWithHostedOAuth(provider: AuthOAuthProvider) async throws {
        try checkBehaviour()
        let user = AuthSessionUser(
            id: UUID().uuidString,
            email: nil,
            displayName: provider == .apple ? "Apple Player" : "Google Player"
        )
        subject.send(user)
    }

    func signOut() async throws {
        subject.send(nil)
    }

    func handleAuthCallback(url: URL) async {
        _ = url
    }

    private func wait() async throws {
        if responseDelay > .zero {
            try await Task.sleep(for: responseDelay)
        }
    }

    private func checkBehaviour() throws {
        switch behaviour {
        case .alwaysSucceed:
            return
        case .alwaysFail(let error):
            throw error
        }
    }

    private static func fallbackDisplayName(for email: String) -> String {
        email.split(separator: "@").first.map(String.init) ?? email
    }
}

/// App-runtime fallback used when auth configuration is missing. Unlike
/// `MockAuthService`, this must never silently authenticate a user.
@MainActor
final class MissingConfigurationAuthService: AuthService {
    private let subject = CurrentValueSubject<AuthSessionUser?, Never>(nil)

    var sessionUserPublisher: AnyPublisher<AuthSessionUser?, Never> {
        subject.eraseToAnyPublisher()
    }

    var currentSessionUser: AuthSessionUser? { nil }

    func bootstrap() async {}

    func signUp(email: String, password: String, displayName: String?) async throws -> AuthSignUpOutcome {
        _ = (email, password, displayName)
        throw AuthServiceError.missingConfiguration
    }

    func resendConfirmation(email: String) async throws {
        _ = email
        throw AuthServiceError.missingConfiguration
    }

    func signIn(email: String, password: String) async throws {
        _ = (email, password)
        throw AuthServiceError.missingConfiguration
    }

    func sendMagicLink(email: String) async throws {
        _ = email
        throw AuthServiceError.missingConfiguration
    }

    func sendPasswordReset(email: String) async throws {
        _ = email
        throw AuthServiceError.missingConfiguration
    }

    func signInWithIDToken(provider: AuthOAuthProvider, idToken: String, nonce: String?) async throws {
        _ = (provider, idToken, nonce)
        throw AuthServiceError.missingConfiguration
    }

    func signInWithHostedOAuth(provider: AuthOAuthProvider) async throws {
        _ = provider
        throw AuthServiceError.missingConfiguration
    }

    func signOut() async throws {}

    func handleAuthCallback(url: URL) async {
        _ = url
    }
}
