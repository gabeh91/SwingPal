import Foundation
import CoreLocation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Wire format the on-device model is asked to return. Kept tiny so the
/// JSON is robust to small phrasing drift in model output.
struct FoundationModelsCourseReviewResponse: Codable, Equatable {
    let verdict: String
    let concerns: [String]
    let oneLineSummary: String
}

protocol FoundationModelsCourseSessioning {
    func review(prompt: String) async throws -> FoundationModelsCourseReviewResponse
}

enum FoundationModelsCourseValidatorError: LocalizedError {
    case frameworkUnavailable
    case modelUnavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .frameworkUnavailable:
            return "FoundationModels is unavailable on this build."
        case .modelUnavailable:
            return "The on-device model is not currently available."
        case .invalidResponse:
            return "FoundationModels returned an invalid course-review payload."
        }
    }
}

/// Layer 2 of the validation pipeline (per the plan). Feeds a small
/// structured digest of the imported course to the on-device model and
/// turns its JSON verdict into an `AICourseReview`. This is **advisory**:
///
/// - `verdict: "broken"` is treated as a hard failure (coordinator emits
///   `.failed`).
/// - `verdict: "concerns"` keeps the import but downgrades the course to
///   `quality.provisional` and surfaces the concerns + one-line summary
///   on the loading overlay so the user can opt in.
/// - `verdict: "ok"` (with the model actually available) clears the course
///   to `quality.reviewed`.
///
/// Mirrors `FoundationModelsRoundSummaryAnalyzer`'s session pattern so we
/// inherit the same resilience: missing framework / unavailable model both
/// surface as `aiAvailable: false` and a provisional outcome.
struct FoundationModelsCourseValidator: AICourseValidating {
    private let session: any FoundationModelsCourseSessioning

    init(session: any FoundationModelsCourseSessioning = LiveFoundationModelsCourseSession()) {
        self.session = session
    }

    func review(_ course: SwingPalCourse) async -> AICourseReview {
        let summary = Self.makeStructuredSummary(for: course)
        do {
            let response = try await session.review(prompt: makePrompt(summary: summary))
            return AICourseReview(
                verdict: parseVerdict(response.verdict),
                concerns: response.concerns,
                oneLineSummary: response.oneLineSummary,
                aiAvailable: true
            )
        } catch FoundationModelsCourseValidatorError.modelUnavailable,
                FoundationModelsCourseValidatorError.frameworkUnavailable {
            return .unavailable
        } catch {
            // Treat any other failure (parse error, network outage, etc.)
            // the same as unavailable — we don't want a transient hiccup to
            // hard-block a valid course.
            return .unavailable
        }
    }

    private func parseVerdict(_ raw: String) -> AICourseReview.Verdict {
        switch raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "broken": return .broken
        case "concerns": return .concerns
        default: return .ok
        }
    }

    static func parseResponseContent(_ raw: String) throws -> FoundationModelsCourseReviewResponse {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: Substring
        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            candidate = trimmed[start...end]
        } else {
            candidate = Substring(trimmed)
        }
        guard let data = String(candidate).data(using: .utf8) else {
            throw FoundationModelsCourseValidatorError.invalidResponse
        }
        do {
            return try JSONDecoder().decode(FoundationModelsCourseReviewResponse.self, from: data)
        } catch {
            throw FoundationModelsCourseValidatorError.invalidResponse
        }
    }

    /// Compact, model-friendly digest of a course. We deliberately ship
    /// counts + percentiles rather than raw polygon geometry to keep the
    /// prompt within the model's context window and to keep the model
    /// focused on interpretive observations rather than bit-counting.
    static func makeStructuredSummary(for course: SwingPalCourse) -> CourseStructuredSummary {
        let holeCount = course.holes.count
        let totalPar = course.holes.reduce(0) { $0 + $1.par }
        let par3 = course.holes.filter { $0.par == 3 }.count
        let par4 = course.holes.filter { $0.par == 4 }.count
        let par5 = course.holes.filter { $0.par == 5 }.count

        var teeToGreenDistances: [Double] = []
        var perHoleFeatureCounts: [PerHoleFeatureCount] = []
        for hole in course.holes {
            let teeCoords = hole.features.filter { $0.kind == .tee }.flatMap(\.coordinates)
            let greenCoords = hole.features.filter { $0.kind == .green }.flatMap(\.coordinates)
            if let teeCentroid = RuntimeOSMCourseConverter.centroid(of: teeCoords),
               let greenCentroid = RuntimeOSMCourseConverter.centroid(of: greenCoords) {
                let distance = RuntimeOSMCourseConverter.haversineMeters(
                    CLLocationCoordinate2D(latitude: teeCentroid.latitude, longitude: teeCentroid.longitude),
                    CLLocationCoordinate2D(latitude: greenCentroid.latitude, longitude: greenCentroid.longitude)
                )
                teeToGreenDistances.append(distance)
            }
            perHoleFeatureCounts.append(
                PerHoleFeatureCount(
                    holeNumber: hole.number,
                    tees: hole.features.filter { $0.kind == .tee }.count,
                    fairways: hole.features.filter { $0.kind == .fairway }.count,
                    greens: hole.features.filter { $0.kind == .green }.count,
                    bunkers: hole.features.filter { $0.kind == .bunker }.count,
                    waterHazards: hole.features.filter { $0.kind == .water }.count
                )
            )
        }
        teeToGreenDistances.sort()
        let percentiles = TeeToGreenPercentiles(
            min: teeToGreenDistances.first.map { Int($0.rounded()) },
            p50: teeToGreenDistances.percentile(0.5).map { Int($0.rounded()) },
            max: teeToGreenDistances.last.map { Int($0.rounded()) }
        )

        return CourseStructuredSummary(
            name: course.name,
            holeCount: holeCount,
            totalPar: totalPar,
            par3HoleCount: par3,
            par4HoleCount: par4,
            par5HoleCount: par5,
            teeToGreenDistanceMetres: percentiles,
            featureCountsPerHole: perHoleFeatureCounts,
            holesMissingFairway: perHoleFeatureCounts.filter { $0.fairways == 0 }.count,
            holesMissingBunker: perHoleFeatureCounts.filter { $0.bunkers == 0 }.count
        )
    }

    private func makePrompt(summary: CourseStructuredSummary) -> String {
        let perHole = summary.featureCountsPerHole.map { row in
            "\(row.holeNumber):tees=\(row.tees) fairways=\(row.fairways) greens=\(row.greens) bunkers=\(row.bunkers) water=\(row.waterHazards)"
        }.joined(separator: "; ")

        return """
        You are a golf-course data reviewer. The user just imported a course's
        geometry from OpenStreetMap and we want a sanity-check before they play.
        Return JSON only with this exact shape:
        {"verdict":"ok|concerns|broken","concerns":["..."],"oneLineSummary":"..."}

        - "verdict":
          - "ok" → the data looks plausible for play.
          - "concerns" → the data is usable but something looks unusual a player should know about.
          - "broken" → the data has structural problems that would ruin play (use sparingly).
        - "concerns" must be at most three short bullet strings, focused on
          interpretive issues a rule-based checker would miss
          (eg. "12 of 18 holes have no fairway polygon at all").
        - "oneLineSummary" must be a single sentence appropriate to show in a UI banner.

        Course: \(summary.name)
        Hole count: \(summary.holeCount)
        Total par: \(summary.totalPar)
        Par distribution: \(summary.par3HoleCount) par-3, \(summary.par4HoleCount) par-4, \(summary.par5HoleCount) par-5
        Tee→green distances (m): min=\(summary.teeToGreenDistanceMetres.min ?? -1), median=\(summary.teeToGreenDistanceMetres.p50 ?? -1), max=\(summary.teeToGreenDistanceMetres.max ?? -1)
        Holes missing fairway polygon: \(summary.holesMissingFairway)
        Holes missing bunkers: \(summary.holesMissingBunker)
        Per-hole feature counts: \(perHole)
        """
    }
}

struct CourseStructuredSummary: Equatable {
    let name: String
    let holeCount: Int
    let totalPar: Int
    let par3HoleCount: Int
    let par4HoleCount: Int
    let par5HoleCount: Int
    let teeToGreenDistanceMetres: TeeToGreenPercentiles
    let featureCountsPerHole: [PerHoleFeatureCount]
    let holesMissingFairway: Int
    let holesMissingBunker: Int
}

struct TeeToGreenPercentiles: Equatable {
    let min: Int?
    let p50: Int?
    let max: Int?
}

struct PerHoleFeatureCount: Equatable {
    let holeNumber: Int
    let tees: Int
    let fairways: Int
    let greens: Int
    let bunkers: Int
    let waterHazards: Int
}

private extension Array where Element == Double {
    func percentile(_ p: Double) -> Double? {
        guard !isEmpty else { return nil }
        let clamped = Swift.min(Swift.max(p, 0), 1)
        let index = Int((clamped * Double(count - 1)).rounded())
        return self[index]
    }
}

struct LiveFoundationModelsCourseSession: FoundationModelsCourseSessioning {
    func review(prompt: String) async throws -> FoundationModelsCourseReviewResponse {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.availability == .available else {
                throw FoundationModelsCourseValidatorError.modelUnavailable
            }
            let session = LanguageModelSession(
                model: model,
                instructions: "Return a concise course-data review using only the provided facts."
            )
            let response = try await session.respond(to: prompt)
            return try FoundationModelsCourseValidator.parseResponseContent(response.content)
        }
        #endif
        throw FoundationModelsCourseValidatorError.frameworkUnavailable
    }
}
