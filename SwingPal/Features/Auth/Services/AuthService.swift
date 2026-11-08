import Foundation
import Combine

/// Lightweight description of the currently signed-in user. Avoids leaking
/// Supabase types into the rest of the app, so views/view-models can be
/// unit-tested with a fake.
struct AuthSessionUser: Equatable, Hashable {
    let id: String
    let email: String?
    let displayName: String?

    init(id: String, email: String? = nil, displayName: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
    }
}

/// Identity-provider tag used by `AuthService.signInWithIDToken(provider:...)`.
enum AuthOAuthProvider: String, Equatable {
    case apple
    case google
}

/// Errors surfaced to the UI. We keep them coarse on purpose: views
/// should render `localizedDescription` and not branch on cause.
enum AuthServiceError: LocalizedError, Equatable {
    case invalidCredentials
    case emailAlreadyRegistered
    case userNotFound
    case rateLimited
    case missingConfiguration
    case userCancelled
    case network(String)
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Email or password is incorrect."
        case .emailAlreadyRegistered:
            return "An account with that email already exists."
        case .userNotFound:
            return "We couldn't find an account for that email."
        case .rateLimited:
            return "Too many attempts. Please wait a moment and try again."
        case .missingConfiguration:
            return "Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY to Info.plist."
        case .userCancelled:
            return "Sign-in was cancelled."
        case .network(let detail):
            return "Network error: \(detail)"
        case .underlying(let detail):
            return detail
        }
    }
}

/// Application-facing auth surface. Concrete implementations live in
/// `Services/Auth/SupabaseAuthService.swift` (real) and the in-memory
/// `MockAuthService` used by previews + tests.
@MainActor
protocol AuthService: AnyObject {
    /// Hot stream — emits the current session user (or `nil`) and every
    /// subsequent change (sign-in / sign-out / token refresh).
    var sessionUserPublisher: AnyPublisher<AuthSessionUser?, Never> { get }

    /// Last known session, available synchronously for first paint.
    var currentSessionUser: AuthSessionUser? { get }

    /// Restores any persisted session (e.g. on cold launch). Idempotent.
    func bootstrap() async

    func signUp(email: String, password: String, displayName: String?) async throws
    func signIn(email: String, password: String) async throws
    func sendMagicLink(email: String) async throws
    func sendPasswordReset(email: String) async throws

    /// Apple/Google sign-in. The caller is responsible for kicking off the
    /// platform flow (ASAuthorizationController for Apple, hosted OAuth
    /// for Google) and supplying the resulting identity token + nonce.
    /// `nonce` may be `nil` for Google.
    func signInWithIDToken(provider: AuthOAuthProvider, idToken: String, nonce: String?) async throws

    /// Convenience for Google specifically: kicks off the hosted OAuth
    /// flow via `ASWebAuthenticationSession`. Implementations that want
    /// to handle Google natively can return `nil` and let the caller
    /// drive `signInWithIDToken(provider: .google, ...)` instead.
    func signInWithHostedOAuth(provider: AuthOAuthProvider) async throws

    func signOut() async throws

    /// Magic-link + OAuth flows finish with a `swingpal://…` callback; forward
    /// it from `App.onOpenURL`.
    func handleAuthCallback(url: URL) async
}
