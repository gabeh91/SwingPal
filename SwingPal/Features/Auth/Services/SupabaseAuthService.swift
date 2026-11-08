import Combine
import Foundation
import Supabase

/// Production auth backed by Supabase Auth + PKCE-friendly OAuth on iOS.
@MainActor
final class SupabaseAuthService: AuthService {
    private let client: SupabaseClient
    private let subject = CurrentValueSubject<AuthSessionUser?, Never>(nil)
    private var authChangesTask: Task<Void, Never>?

    init(client: SupabaseClient) {
        self.client = client

        authChangesTask = Task { [weak self] in
            guard let self else { return }
            for await (_, session) in await self.client.auth.authStateChanges {
                if let session {
                    self.subject.send(Self.mapUser(session.user))
                } else {
                    self.subject.send(nil)
                }
            }
        }
    }

    deinit {
        authChangesTask?.cancel()
    }

    var sessionUserPublisher: AnyPublisher<AuthSessionUser?, Never> {
        subject.eraseToAnyPublisher()
    }

    var currentSessionUser: AuthSessionUser? { subject.value }

    func bootstrap() async {
        do {
            let session = try await client.auth.session
            subject.send(Self.mapUser(session.user))
        } catch {
            subject.send(nil)
        }
    }

    func signUp(email: String, password: String, displayName: String?) async throws {
        var data: [String: AnyJSON]?
        if let displayName, !displayName.trimmingCharacters(in: .whitespaces).isEmpty {
            data = ["display_name": .string(displayName.trimmingCharacters(in: .whitespaces))]
        }
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: data
        )
        if let session = response.session {
            subject.send(Self.mapUser(session.user))
        }
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        subject.send(Self.mapUser(session.user))
    }

    func sendMagicLink(email: String) async throws {
        try await client.auth.signInWithOTP(email: email)
    }

    func sendPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    func signInWithIDToken(provider: AuthOAuthProvider, idToken: String, nonce: String?) async throws {
        let credentials = OpenIDConnectCredentials(
            provider: provider == .apple ? .apple : .google,
            idToken: idToken,
            nonce: nonce
        )
        let session = try await client.auth.signInWithIdToken(credentials: credentials)
        subject.send(Self.mapUser(session.user))
    }

    func signInWithHostedOAuth(provider: AuthOAuthProvider) async throws {
        guard provider == .google else {
            throw AuthServiceError.underlying("Hosted OAuth is only used for Google sign-in.")
        }
        let session = try await client.auth.signInWithOAuth(provider: .google)
        subject.send(Self.mapUser(session.user))
    }

    func signOut() async throws {
        try await client.auth.signOut()
        subject.send(nil)
    }

    func handleAuthCallback(url: URL) async {
        do {
            let session = try await client.auth.session(from: url)
            subject.send(Self.mapUser(session.user))
        } catch {
            subject.send(nil)
        }
    }

    private static func mapUser(_ user: User) -> AuthSessionUser {
        let fromMeta = metadataString(user.userMetadata["display_name"])
            ?? metadataString(user.userMetadata["full_name"])
        let displayName = fromMeta ?? user.email
        return AuthSessionUser(
            id: user.id.uuidString,
            email: user.email,
            displayName: displayName
        )
    }

    /// `AnyJSON` decoding differs across Supabase releases — extract plain strings safely.
    private static func metadataString(_ value: AnyJSON?) -> String? {
        guard let value else { return nil }
        if case let .string(s) = value {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
}
