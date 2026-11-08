import Foundation

/// Parses follow targets from app URLs, https links, or plain UUID strings (e.g. NFC text).
enum FollowDeepLink {
    /// `swingpal://follow/<uuid>`
    static func userId(from url: URL) -> UUID? {
        guard let scheme = url.scheme?.lowercased() else {
            return nil
        }

        if scheme == "swingpal" {
            if url.host?.lowercased() == "follow" {
                let segment = url.path.split(separator: "/").map(String.init).first { !$0.isEmpty }
                if let segment, let id = UUID(uuidString: segment) {
                    return id
                }
            }
            return nil
        }

        if scheme == "https" || scheme == "http" {
            return userId(fromHTTPSURL: url)
        }

        return nil
    }

    static func userId(fromPlainText string: String) -> UUID? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id = UUID(uuidString: trimmed) {
            return id
        }
        if let url = URL(string: trimmed), let id = userId(from: url) {
            return id
        }
        // Last segment path match .../follow/<uuid>
        if let range = trimmed.range(of: "/follow/", options: .backwards),
           let tail = Optional(trimmed[range.upperBound...]),
           let id = UUID(uuidString: String(tail).trimmingCharacters(in: CharacterSet(charactersIn: "/"))) {
            return id
        }
        return nil
    }

    private static func userId(fromHTTPSURL url: URL) -> UUID? {
        let parts = url.path.split(separator: "/").map(String.init)
        if let idx = parts.firstIndex(of: "follow"), idx + 1 < parts.count {
            return UUID(uuidString: parts[idx + 1])
        }
        return nil
    }
}
