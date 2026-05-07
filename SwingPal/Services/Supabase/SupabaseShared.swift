import Foundation
import Supabase

/// Holds the single `SupabaseClient` used by auth **and** Storage/database callers so every
/// subsystem shares one session (JWT refresh, cookies, etc.).
enum SupabaseShared {
    private static let lock = NSLock()
    private static var _client: SupabaseClient?

    static func setClient(_ client: SupabaseClient?) {
        lock.lock()
        defer { lock.unlock() }
        _client = client
    }

    static func client() -> SupabaseClient? {
        lock.lock()
        defer { lock.unlock() }
        return _client
    }
}
