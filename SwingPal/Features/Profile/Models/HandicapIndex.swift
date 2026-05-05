import Foundation

struct HandicapIndexSnapshot: Equatable, Codable {
    /// User-entered Handicap Index (e.g. 12.4). This is treated as authoritative.
    var manualIndex: Double?

    init(manualIndex: Double? = nil) {
        self.manualIndex = manualIndex
    }
}

enum HandicapIndexEstimator {
    /// Minimal, offline estimate using finished rounds when we don't have
    /// course rating / slope available yet. Uses a par-only baseline:
    /// differential ≈ (score - parTotal).
    ///
    /// This is *not* an official WHS computation; it is a useful estimate until
    /// we wire in rating/slope per tee.
    static func estimateIndex(from rounds: [RoundHistorySummary]) -> Double? {
        let differentials = rounds
            .filter { $0.status == .finished }
            .map { differential(from: $0) }
            .compactMap { $0 }
            .sorted()

        guard differentials.count >= 3 else { return nil }

        let bestCount = bestDifferentialCount(for: differentials.count)
        guard bestCount > 0 else { return nil }
        let best = differentials.prefix(bestCount)
        let average = best.reduce(0.0, +) / Double(bestCount)
        // Mirror WHS-style display: one decimal place.
        return (average * 10).rounded() / 10
    }

    static func differential(from round: RoundHistorySummary) -> Double? {
        guard round.totalStrokes > 0 else { return nil }
        let parTotal: Int
        switch round.totalHoleCount {
        case 9:
            parTotal = 36
        case 18:
            parTotal = 72
        default:
            // Unknown hole count — we can't baseline sensibly.
            return nil
        }
        return Double(round.totalStrokes - parTotal)
    }

    /// Approximation of WHS “best X of last N” thresholds.
    private static func bestDifferentialCount(for count: Int) -> Int {
        switch count {
        case 3: return 1
        case 4: return 1
        case 5: return 1
        case 6: return 2
        case 7: return 2
        case 8: return 2
        case 9: return 3
        case 10: return 3
        case 11: return 4
        case 12: return 4
        case 13: return 5
        case 14: return 5
        case 15: return 6
        case 16: return 6
        case 17: return 7
        case 18: return 8
        case 19: return 8
        default:
            return count >= 20 ? 8 : 0
        }
    }
}

