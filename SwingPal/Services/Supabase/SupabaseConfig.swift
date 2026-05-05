import Foundation

/// URL + anon key + redirect required to talk to a Supabase project.
/// Loaded from `Info.plist` keys `SUPABASE_URL` and `SUPABASE_ANON_KEY`,
/// or — when those are absent — from environment variables of the same
/// name (helpful for unit tests + scripted previews).
struct SupabaseConfig: Equatable {
    let url: URL
    let anonKey: String
    /// Custom URL scheme the app registers in `Info.plist`. Used as the
    /// callback for hosted OAuth + email magic links.
    let redirectScheme: String
    /// Full callback URL handed to Supabase. Default: `<scheme>://auth-callback`.
    let redirectURL: URL

    init(
        url: URL,
        anonKey: String,
        redirectScheme: String = "swingpal",
        redirectURL: URL? = nil
    ) {
        self.url = url
        self.anonKey = anonKey
        self.redirectScheme = redirectScheme
        // swiftlint:disable:next force_unwrapping
        self.redirectURL = redirectURL ?? URL(string: "\(redirectScheme)://auth-callback")!
    }

    /// Reads `SupabaseConfig` from `Bundle.main.infoDictionary`, falling
    /// back to `ProcessInfo`. Returns `nil` if either key is missing or
    /// blank — which is treated as "Supabase isn't wired yet" by the rest
    /// of the app and surfaces a clear error in the auth UI.
    static func loadFromEnvironment(bundle: Bundle = .main) -> SupabaseConfig? {
        let info = bundle.infoDictionary ?? [:]
        let env = ProcessInfo.processInfo.environment

        let urlString = stringValue(forKey: "SUPABASE_URL", info: info, env: env)
        let key = stringValue(forKey: "SUPABASE_ANON_KEY", info: info, env: env)

        guard let urlString,
              let url = URL(string: urlString),
              let key,
              !key.isEmpty else {
            return nil
        }

        return SupabaseConfig(url: url, anonKey: key)
    }

    private static func stringValue(
        forKey key: String,
        info: [String: Any],
        env: [String: String]
    ) -> String? {
        if let raw = info[key] as? String, !raw.isEmpty, !raw.hasPrefix("$(") {
            return raw
        }
        if let raw = env[key], !raw.isEmpty {
            return raw
        }
        return nil
    }
}
