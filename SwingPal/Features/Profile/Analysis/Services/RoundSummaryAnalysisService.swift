import Foundation

protocol RoundSummaryAnalysisGenerating {
    func generateAnalysis(for summary: RoundHistorySummary) async throws -> RoundSummaryAnalysis
}

struct DeterministicRoundSummaryAnalysisGenerator: RoundSummaryAnalysisGenerating {
    func generateAnalysis(for summary: RoundHistorySummary) async throws -> RoundSummaryAnalysis {
        RoundRecapWriter.analysis(for: summary)
    }
}

/// Works out the caddie's notes on a round from its card. Every line names a
/// hole or a figure from the card; when there's nothing worth saying it says
/// less rather than padding a section out. Rounds saved before the card was
/// kept only have totals, so their notes are limited to what totals show.
enum RoundRecapWriter {
    static let maximumNotes = 3

    static func analysis(for summary: RoundHistorySummary, generatedAt: Date = Date()) -> RoundSummaryAnalysis {
        RoundSummaryAnalysis(
            roundID: summary.id,
            cacheKey: RoundSummaryAnalysis.CacheKey(summary: summary).rawValue,
            provider: .deterministic,
            summary: summaryLine(for: summary),
            whatWentWell: strengths(for: summary),
            needsWork: needsWork(for: summary),
            generatedAt: generatedAt,
            updatedAt: nil
        )
    }

    // MARK: Summary

    static func summaryLine(for summary: RoundHistorySummary) -> String {
        let holes = summary.holes
        guard !holes.isEmpty else { return totalsOnlySummaryLine(for: summary) }

        let strokes = holes.reduce(0) { $0 + $1.score }
        let toPar = holes.reduce(0) { $0 + $1.toPar }
        let lead: String
        if summary.status == .finished || holes.count >= summary.totalHoleCount {
            lead = "Shot \(strokes) (\(overUnder(toPar))) for the \(count(holes.count, "hole"))"
        } else {
            lead = "\(strokes) (\(overUnder(toPar))) through \(holes.count) of \(summary.totalHoleCount) holes"
        }
        let shape = scoringShape(holes)
        return shape.isEmpty ? "\(lead)." : "\(lead) — \(shape)."
    }

    private static func totalsOnlySummaryLine(for summary: RoundHistorySummary) -> String {
        guard summary.completedHoleCount > 0, summary.totalStrokes > 0 else {
            return "No holes were scored before this round was saved."
        }
        var parts = ["\(count(summary.totalStrokes, "stroke")) over \(count(summary.completedHoleCount, "hole"))"]
        if summary.totalPutts > 0 {
            parts.append(count(summary.totalPutts, "putt"))
        }
        parts.append(summary.totalPenalties == 0 ? "no penalty strokes" : count(summary.totalPenalties, "penalty stroke"))
        return joined(parts) + "."
    }

    private static func scoringShape(_ holes: [RoundHistorySummary.HoleRecord]) -> String {
        let aces = holes.filter { $0.score == 1 }.count
        let eagles = holes.filter { $0.toPar <= -2 && $0.score != 1 }.count
        let birdies = holes.filter { $0.toPar == -1 }.count
        let pars = holes.filter { $0.toPar == 0 }.count
        let bogeys = holes.filter { $0.toPar == 1 }.count
        let doubles = holes.filter { $0.toPar == 2 }.count
        let worse = holes.filter { $0.toPar >= 3 }.count
        var parts: [String] = []
        if aces > 0 { parts.append(aces == 1 ? "a hole in one" : "\(aces) holes in one") }
        if eagles > 0 { parts.append(count(eagles, "eagle")) }
        if birdies > 0 { parts.append(count(birdies, "birdie")) }
        if pars > 0 { parts.append(count(pars, "par")) }
        if bogeys > 0 { parts.append(count(bogeys, "bogey")) }
        if doubles > 0 { parts.append(count(doubles, "double")) }
        if worse > 0 { parts.append("\(worse) triple or worse") }
        return joined(parts)
    }

    // MARK: What went well

    static func strengths(for summary: RoundHistorySummary) -> [String] {
        let holes = summary.holes
        guard !holes.isEmpty else { return totalsOnlyStrengths(for: summary) }
        var notes: [String] = []

        let aces = holes.filter { $0.score == 1 }.map(\.number)
        if !aces.isEmpty {
            notes.append("Hole in one on \(holeList(aces)).")
        }
        let eagles = holes.filter { $0.toPar <= -2 && $0.score != 1 }.map(\.number)
        if !eagles.isEmpty {
            notes.append("\(eagles.count == 1 ? "Eagle" : "Eagles") on \(holeList(eagles)).")
        }
        let birdies = holes.filter { $0.toPar == -1 }.map(\.number)
        if !birdies.isEmpty {
            notes.append("\(birdies.count == 1 ? "Birdie" : "Birdies") on \(holeList(birdies)).")
        }

        let run = longestParOrBetterRun(holes)
        if run.count == holes.count, holes.count >= 3 {
            notes.append("Par or better on all \(holes.count) holes.")
        } else if run.count >= 3, let first = run.first, let last = run.last {
            notes.append("Par or better on \(run.count) holes in a row, \(ordinal(first)) to \(ordinal(last)).")
        }

        let chipIns = holes.filter { $0.chippedIn == true }.map(\.number)
        if !chipIns.isEmpty {
            notes.append("Holed out from off the green on \(holeList(chipIns)).")
        }

        // Chip-ins and bunkers get their own lines, so they aren't counted
        // again here.
        let chipTries = holes.filter { $0.upAndDown != nil && $0.sandSave == nil && $0.chippedIn != true }
        let upAndDowns = chipTries.filter { $0.upAndDown == true }.map(\.number)
        if !upAndDowns.isEmpty, upAndDowns.count * 2 >= chipTries.count {
            if upAndDowns.count < chipTries.count {
                notes.append("Up and down \(times(upAndDowns.count)) from \(chipTries.count) chances: \(holeList(upAndDowns)).")
            } else if upAndDowns.count == 1 {
                notes.append("Up and down on \(holeList(upAndDowns)).")
            } else {
                notes.append("Up and down all \(upAndDowns.count) times: \(holeList(upAndDowns)).")
            }
        }

        let sandSaves = holes.filter { $0.sandSave == true && $0.chippedIn != true }.map(\.number)
        if !sandSaves.isEmpty {
            notes.append("\(sandSaves.count == 1 ? "Sand save" : "Sand saves") on \(holeList(sandSaves)).")
        }

        // Without shots logged around the green, a par after a missed green
        // is the nearest thing to an up-and-down the card can show.
        let hasShortGameRecord = holes.contains { $0.upAndDown != nil || $0.chippedIn == true }
        if !hasShortGameRecord {
            let saves = holes.filter { $0.greenInRegulation == false && $0.toPar == 0 }.map(\.number)
            if !saves.isEmpty {
                notes.append("Saved par after missing the green on \(holeList(saves)).")
            }
        }

        let puttedHoles = holes.compactMap { hole in hole.putts.map { (number: hole.number, putts: $0) } }
        if puttedHoles.count >= 3 {
            let threePutts = puttedHoles.filter { $0.putts >= 3 }
            let onePutts = puttedHoles.filter { $0.putts == 1 }.map(\.number)
            let totalPutts = puttedHoles.reduce(0) { $0 + $1.putts }
            let perHole = Double(totalPutts) / Double(puttedHoles.count)
            if threePutts.isEmpty, puttedHoles.count >= 6 {
                let onePuttClause = onePutts.count >= 2 ? ", with one-putts on \(holeList(onePutts))" : ""
                notes.append("No three-putts in \(puttedHoles.count) holes\(onePuttClause).")
            } else if onePutts.count >= 3 {
                notes.append("One-putts on \(holeList(onePutts)).")
            } else if perHole <= 1.7 {
                notes.append("\(count(totalPutts, "putt")) over \(puttedHoles.count) holes — \(oneDecimal(perHole)) a hole.")
            }
        }

        let fairways = rate(holes.compactMap(\.fairwayHit))
        if fairways.of >= 3, Double(fairways.hit) / Double(fairways.of) >= 0.6 {
            notes.append("Hit \(fairways.hit) of \(fairways.of) fairways.")
        }
        let greens = rate(holes.compactMap(\.greenInRegulation))
        if greens.of >= 3, Double(greens.hit) / Double(greens.of) >= 0.5 {
            notes.append("Hit \(greens.hit) of \(greens.of) greens in regulation.")
        }

        if let best = parTypeResults(holes).min(by: { $0.perHole < $1.perHole }),
           parTypeResults(holes).count > 1,
           best.toPar <= 0 {
            notes.append("Played the par \(best.par)s in \(overUnder(best.toPar)) across \(best.holes) holes.")
        }

        if holes.count >= 6, holes.allSatisfy({ $0.penalties == 0 }) {
            notes.append("No penalty strokes in \(holes.count) holes.")
        }

        return Array(notes.prefix(maximumNotes))
    }

    private static func totalsOnlyStrengths(for summary: RoundHistorySummary) -> [String] {
        let holes = summary.completedHoleCount
        guard holes > 0 else { return [] }
        var notes: [String] = []
        if holes >= 3, summary.totalPutts > 0 {
            let perHole = Double(summary.totalPutts) / Double(holes)
            if perHole <= 1.7 {
                notes.append("\(count(summary.totalPutts, "putt")) over \(holes) holes — \(oneDecimal(perHole)) a hole.")
            }
        }
        if holes >= 6, summary.totalPenalties == 0 {
            notes.append("No penalty strokes in \(holes) holes.")
        }
        return notes
    }

    // MARK: Needs attention

    static func needsWork(for summary: RoundHistorySummary) -> [String] {
        let holes = summary.holes
        guard !holes.isEmpty else { return totalsOnlyNeedsWork(for: summary) }
        var notes: [String] = []
        let roundToPar = holes.reduce(0) { $0 + $1.toPar }

        let blowUps = holes.filter { $0.toPar >= 2 }
        if blowUps.count == 1, let hole = blowUps.first {
            var line = "\(overParName(hole.toPar)) on \(ordinal(hole.number))"
            if roundToPar > hole.toPar {
                line += ", \(hole.toPar) of the \(roundToPar) over par"
            }
            notes.append(line + ".")
        } else if blowUps.count > 1 {
            let dropped = blowUps.reduce(0) { $0 + $1.toPar }
            let list = joined(blowUps.map { "\(ordinal($0.number)) (+\($0.toPar))" })
            var line = "Doubles or worse on \(list)"
            if roundToPar >= dropped {
                line += ", \(dropped) of the \(roundToPar) over par"
            } else {
                line += ", \(dropped) over between them"
            }
            notes.append(line + ".")
        }

        let penaltyHoles = holes.filter { $0.penalties > 0 }
        if penaltyHoles.count == 1, let hole = penaltyHoles.first {
            notes.append("\(hole.penalties == 1 ? "A penalty stroke" : "\(hole.penalties) penalty strokes") on \(ordinal(hole.number)).")
        } else if penaltyHoles.count > 1 {
            let total = penaltyHoles.reduce(0) { $0 + $1.penalties }
            notes.append("Penalty strokes on \(holeList(penaltyHoles.map(\.number))), \(total) in all.")
        }

        let puttedHoles = holes.compactMap { hole in hole.putts.map { (number: hole.number, putts: $0) } }
        let threePutts = puttedHoles.filter { $0.putts >= 3 }
        if !threePutts.isEmpty {
            let noun = threePutts.contains(where: { $0.putts >= 4 }) ? "Three-putts or worse" : (threePutts.count == 1 ? "Three-putt" : "Three-putts")
            notes.append("\(noun) on \(holeList(threePutts.map(\.number))).")
        }

        let duffed = holes.filter { ($0.shortGameShots ?? 0) >= 2 }
        if duffed.count == 1, let hole = duffed.first {
            notes.append("Needed \(hole.shortGameShots ?? 2) shots around the green on \(ordinal(hole.number)).")
        } else if duffed.count > 1 {
            notes.append("Needed 2 or more shots around the green on \(holeList(duffed.map(\.number))).")
        }

        let upAndDownTries = holes.filter { $0.upAndDown != nil }
        let upAndDownsMade = upAndDownTries.filter { $0.upAndDown == true }.count
        if upAndDownTries.count >= 3, upAndDownsMade * 3 <= upAndDownTries.count {
            if upAndDownsMade == 0 {
                notes.append("No up-and-downs from \(upAndDownTries.count) chances.")
            } else {
                notes.append("Up and down \(times(upAndDownsMade)) from \(upAndDownTries.count) chances.")
            }
        }

        // Skipped when the line above already says it: every chance was a bunker.
        let sandTries = holes.filter { $0.sandSave != nil }
        let sandSavesMade = sandTries.filter { $0.sandSave == true }.count
        let alreadySaid = upAndDownsMade == 0 && upAndDownTries.count >= 3 && sandTries.count == upAndDownTries.count
        if sandTries.count >= 2, sandSavesMade == 0, !alreadySaid {
            notes.append("No sand saves from \(sandTries.count) bunkers.")
        }

        let parTypes = parTypeResults(holes)
        if let worst = parTypes.max(by: { $0.perHole < $1.perHole }), worst.perHole >= 1.0 {
            notes.append("The par \(worst.par)s played \(worst.toPar) over across \(worst.holes) holes, \(oneDecimal(worst.perHole)) a hole.")
        }

        let fairways = rate(holes.compactMap(\.fairwayHit))
        if fairways.of >= 3, Double(fairways.hit) / Double(fairways.of) <= 0.4 {
            notes.append("Found \(fairways.hit) of \(fairways.of) fairways.")
        }
        let greens = rate(holes.compactMap(\.greenInRegulation))
        if greens.of >= 4, Double(greens.hit) / Double(greens.of) <= 0.25 {
            notes.append("Hit \(greens.hit) of \(greens.of) greens in regulation.")
        }

        if threePutts.isEmpty, puttedHoles.count >= 4 {
            let totalPutts = puttedHoles.reduce(0) { $0 + $1.putts }
            let perHole = Double(totalPutts) / Double(puttedHoles.count)
            if perHole >= 2.2 {
                notes.append("\(count(totalPutts, "putt")) over \(puttedHoles.count) holes — \(oneDecimal(perHole)) a hole.")
            }
        }

        let front = holes.filter { (1...9).contains($0.number) }
        let back = holes.filter { (10...18).contains($0.number) }
        if front.count == 9, back.count == 9 {
            let frontStrokes = front.reduce(0) { $0 + $1.score }
            let backStrokes = back.reduce(0) { $0 + $1.score }
            let gap = (back.reduce(0) { $0 + $1.toPar }) - (front.reduce(0) { $0 + $1.toPar })
            if abs(gap) >= 4 {
                let (worse, better) = gap > 0 ? ("back", "front") : ("front", "back")
                notes.append("The \(worse) nine was \(abs(gap)) shots worse than the \(better) (\(gap > 0 ? backStrokes : frontStrokes) against \(gap > 0 ? frontStrokes : backStrokes)).")
            }
        }

        return Array(notes.prefix(maximumNotes))
    }

    private static func totalsOnlyNeedsWork(for summary: RoundHistorySummary) -> [String] {
        let holes = summary.completedHoleCount
        guard holes > 0 else { return [] }
        var notes: [String] = []
        if summary.totalPenalties > 0 {
            notes.append("\(count(summary.totalPenalties, "penalty stroke")) over \(count(holes, "hole")).")
        }
        if holes >= 3, summary.totalPutts > 0 {
            let perHole = Double(summary.totalPutts) / Double(holes)
            if perHole >= 2.2 {
                notes.append("\(count(summary.totalPutts, "putt")) over \(holes) holes — \(oneDecimal(perHole)) a hole.")
            }
        }
        return notes
    }

    // MARK: Helpers

    private struct ParTypeResult {
        let par: Int
        let holes: Int
        let toPar: Int
        var perHole: Double { Double(toPar) / Double(holes) }
    }

    /// Par types played at least twice, so one hole doesn't make a trend.
    private static func parTypeResults(_ holes: [RoundHistorySummary.HoleRecord]) -> [ParTypeResult] {
        Dictionary(grouping: holes, by: \.par)
            .filter { $0.value.count >= 2 }
            .map { ParTypeResult(par: $0.key, holes: $0.value.count, toPar: $0.value.reduce(0) { $0 + $1.toPar }) }
            .sorted { $0.par < $1.par }
    }

    private static func longestParOrBetterRun(_ holes: [RoundHistorySummary.HoleRecord]) -> [Int] {
        var best: [Int] = []
        var current: [Int] = []
        for hole in holes {
            if hole.toPar <= 0, current.isEmpty || current.last.map({ $0 + 1 == hole.number }) == true {
                current.append(hole.number)
            } else if hole.toPar <= 0 {
                current = [hole.number]
            } else {
                current = []
            }
            if current.count > best.count { best = current }
        }
        return best
    }

    private static func rate(_ results: [Bool]) -> (hit: Int, of: Int) {
        (results.filter { $0 }.count, results.count)
    }

    static func overUnder(_ toPar: Int) -> String {
        switch toPar {
        case 0: return "level par"
        case let over where over > 0: return "\(over) over"
        default: return "\(-toPar) under"
        }
    }

    private static func overParName(_ toPar: Int) -> String {
        switch toPar {
        case 2: return "Double bogey"
        case 3: return "Triple bogey"
        default: return "+\(toPar)"
        }
    }

    static func ordinal(_ number: Int) -> String {
        let suffix: String
        switch (number % 10, number % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "the \(number)\(suffix)"
    }

    /// "the 3rd", "the 3rd and 7th", "the 3rd, 7th and 12th".
    static func holeList(_ numbers: [Int]) -> String {
        let bare = numbers.map { String(ordinal($0).dropFirst(4)) }
        return "the " + joined(bare)
    }

    private static func joined(_ parts: [String]) -> String {
        switch parts.count {
        case 0: return ""
        case 1: return parts[0]
        default: return parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
        }
    }

    private static func count(_ value: Int, _ noun: String) -> String {
        "\(value) \(noun)\(value == 1 ? "" : "s")"
    }

    private static func times(_ value: Int) -> String {
        value == 1 ? "1 time" : "\(value) times"
    }

    private static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

final class RoundSummaryAnalysisService {
    enum Error: Swift.Error {
        case noAvailableGenerator
    }

    private let store: RoundSummaryAnalysisStoring
    private let generators: [RoundSummaryAnalysisGenerating]

    init(
        store: RoundSummaryAnalysisStoring = UserDefaultsRoundSummaryAnalysisStore(),
        generators: [RoundSummaryAnalysisGenerating] = [
            FoundationModelsRoundSummaryAnalyzer(),
            DeterministicRoundSummaryAnalysisGenerator()
        ]
    ) {
        self.store = store
        self.generators = generators
    }

    func cachedAnalysis(for summary: RoundHistorySummary) -> RoundSummaryAnalysis? {
        let key = RoundSummaryAnalysis.CacheKey(summary: summary).rawValue
        return store.load().first(where: { $0.roundID == summary.id && $0.cacheKey == key })
    }

    func analysis(for summary: RoundHistorySummary) async throws -> RoundSummaryAnalysis {
        if let cached = cachedAnalysis(for: summary) {
            return cached
        }

        for generator in generators {
            if let generated = try? await generator.generateAnalysis(for: summary) {
                persist(generated)
                return generated
            }
        }

        throw Error.noAvailableGenerator
    }

    private func persist(_ analysis: RoundSummaryAnalysis) {
        var analyses = store.load().filter { $0.roundID != analysis.roundID }
        analyses.insert(analysis, at: 0)
        store.save(analyses)

        // Best-effort cloud sync (no-op if Supabase/auth is unavailable).
        Task {
            guard SupabaseShared.client() != nil else { return }
            do {
                try await RoundSummaryAnalysisCloudStore().upsertMyAnalysis(analysis)
            } catch {
                // Keep local analysis even if push fails.
            }
        }
    }
}
