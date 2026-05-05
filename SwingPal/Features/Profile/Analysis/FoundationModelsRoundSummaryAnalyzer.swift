import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoundationModelsRoundSummaryResponse: Codable, Equatable {
    let summary: String
    let whatWentWell: [String]
    let needsWork: [String]
}

protocol FoundationModelsRoundSummarySessioning {
    func generate(prompt: String) async throws -> FoundationModelsRoundSummaryResponse
}

enum FoundationModelsRoundSummaryAnalyzerError: LocalizedError {
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
            return "FoundationModels returned an invalid round analysis payload."
        }
    }
}

struct FoundationModelsRoundSummaryAnalyzer: RoundSummaryAnalysisGenerating {
    private let session: any FoundationModelsRoundSummarySessioning

    init(session: any FoundationModelsRoundSummarySessioning = LiveFoundationModelsRoundSummarySession()) {
        self.session = session
    }

    func generateAnalysis(for summary: RoundHistorySummary) async throws -> RoundSummaryAnalysis {
        let response = try await session.generate(prompt: makePrompt(for: summary))
        return RoundSummaryAnalysis(
            roundID: summary.id,
            cacheKey: RoundSummaryAnalysis.CacheKey(summary: summary).rawValue,
            provider: .foundationModels,
            summary: response.summary,
            whatWentWell: Array(response.whatWentWell.prefix(3)),
            needsWork: Array(response.needsWork.prefix(3)),
            generatedAt: Date()
        )
    }

    static func parseResponseContent(_ raw: String) throws -> FoundationModelsRoundSummaryResponse {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: Substring

        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            candidate = trimmed[start...end]
        } else {
            candidate = Substring(trimmed)
        }

        guard let data = String(candidate).data(using: .utf8) else {
            throw FoundationModelsRoundSummaryAnalyzerError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(FoundationModelsRoundSummaryResponse.self, from: data)
        } catch {
            throw FoundationModelsRoundSummaryAnalyzerError.invalidResponse
        }
    }

    private func makePrompt(for summary: RoundHistorySummary) -> String {
        """
        You are a golf round analyst. Use only the provided facts.
        Return JSON only with this exact shape:
        {"summary":"...","whatWentWell":["...","...","..."],"needsWork":["...","...","..."]}
        Return one short summary sentence, exactly three strengths, and exactly three improvement bullets.
        Do not invent shots, clubs, weather, or conditions that were not provided.

        Course: \(summary.courseName)
        Status: \(summary.status.rawValue)
        Hole progress: \(summary.holeNumber) of \(summary.totalHoleCount)
        Players: \(summary.playerCount)
        Total strokes: \(summary.totalStrokes)
        Completed holes: \(summary.completedHoleCount)
        Total putts: \(summary.totalPutts)
        Total penalties: \(summary.totalPenalties)
        """
    }
}

struct LiveFoundationModelsRoundSummarySession: FoundationModelsRoundSummarySessioning {
    func generate(prompt: String) async throws -> FoundationModelsRoundSummaryResponse {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.availability == .available else {
                throw FoundationModelsRoundSummaryAnalyzerError.modelUnavailable
            }

            let session = LanguageModelSession(
                model: model,
                instructions: "Return concise golf round analysis using only the provided facts."
            )
            let response = try await session.respond(to: prompt)
            return try FoundationModelsRoundSummaryAnalyzer.parseResponseContent(response.content)
        }
        #endif

        throw FoundationModelsRoundSummaryAnalyzerError.frameworkUnavailable
    }
}
