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

struct StatsOverviewHighlight: Equatable {
    let title: String
    let value: String
    let detail: String
}

enum StatsSignalTone: Equatable {
    case positive
    case caution
    case neutral
}

struct StatsRecentRoundCard: Equatable, Identifiable {
    let id: UUID
    let courseName: String
    let statusTitle: String
    let scoreValue: String
    let scoreCaption: String
    let progressLabel: String
    let progressValue: Double
    let metadataPills: [String]
    let updatedAt: Date
}

struct StatsViewModel {
    let heroTitle: String
    let heroCourseName: String
    let heroSummary: String
    let heroStrengths: [String]
    let heroImprovements: [String]
    let heroSnapshotFacts: [StatsFact]
    let trendSignalTitle: String
    let trendSignalValue: String
    let trendSignalDetail: String
    let trendSignalTone: StatsSignalTone
    let overviewHighlights: [StatsOverviewHighlight]
    let sections: [StatsSkillSection]
    let recentRoundsTitle: String
    let recentRounds: [RoundHistorySummary]
    let recentRoundCards: [StatsRecentRoundCard]

    init(previousRounds: [RoundHistorySummary], analyses: [RoundSummaryAnalysis]) {
        let sortedRounds = previousRounds.sorted { $0.updatedAt > $1.updatedAt }
        let latestRound = sortedRounds.first
        let latestAnalysis = latestRound.flatMap { latestRound in
            analyses.first(where: { $0.roundID == latestRound.id })
        }
        let heroModel = latestAnalysis.map(ProfileViewModel.previousRoundAnalysisModel(for:))
            ?? latestRound.map(ProfileViewModel.previousRoundAnalysisModel(for:))

        heroTitle = "Latest Round Intelligence"
        heroCourseName = latestRound?.courseName ?? "No round history yet"
        heroSummary = heroModel?.summary ?? "Finish and review a round to unlock your first AI-led stats briefing."
        heroStrengths = heroModel?.strengths ?? []
        heroImprovements = heroModel?.improvements ?? []
        heroSnapshotFacts = Self.makeHeroSnapshotFacts(from: sortedRounds)

        let trend = Self.makeTrendSignal(from: sortedRounds)
        trendSignalTitle = trend.title
        trendSignalValue = trend.value
        trendSignalDetail = trend.detail
        trendSignalTone = trend.tone

        sections = Self.makeSections(from: sortedRounds)
        overviewHighlights = Self.makeOverviewHighlights(from: sections)
        recentRoundsTitle = "Recent Rounds"
        recentRounds = Array(sortedRounds.prefix(5))
        recentRoundCards = recentRounds.map(Self.makeRecentRoundCard(for:))
    }

    private static func makeHeroSnapshotFacts(from rounds: [RoundHistorySummary]) -> [StatsFact] {
        guard let latest = rounds.first else {
            return [
                .init(title: "Latest Score", value: "--", detail: "No score yet"),
                .init(title: "Rounds Tracked", value: "0", detail: "History empty"),
                .init(title: "Finished Cards", value: "0", detail: "Need completed rounds")
            ]
        }

        let finishedRounds = rounds.filter { $0.status == .finished }
        return [
            .init(title: "Latest Score", value: "\(latest.totalStrokes)", detail: latest.status == .finished ? "Most recent scorecard" : "Saved checkpoint"),
            .init(title: "Rounds Tracked", value: "\(rounds.count)", detail: "Recent history"),
            .init(title: "Finished Cards", value: "\(finishedRounds.count)", detail: "Completed rounds")
        ]
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
                detail: "Need another round before SwingPal can call a trend.",
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
            title: "Scoring load holding steady",
            value: "\(latest.totalStrokes) strokes",
            detail: "The last two rounds landed in a very similar range.",
            tone: .neutral
        )
    }

    private static func makeSections(from rounds: [RoundHistorySummary]) -> [StatsSkillSection] {
        let recentRounds = Array(rounds.prefix(5))

        guard let latest = recentRounds.first else {
            let placeholderFacts = [
                StatsFact(title: "Signal", value: "--", detail: "Round data needed"),
                StatsFact(title: "Status", value: "Waiting", detail: "No rounds tracked yet"),
                StatsFact(title: "Depth", value: "--", detail: "Need more rounds")
            ]
            return [
                .init(title: "Driving", summary: "Tee-shot signals appear once rounds are logged.", facts: placeholderFacts),
                .init(title: "Approach", summary: "Approach load will sharpen as more full rounds land.", facts: placeholderFacts),
                .init(title: "Short Game", summary: "Short-game pressure needs completed holes to read cleanly.", facts: placeholderFacts),
                .init(title: "Putting", summary: "Putting facts need tracked rounds before they mean anything.", facts: placeholderFacts)
            ]
        }

        let finishedRounds = recentRounds.filter { $0.status == .finished }
        let unfinishedRounds = recentRounds.filter { $0.status == .unfinished }
        let averagePenalties = average(recentRounds.map { Double($0.totalPenalties) })
        let averageStrokesPerHole = average(recentRounds.map(strokesPerHole(for:)))
        let averagePuttsPerHole = average(recentRounds.map(puttsPerHole(for:)))
        let completionRate = holeCompletionRate(for: recentRounds)
        let penaltyFreeRounds = recentRounds.filter { $0.totalPenalties == 0 }.count
        let bestFinishedScore = finishedRounds.map(\.totalStrokes).min() ?? latest.totalStrokes
        let bestFinishedPutting = finishedRounds.map(\.totalPutts).min() ?? latest.totalPutts

        return [
            .init(
                title: "Driving",
                summary: averagePenalties <= 1
                    ? "Penalty control is staying mostly manageable across the recent sample."
                    : "Penalty strokes remain the clearest off-tee scoring leak in the recent sample.",
                facts: [
                    .init(title: "Latest Penalties", value: "\(latest.totalPenalties)", detail: "Most recent round"),
                    .init(title: "Recent Avg", value: formatted(averagePenalties), detail: "Last \(recentRounds.count) rounds"),
                    .init(title: "Penalty-Free", value: "\(penaltyFreeRounds) / \(recentRounds.count)", detail: "Rounds without a penalty")
                ]
            ),
            .init(
                title: "Approach",
                summary: averageStrokesPerHole <= strokesPerHole(for: latest)
                    ? "Scoring load is stable, but the latest round did not beat your recent per-hole scoring pace."
                    : "The latest round beat your recent scoring pace, which is the cleanest approach-side signal available right now.",
                facts: [
                    .init(title: "Latest Strokes / Hole", value: formatted(strokesPerHole(for: latest)), detail: "Completed holes only"),
                    .init(title: "Recent Avg", value: formatted(averageStrokesPerHole), detail: "Last \(recentRounds.count) rounds"),
                    .init(title: "Best Score", value: "\(bestFinishedScore)", detail: "Best finished round")
                ]
            ),
            .init(
                title: "Short Game",
                summary: completionRate >= 0.9
                    ? "Round closure is strong enough that the recovery picture is being built from mostly complete scorecards."
                    : "There are still enough saved checkpoints in the sample that the recovery picture needs more complete cards.",
                facts: [
                    .init(title: "Finished Rounds", value: "\(finishedRounds.count)", detail: "Completed scorecards"),
                    .init(title: "Saved Checkpoints", value: "\(unfinishedRounds.count)", detail: "Resumable rounds"),
                    .init(title: "Hole Completion", value: percentage(completionRate), detail: "Across recent rounds")
                ]
            ),
            .init(
                title: "Putting",
                summary: puttsPerHole(for: latest) <= averagePuttsPerHole
                    ? "Putting load in the latest round was at or better than your recent average."
                    : "Putting volume climbed above your recent baseline, which is worth watching.",
                facts: [
                    .init(title: "Latest Putts / Hole", value: formatted(puttsPerHole(for: latest)), detail: "Completed holes only"),
                    .init(title: "Recent Avg", value: formatted(averagePuttsPerHole), detail: "Last \(recentRounds.count) rounds"),
                    .init(title: "Best Round", value: "\(bestFinishedPutting)", detail: "Fewest putts in a finished round")
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

    private static func makeOverviewHighlights(from sections: [StatsSkillSection]) -> [StatsOverviewHighlight] {
        sections.compactMap { section in
            let highlightDetail: String
            switch section.title {
            case "Driving":
                highlightDetail = "latest penalties"
            case "Approach":
                highlightDetail = "recent strokes / hole"
            case "Short Game":
                highlightDetail = "hole completion"
            case "Putting":
                highlightDetail = "recent putts / hole"
            default:
                highlightDetail = "latest signal"
            }

            let sourceFact: StatsFact?
            switch section.title {
            case "Driving":
                sourceFact = section.facts.first
            case "Approach":
                sourceFact = section.facts.dropFirst().first
            case "Short Game":
                sourceFact = section.facts.last
            case "Putting":
                sourceFact = section.facts.dropFirst().first
            default:
                sourceFact = section.facts.first
            }

            guard let fact = sourceFact else {
                return nil
            }

            return StatsOverviewHighlight(
                title: section.title,
                value: fact.value,
                detail: highlightDetail
            )
        }
    }

    private static func makeRecentRoundCard(for summary: RoundHistorySummary) -> StatsRecentRoundCard {
        StatsRecentRoundCard(
            id: summary.id,
            courseName: summary.courseName,
            statusTitle: summary.status == .finished ? "Finished Round" : "Saved to Resume",
            scoreValue: "\(summary.totalStrokes)",
            scoreCaption: "strokes",
            progressLabel: "\(summary.completedHoleCount) / \(summary.totalHoleCount) holes",
            progressValue: progressValue(for: summary),
            metadataPills: [
                "\(summary.totalPutts) putt\(summary.totalPutts == 1 ? "" : "s")",
                "\(summary.totalPenalties) penalt\(summary.totalPenalties == 1 ? "y" : "ies")",
                "\(summary.playerCount) golfer\(summary.playerCount == 1 ? "" : "s")"
            ],
            updatedAt: summary.updatedAt
        )
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else {
            return 0
        }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func progressValue(for summary: RoundHistorySummary) -> Double {
        guard summary.totalHoleCount > 0 else {
            return 0
        }

        return Double(summary.completedHoleCount) / Double(summary.totalHoleCount)
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
