import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Wraps `ASAuthorizationController` in an `async` API that returns the
/// (idToken, rawNonce) tuple our `AuthService` consumes for
/// `signInWithIDToken(provider: .apple, ...)`.
///
/// The raw nonce is what the *backend* (Supabase) verifies; the SHA-256
/// of the raw nonce is what we hand to Apple's request as `nonce`.
@MainActor
final class AppleSignInCoordinator: NSObject {
    struct AppleCredential: Equatable {
        let idToken: String
        let rawNonce: String
        let displayName: String?
        let email: String?
    }

    private var continuation: CheckedContinuation<AppleCredential, Error>?
    private var currentNonce: String?

    func startSignIn() async throws -> AppleCredential {
        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppleCredential, Error>) in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Failed to generate nonce: \(status)")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AuthServiceError.underlying("Apple credential missing."))
            continuation = nil
            return
        }

        guard let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            continuation?.resume(throwing: AuthServiceError.underlying("Apple identity token missing."))
            continuation = nil
            return
        }

        guard let rawNonce = currentNonce else {
            continuation?.resume(throwing: AuthServiceError.underlying("Apple sign-in nonce missing."))
            continuation = nil
            return
        }

        let formatter = PersonNameComponentsFormatter()
        let displayName: String? = credential.fullName.flatMap { components in
            let value = formatter.string(from: components).trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }

        let result = AppleCredential(
            idToken: token,
            rawNonce: rawNonce,
            displayName: displayName,
            email: credential.email
        )
        continuation?.resume(returning: result)
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let asError = error as? ASAuthorizationError {
            switch asError.code {
            case .canceled:
                continuation?.resume(throwing: AuthServiceError.userCancelled)
            default:
                continuation?.resume(throwing: AuthServiceError.underlying(asError.localizedDescription))
            }
        } else {
            continuation?.resume(throwing: AuthServiceError.underlying(error.localizedDescription))
        }
        continuation = nil
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        guard let windowScene = scenes.compactMap({ $0 as? UIWindowScene }).first else {
            return ASPresentationAnchor()
        }
        return windowScene.keyWindow
            ?? windowScene.windows.first(where: \.isKeyWindow)
            ?? windowScene.windows.first
            ?? ASPresentationAnchor()
    }
}
