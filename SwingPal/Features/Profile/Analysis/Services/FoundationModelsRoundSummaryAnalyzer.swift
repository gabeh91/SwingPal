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
    case noCard

    var errorDescription: String? {
        switch self {
        case .frameworkUnavailable:
            return "FoundationModels is unavailable on this build."
        case .modelUnavailable:
            return "The on-device model is not currently available."
        case .invalidResponse:
            return "FoundationModels returned an invalid round analysis payload."
        case .noCard:
            return "This round has no hole-by-hole card to write notes from."
        }
    }
}

/// Writes the caddie's notes with Apple's on-device model. The model gets the
/// hole-by-hole card plus the observations `RoundRecapWriter` has already
/// worked out, and its lines are checked before they're shown: a line that
/// doesn't cite a hole or a figure, or that talks about the app rather than
/// the golf, is dropped. Rounds without a card go to the writer instead.
struct FoundationModelsRoundSummaryAnalyzer: RoundSummaryAnalysisGenerating {
    private let session: any FoundationModelsRoundSummarySessioning

    init(session: any FoundationModelsRoundSummarySessioning = LiveFoundationModelsRoundSummarySession()) {
        self.session = session
    }

    func generateAnalysis(for summary: RoundHistorySummary) async throws -> RoundSummaryAnalysis {
        guard !summary.holes.isEmpty else {
            throw FoundationModelsRoundSummaryAnalyzerError.noCard
        }
        let response = try await session.generate(prompt: Self.makePrompt(for: summary))
        let whatWentWell = Self.usableNotes(response.whatWentWell)
        let needsWork = Self.usableNotes(response.needsWork)
        let writerHasSomething = !RoundRecapWriter.strengths(for: summary).isEmpty
            || !RoundRecapWriter.needsWork(for: summary).isEmpty
        // Everything the model said was unusable, when there was something to say.
        if whatWentWell.isEmpty, needsWork.isEmpty, writerHasSomething {
            throw FoundationModelsRoundSummaryAnalyzerError.invalidResponse
        }
        let summaryLine = response.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return RoundSummaryAnalysis(
            roundID: summary.id,
            cacheKey: RoundSummaryAnalysis.CacheKey(summary: summary).rawValue,
            provider: .foundationModels,
            summary: Self.isUsable(summaryLine) ? summaryLine : RoundRecapWriter.summaryLine(for: summary),
            whatWentWell: whatWentWell,
            needsWork: needsWork,
            generatedAt: Date(),
            updatedAt: nil
        )
    }

    /// Words that mean a line is about the app or the record, not the golf.
    static let offTopicWords: Set<String> = [
        "log", "logs", "logged", "logging",
        "saving", "completed",
        "track", "tracked", "tracking",
        "data", "recap", "app", "record", "recorded", "baseline"
    ]

    static func isUsable(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.contains(where: \.isNumber) else { return false }
        let words = trimmed.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        return !words.contains { offTopicWords.contains($0) }
    }

    static func usableNotes(_ lines: [String]) -> [String] {
        Array(
            lines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter(isUsable)
                .prefix(RoundRecapWriter.maximumNotes)
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

    static let instructions = """
        You are a golf caddie writing short notes on a player's round, for the player.
        Use only the facts you are given. Never invent shots, clubs, distances, weather or conditions.
        Every note must name a hole (as a digit, e.g. "the 7th") or a figure from the card.
        Never mention logging, saving, tracking, data, records or the app — only the golf.
        Give at most three notes for each list. If nothing is worth saying, give fewer, or none.
        Write plainly, in the second person, one short sentence per note.
        """

    static func makePrompt(for summary: RoundHistorySummary) -> String {
        let holes = summary.holes
        let strokes = holes.reduce(0) { $0 + $1.score }
        let par = holes.reduce(0) { $0 + $1.par }
        let card = holes.map { hole -> String in
            var parts = ["par \(hole.par)", "scored \(hole.score) (\(RoundRecapWriter.overUnder(hole.toPar)))"]
            if let putts = hole.putts { parts.append("\(putts) putt\(putts == 1 ? "" : "s")") }
            if hole.penalties > 0 { parts.append("\(hole.penalties) penalty stroke\(hole.penalties == 1 ? "" : "s")") }
            if let fairway = hole.fairwayHit { parts.append(fairway ? "fairway hit" : "fairway missed") }
            if let green = hole.greenInRegulation { parts.append(green ? "green in regulation" : "green missed in regulation") }
            if hole.chippedIn == true {
                parts.append("holed out from off the green")
            } else if let upAndDown = hole.upAndDown {
                let what = hole.sandSave != nil ? "sand save" : "up and down"
                parts.append(upAndDown ? what : "no \(what)")
            }
            if let shots = hole.shortGameShots, shots >= 2 { parts.append("\(shots) shots around the green") }
            if let firstPutt = hole.firstPuttMeters { parts.append("first putt from \(firstPutt) m") }
            return "Hole \(hole.number): " + parts.joined(separator: ", ")
        }
        let good = RoundRecapWriter.strengths(for: summary)
        let costly = RoundRecapWriter.needsWork(for: summary)
        func bullets(_ lines: [String]) -> String {
            lines.isEmpty ? "(none)" : lines.map { "- \($0)" }.joined(separator: "\n")
        }

        return """
        Course: \(summary.courseName)
        Round: \(summary.status == .finished ? "finished" : "stopped early"), \(holes.count) of \(summary.totalHoleCount) holes scored
        Score: \(strokes) against a par of \(par) (\(RoundRecapWriter.overUnder(strokes - par)))

        Card:
        \(card.joined(separator: "\n"))

        What went well, worked out from the card:
        \(bullets(good))

        What cost shots, worked out from the card:
        \(bullets(costly))

        Write a one-sentence summary of the round that states the score, then the notes for what went well and what needs work. \
        Prefer the points above; you may reword or combine them, and add another only if the card clearly shows it.
        """
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct GeneratedRoundNotes {
    @Guide(description: "One sentence on the round that states the score.")
    var summary: String
    @Guide(description: "Up to three things that went well, each naming a hole or a figure from the card.")
    var whatWentWell: [String]
    @Guide(description: "Up to three things that cost shots, each naming a hole or a figure from the card.")
    var needsWork: [String]
}
#endif

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
                instructions: FoundationModelsRoundSummaryAnalyzer.instructions
            )
            // Guided generation: the model fills the struct directly, so
            // there's no JSON to parse (or fail to parse).
            let response = try await session.respond(to: prompt, generating: GeneratedRoundNotes.self)
            return FoundationModelsRoundSummaryResponse(
                summary: response.content.summary,
                whatWentWell: response.content.whatWentWell,
                needsWork: response.content.needsWork
            )
        }
        #endif

        throw FoundationModelsRoundSummaryAnalyzerError.frameworkUnavailable
    }
}
