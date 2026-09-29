import Foundation
import OSLog

/// Runs Overpass queries against the public instances, in order, until one
/// returns real data.
///
/// The public servers are shared and often busy. When they are, they answer
/// with HTTP 429/504, with an XML or HTML error page, or with HTTP 200 and a
/// JSON `remark` such as "runtime error: Query timed out". All of those are
/// treated as "try again / try the next server" here, so a busy server never
/// reaches the converter as an "unreadable" course.
struct OverpassClient {
    static let endpoints: [URL] = [
        URL(string: "https://overpass-api.de/api/interpreter")!,
        URL(string: "https://overpass.kumi.systems/api/interpreter")!,
        URL(string: "https://overpass.private.coffee/api/interpreter")!
    ]

    private static let logger = Logger(subsystem: "com.swingpal.app", category: "Overpass")

    var session: URLSession = .shared
    var endpoints: [URL] = OverpassClient.endpoints
    /// Attempts per endpoint before moving on.
    var attemptsPerEndpoint = 2
    /// Pause before retrying the same endpoint (doubles each retry).
    var retryDelay: Duration = .seconds(1.5)

    /// Returns the raw JSON body of the first successful answer.
    func run(_ query: String) async throws -> Data {
        var lastError: OSMCourseDiscoveryError = .networkUnavailable
        for endpoint in endpoints {
            var delay = retryDelay
            for attempt in 1...max(attemptsPerEndpoint, 1) {
                try Task.checkCancellation()
                do {
                    return try await send(query, to: endpoint)
                } catch let error as OSMCourseDiscoveryError {
                    lastError = error
                    Self.logger.info("Overpass \(endpoint.host() ?? "?", privacy: .public) attempt \(attempt) failed: \(String(describing: error), privacy: .public)")
                    // Retry the same server after a pause; then fall through to the next.
                    if attempt < attemptsPerEndpoint {
                        try await Task.sleep(for: delay)
                        delay = delay * 2
                    }
                }
            }
        }
        throw lastError
    }

    private func send(_ query: String, to endpoint: URL) async throws -> Data {
        var request = URLRequest(url: endpoint, timeoutInterval: 75)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(LiveOSMCourseDiscovery.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = Self.formBody(for: query)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw OSMCourseDiscoveryError.networkUnavailable
        }

        guard let http = response as? HTTPURLResponse else {
            throw OSMCourseDiscoveryError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300:
            break
        case 429, 502, 503, 504:
            throw OSMCourseDiscoveryError.rateLimited
        default:
            throw OSMCourseDiscoveryError.invalidResponse
        }
        try Self.checkPayload(data)
        return data
    }

    /// `application/x-www-form-urlencoded` body. `.urlQueryAllowed` leaves
    /// `+`, `&` and `=` unescaped, which corrupts queries containing them.
    static func formBody(for query: String) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return Data("data=\(encoded)".utf8)
    }

    /// Throws when a 200 response isn't usable JSON data: an XML/HTML error
    /// page, or JSON whose `remark` reports a runtime error or timeout.
    static func checkPayload(_ data: Data) throws {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["elements"] is [Any]
        else {
            throw OSMCourseDiscoveryError.rateLimited
        }
        if let remark = object["remark"] as? String {
            let lowered = remark.lowercased()
            if lowered.contains("runtime error") || lowered.contains("timed out") || lowered.contains("out of memory") {
                throw OSMCourseDiscoveryError.rateLimited
            }
        }
    }
}
