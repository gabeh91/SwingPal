import Foundation

struct StatsFact: Equatable {
    let title: String
    let value: String
    let detail: String
}

struct StatsSkillSection: Equatable {
    let title: String
    let summary: String
    let facts: [StatsFact]
}

enum StatsSignalTone: Equatable {
    case positive
    case caution
    case neutral
}

struct StatsViewModel {
    let heroTitle: String
    let trendSignalTitle: String
    let trendSignalValue: String
    let trendSignalDetail: String
    let trendSignalTone: StatsSignalTone
    let sections: [StatsSkillSection]
    let recentRounds: [RoundHistorySummary]
    /// Completed cards with the same hole count as the latest, oldest first:
    /// the sample the stroke line is drawn from.
    let strokeLine: [RoundHistorySummary]

    init(previousRounds: [RoundHistorySummary], analyses: [RoundSummaryAnalysis]) {
        let sortedRounds = previousRounds.sorted { $0.updatedAt > $1.updatedAt }
        let completedRounds = Self.completedRounds(from: sortedRounds)

        heroTitle = "Latest Round Intelligence"

        let trend = Self.makeTrendSignal(from: Self.comparableRounds(from: completedRounds))
        trendSignalTitle = trend.title
        trendSignalValue = trend.value
        trendSignalDetail = trend.detail
        trendSignalTone = trend.tone

        sections = Self.makeSections(from: sortedRounds)
        recentRounds = Array(sortedRounds.prefix(5))
        strokeLine = Array(Self.comparableRounds(from: completedRounds).prefix(12).reversed())
    }

    private static func makeTrendSignal(from rounds: [RoundHistorySummary]) -> (title: String, value: String, detail: String, tone: StatsSignalTone) {
        guard let latest = rounds.first else {
            return (
                title: "No trend yet",
                value: "--",
                detail: "Log a completed round to start building performance signals.",
                tone: .neutral
            )
        }

        guard rounds.count > 1 else {
            return (
                title: "Latest scorecard loaded",
                value: "\(latest.totalStrokes) strokes",
                detail: "Need another completed \(latest.totalHoleCount)-hole round for comparison.",
                tone: .neutral
            )
        }

        let previous = rounds[1]
        if latest.totalPenalties < previous.totalPenalties {
            return (
                title: "Penalty control improved",
                value: penaltyLabel(for: latest.totalPenalties),
                detail: "Down from \(previous.totalPenalties) in the previous round.",
                tone: .positive
            )
        }

        if latest.totalPenalties > previous.totalPenalties {
            return (
                title: "Penalty load climbed",
                value: penaltyLabel(for: latest.totalPenalties),
                detail: "Up from \(previous.totalPenalties) in the previous round.",
                tone: .caution
            )
        }

        let latestPuttsPerHole = puttsPerHole(for: latest)
        let previousPuttsPerHole = puttsPerHole(for: previous)
        if latestPuttsPerHole < previousPuttsPerHole {
            return (
                title: "Putting pressure eased",
                value: formatted(latestPuttsPerHole),
                detail: "Down from \(formatted(previousPuttsPerHole)) putts per hole.",
                tone: .positive
            )
        }

        if latestPuttsPerHole > previousPuttsPerHole {
            return (
                title: "Putting load increased",
                value: formatted(latestPuttsPerHole),
                detail: "Up from \(formatted(previousPuttsPerHole)) putts per hole.",
                tone: .caution
            )
        }

        return (
            title: "Penalty and putting totals unchanged",
            value: "\(latest.totalStrokes) strokes",
            detail: "The last two comparable scorecards have the same recorded penalties and putts.",
            tone: .neutral
        )
    }

    private static func completedRounds(from rounds: [RoundHistorySummary]) -> [RoundHistorySummary] {
        rounds.filter {
            $0.status == .finished && $0.totalHoleCount > 0
                && $0.completedHoleCount == $0.totalHoleCount && $0.totalStrokes > 0
        }
    }

    private static func comparableRounds(from completedRounds: [RoundHistorySummary]) -> [RoundHistorySummary] {
        guard let latest = completedRounds.first else { return [] }
        return completedRounds.filter { $0.totalHoleCount == latest.totalHoleCount }
    }

    private static func makeSections(from rounds: [RoundHistorySummary]) -> [StatsSkillSection] {
        let recentHistory = Array(rounds.prefix(5))
        let performanceRounds = Array(comparableRounds(from: completedRounds(from: rounds)).prefix(5))
        let finishedHistory = completedRounds(from: recentHistory)
        let unfinishedHistory = recentHistory.filter { $0.status == .unfinished }
        let history = StatsSkillSection(
            title: "Round History",
            summary: "Saved checkpoints stay in your history and are excluded from performance comparisons.",
            facts: [
                .init(title: "Finished Rounds", value: "\(finishedHistory.count)", detail: "Completed scorecards"),
                .init(title: "Saved Checkpoints", value: "\(unfinishedHistory.count)", detail: "Resumable rounds"),
                .init(title: "Hole Completion", value: recentHistory.isEmpty ? "--" : percentage(holeCompletionRate(for: recentHistory)), detail: "Across last \(recentHistory.count) saved rounds")
            ]
        )

        guard let latest = performanceRounds.first else {
            func placeholder(_ title: String, _ titles: [String]) -> StatsSkillSection {
                .init(title: title, summary: "Complete a scorecard to see recorded \(title.lowercased()) figures.",
                      facts: titles.map { .init(title: $0, value: "--", detail: "Completed scorecard needed") })
            }
            return [
                placeholder("Penalties", ["Latest Penalties", "Recent Avg", "Penalty-Free"]),
                placeholder("Scoring", ["Latest Strokes / Hole", "Recent Avg", "Best Score"]),
                history,
                placeholder("Putting", ["Latest Putts / Hole", "Recent Avg", "Best Round"])
            ]
        }

        let sample = "Last \(performanceRounds.count) finished \(latest.totalHoleCount)-hole round\(performanceRounds.count == 1 ? "" : "s")"
        let averagePenalties = average(performanceRounds.map { Double($0.totalPenalties) })
        let averageStrokesPerHole = average(performanceRounds.map(strokesPerHole(for:)))
        let averagePuttsPerHole = average(performanceRounds.map(puttsPerHole(for:)))
        let penaltyFreeRounds = performanceRounds.filter { $0.totalPenalties == 0 }.count
        return [
            .init(
                title: "Penalties",
                summary: "Recorded penalties across all shots; these totals do not identify which part of your game caused them.",
                facts: [
                    .init(title: "Latest Penalties", value: "\(latest.totalPenalties)", detail: "Latest completed round"),
                    .init(title: "Recent Avg", value: formatted(averagePenalties), detail: sample),
                    .init(title: "Penalty-Free", value: "\(penaltyFreeRounds) / \(performanceRounds.count)", detail: "Cards with no recorded penalties")
                ]
            ),
            .init(
                title: "Scoring",
                summary: "Recorded strokes across completed \(latest.totalHoleCount)-hole rounds. Course difficulty is not adjusted.",
                facts: [
                    .init(title: "Latest Strokes / Hole", value: formatted(strokesPerHole(for: latest)), detail: "Latest completed round"),
                    .init(title: "Recent Avg", value: formatted(averageStrokesPerHole), detail: sample),
                    .init(title: "Best Score", value: "\(performanceRounds.map(\.totalStrokes).min()!)", detail: sample)
                ]
            ),
            history,
            .init(
                title: "Putting",
                summary: "Recorded putts on completed scorecards. Unrecorded putts cannot be distinguished from zero.",
                facts: [
                    .init(title: "Latest Putts / Hole", value: formatted(puttsPerHole(for: latest)), detail: "Recorded putts / completed holes"),
                    .init(title: "Recent Avg", value: formatted(averagePuttsPerHole), detail: sample),
                    .init(title: "Best Round", value: "\(performanceRounds.map(\.totalPutts).min()!)", detail: "Fewest recorded putts; \(latest.totalHoleCount) holes")
                ]
            )
        ]
    }

    private static func puttsPerHole(for summary: RoundHistorySummary) -> Double {
        let divisor = max(summary.completedHoleCount, 1)
        return Double(summary.totalPutts) / Double(divisor)
    }

    private static func strokesPerHole(for summary: RoundHistorySummary) -> Double {
        let divisor = max(summary.completedHoleCount, 1)
        return Double(summary.totalStrokes) / Double(divisor)
    }

    private static func penaltyLabel(for count: Int) -> String {
        count == 1 ? "1 penalty" : "\(count) penalties"
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else {
            return 0
        }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func holeCompletionRate(for summaries: [RoundHistorySummary]) -> Double {
        let totalHoles = summaries.reduce(0) { $0 + $1.totalHoleCount }
        guard totalHoles > 0 else {
            return 0
        }

        let completedHoles = summaries.reduce(0) { $0 + $1.completedHoleCount }
        return Double(completedHoles) / Double(totalHoles)
    }

    private static func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    private static func percentage(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}
