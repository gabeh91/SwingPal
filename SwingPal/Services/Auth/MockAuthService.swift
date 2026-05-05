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

    func signUp(email: String, password: String, displayName: String?) async throws {
        try checkBehaviour()
        let user = AuthSessionUser(
            id: UUID().uuidString,
            email: email,
            displayName: displayName ?? Self.fallbackDisplayName(for: email)
        )
        subject.send(user)
    }

    func signIn(email: String, password: String) async throws {
        try checkBehaviour()
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
