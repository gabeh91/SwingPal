import XCTest
@testable import SwingPal

final class RoundSummaryAnalysisServiceTests: XCTestCase {
    func testReturnsCachedAnalysisWithoutCallingGenerators() async throws {
        let summary = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .unfinished,
            holeNumber: 7,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 27,
            completedHoleCount: 4,
            totalPutts: 6,
            totalPenalties: 2,
            updatedAt: .distantPast
        )
        let key = RoundSummaryAnalysis.CacheKey(summary: summary).rawValue
        let cached = RoundSummaryAnalysis(
            roundID: summary.id,
            cacheKey: key,
            provider: .deterministic,
            summary: "Cached summary",
            whatWentWell: ["One", "Two"],
            needsWork: ["Three", "Four"],
            generatedAt: .distantPast,
            updatedAt: nil
        )

        let store = StubRoundSummaryAnalysisStore(analyses: [cached])
        let generator = RecordingRoundSummaryAnalysisGenerator(result: .failure(StubError.unavailable))
        let service = RoundSummaryAnalysisService(store: store, generators: [generator])

        let result = try await service.analysis(for: summary)

        XCTAssertEqual(result, cached)
        XCTAssertEqual(generator.callCount, 0)
    }

    func testFallsBackToDeterministicGeneratorAndCachesResult() async throws {
        let summary = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .unfinished,
            holeNumber: 7,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 27,
            completedHoleCount: 4,
            totalPutts: 6,
            totalPenalties: 2,
            updatedAt: .distantPast
        )

        let store = StubRoundSummaryAnalysisStore()
        let failing = RecordingRoundSummaryAnalysisGenerator(result: .failure(StubError.unavailable))
        let fallback = RecordingRoundSummaryAnalysisGenerator(result: .success(
            RoundSummaryAnalysis(
                roundID: summary.id,
                cacheKey: RoundSummaryAnalysis.CacheKey(summary: summary).rawValue,
                provider: .deterministic,
                summary: "Fallback summary",
                whatWentWell: ["One", "Two"],
                needsWork: ["Three", "Four"],
                generatedAt: .distantPast,
                updatedAt: nil
            )
        ))

        let service = RoundSummaryAnalysisService(store: store, generators: [failing, fallback])

        let result = try await service.analysis(for: summary)

        XCTAssertEqual(result.provider, RoundSummaryAnalysis.Provider.deterministic)
        XCTAssertEqual(failing.callCount, 1)
        XCTAssertEqual(fallback.callCount, 1)
        XCTAssertEqual(store.saved.last?.summary, "Fallback summary")
    }

    func testPersistingNewAnalysisReplacesStaleCacheForSameRoundID() async throws {
        let summary = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .unfinished,
            holeNumber: 7,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 27,
            completedHoleCount: 4,
            totalPutts: 6,
            totalPenalties: 2,
            updatedAt: .distantPast
        )

        let stale = RoundSummaryAnalysis(
            roundID: summary.id,
            cacheKey: "old-key",
            provider: .deterministic,
            summary: "Old",
            whatWentWell: ["One", "Two"],
            needsWork: ["Three", "Four"],
            generatedAt: .distantPast,
            updatedAt: nil
        )

        let store = StubRoundSummaryAnalysisStore(analyses: [stale])
        let fresh = RecordingRoundSummaryAnalysisGenerator(result: .success(
            RoundSummaryAnalysis(
                roundID: summary.id,
                cacheKey: RoundSummaryAnalysis.CacheKey(summary: summary).rawValue,
                provider: .deterministic,
                summary: "Fresh",
                whatWentWell: ["One", "Two"],
                needsWork: ["Three", "Four"],
                generatedAt: .distantPast,
                updatedAt: nil
            )
        ))

        let service = RoundSummaryAnalysisService(store: store, generators: [fresh])

        _ = try await service.analysis(for: summary)

        XCTAssertEqual(store.saved.count, 1)
        XCTAssertEqual(store.saved.first?.summary, "Fresh")
    }
}

private enum StubError: Error {
    case unavailable
}

private final class StubRoundSummaryAnalysisStore: RoundSummaryAnalysisStoring {
    private let initial: [RoundSummaryAnalysis]
    var saved: [RoundSummaryAnalysis] = []

    init(analyses: [RoundSummaryAnalysis] = []) {
        initial = analyses
    }

    func load() -> [RoundSummaryAnalysis] {
        saved.isEmpty ? initial : saved
    }

    func save(_ analyses: [RoundSummaryAnalysis]) {
        saved = analyses
    }
}

private final class RecordingRoundSummaryAnalysisGenerator: RoundSummaryAnalysisGenerating {
    let result: Result<RoundSummaryAnalysis, Error>
    private(set) var callCount = 0

    init(result: Result<RoundSummaryAnalysis, Error>) {
        self.result = result
    }

    func generateAnalysis(for summary: RoundHistorySummary) async throws -> RoundSummaryAnalysis {
        callCount += 1
        return try result.get()
    }
}

// MARK: - Caddie's notes from the card

final class RoundRecapWriterTests: XCTestCase {
    /// 9 holes, 38 (+2): birdies on 3 and 8, a double with a penalty and a
    /// three-putt on 7, par saved on 2 after missing the green.
    static func sampleCard() -> [RoundHistorySummary.HoleRecord] {
        [
            .init(number: 1, par: 4, score: 5, putts: 2, fairwayHit: false, greenInRegulation: false),
            .init(number: 2, par: 4, score: 4, putts: 1, fairwayHit: true, greenInRegulation: false),
            .init(number: 3, par: 3, score: 2, putts: 1, greenInRegulation: true),
            .init(number: 4, par: 5, score: 5, putts: 2, fairwayHit: true, greenInRegulation: true),
            .init(number: 5, par: 4, score: 4, putts: 2, fairwayHit: true, greenInRegulation: true),
            .init(number: 6, par: 3, score: 3, putts: 2, greenInRegulation: true),
            .init(number: 7, par: 4, score: 6, putts: 3, penalties: 1, fairwayHit: false, greenInRegulation: false),
            .init(number: 8, par: 5, score: 4, putts: 1, fairwayHit: true, greenInRegulation: false),
            .init(number: 9, par: 4, score: 5, putts: 2, fairwayHit: false, greenInRegulation: false)
        ]
    }

    static func summary(
        _ holes: [RoundHistorySummary.HoleRecord],
        status: RoundHistorySummary.Status = .finished,
        totalHoleCount: Int = 9
    ) -> RoundHistorySummary {
        RoundHistorySummary(
            id: UUID(),
            courseName: "Medway",
            status: status,
            holeNumber: holes.last?.number ?? 1,
            totalHoleCount: totalHoleCount,
            playerCount: 1,
            totalStrokes: holes.reduce(0) { $0 + $1.score },
            completedHoleCount: holes.count,
            totalPutts: holes.reduce(0) { $0 + ($1.putts ?? 0) },
            totalPenalties: holes.reduce(0) { $0 + $1.penalties },
            updatedAt: .distantPast,
            holes: holes
        )
    }

    func testNotesComeFromTheCardAndNameTheHoles() {
        let analysis = RoundRecapWriter.analysis(for: Self.summary(Self.sampleCard()))

        XCTAssertEqual(analysis.provider, .deterministic)
        XCTAssertEqual(analysis.summary, "Shot 38 (2 over) for the 9 holes — 2 birdies, 4 pars, 2 bogeys and 1 double.")
        XCTAssertEqual(analysis.whatWentWell, [
            "Birdies on the 3rd and 8th.",
            "Par or better on 5 holes in a row, the 2nd to the 6th.",
            "Saved par after missing the green on the 2nd."
        ])
        XCTAssertEqual(analysis.needsWork, [
            "Double bogey on the 7th.",
            "A penalty stroke on the 7th.",
            "Three-putt on the 7th."
        ])
    }

    func testEveryNoteCitesAFigureAndNeverTalksAboutTheApp() {
        let analysis = RoundRecapWriter.analysis(for: Self.summary(Self.sampleCard()))
        for line in [analysis.summary] + analysis.whatWentWell + analysis.needsWork {
            XCTAssertTrue(FoundationModelsRoundSummaryAnalyzer.isUsable(line), line)
        }
    }

    func testSaysLessRatherThanPadding() {
        let card: [RoundHistorySummary.HoleRecord] = [
            .init(number: 1, par: 4, score: 5),
            .init(number: 2, par: 4, score: 5),
            .init(number: 3, par: 4, score: 5)
        ]
        let summary = Self.summary(card, status: .unfinished, totalHoleCount: 18)

        XCTAssertEqual(RoundRecapWriter.summaryLine(for: summary), "15 (3 over) through 3 of 18 holes — 3 bogeys.")
        XCTAssertEqual(RoundRecapWriter.strengths(for: summary), [])
        XCTAssertEqual(RoundRecapWriter.needsWork(for: summary), ["The par 4s played 3 over across 3 holes, 1.0 a hole."])
    }

    func testHoleInOneLeadsTheNotes() {
        var card = Self.sampleCard()
        card[2] = .init(number: 3, par: 3, score: 1, putts: 0)
        let analysis = RoundRecapWriter.analysis(for: Self.summary(card))

        XCTAssertEqual(analysis.whatWentWell.first, "Hole in one on the 3rd.")
        XCTAssertTrue(analysis.summary.contains("a hole in one"), analysis.summary)
    }

    func testRoundWithNoScoredHolesSaysSoAndNothingElse() {
        let summary = RoundHistorySummary(
            id: UUID(), courseName: "Medway", status: .unfinished,
            holeNumber: 1, totalHoleCount: 18, playerCount: 1, updatedAt: .distantPast
        )
        let analysis = RoundRecapWriter.analysis(for: summary)
        XCTAssertEqual(analysis.summary, "No holes were scored before this round was saved.")
        XCTAssertEqual(analysis.whatWentWell, [])
        XCTAssertEqual(analysis.needsWork, [])
    }

    func testHoleNamesReadLikeACaddie() {
        XCTAssertEqual(RoundRecapWriter.ordinal(1), "the 1st")
        XCTAssertEqual(RoundRecapWriter.ordinal(2), "the 2nd")
        XCTAssertEqual(RoundRecapWriter.ordinal(3), "the 3rd")
        XCTAssertEqual(RoundRecapWriter.ordinal(11), "the 11th")
        XCTAssertEqual(RoundRecapWriter.ordinal(12), "the 12th")
        XCTAssertEqual(RoundRecapWriter.ordinal(13), "the 13th")
        XCTAssertEqual(RoundRecapWriter.holeList([3, 7, 12]), "the 3rd, 7th and 12th")
    }

    // MARK: Around the green

    func testUpAndDownsAndSandSavesAreNamedByHole() {
        let card: [RoundHistorySummary.HoleRecord] = [
            .init(number: 1, par: 4, score: 4, putts: 1, greenInRegulation: false, shortGameShots: 1, upAndDown: true),
            .init(number: 2, par: 4, score: 5, putts: 2, greenInRegulation: false, shortGameShots: 1, upAndDown: false),
            .init(number: 3, par: 3, score: 3, putts: 1, greenInRegulation: false, shortGameShots: 1, upAndDown: true, sandSave: true),
            .init(number: 4, par: 4, score: 5, putts: 2, greenInRegulation: true)
        ]
        let strengths = RoundRecapWriter.strengths(for: Self.summary(card))

        XCTAssertEqual(Array(strengths.prefix(2)), [
            "Up and down 1 time from 2 chances: the 1st.",
            "Sand save on the 3rd."
        ])
        let savedPar = strengths.filter { $0.hasPrefix("Saved par") }
        XCTAssertEqual(savedPar, [], "The up-and-down already says it")
    }

    func testEveryUpAndDownMadeReadsAsAClearRun() {
        let card: [RoundHistorySummary.HoleRecord] = [
            .init(number: 1, par: 4, score: 5, putts: 1, shortGameShots: 1, upAndDown: true),
            .init(number: 2, par: 4, score: 6, putts: 2),
            .init(number: 3, par: 4, score: 5, putts: 1, shortGameShots: 1, upAndDown: true)
        ]
        let strengths = RoundRecapWriter.strengths(for: Self.summary(card))
        XCTAssertEqual(strengths.first, "Up and down all 2 times: the 1st and 3rd.")
    }

    func testAChipInIsNotCountedAgainAsAnUpAndDown() {
        let card: [RoundHistorySummary.HoleRecord] = [
            .init(number: 1, par: 4, score: 5, putts: 2),
            .init(number: 2, par: 4, score: 3, putts: 0, shortGameShots: 1, upAndDown: true, chippedIn: true),
            .init(number: 3, par: 4, score: 5, putts: 2)
        ]
        let strengths = RoundRecapWriter.strengths(for: Self.summary(card))

        XCTAssertEqual(Array(strengths.prefix(2)), [
            "Birdie on the 2nd.",
            "Holed out from off the green on the 2nd."
        ])
        let upAndDownLines = strengths.filter { $0.hasPrefix("Up and down") }
        XCTAssertEqual(upAndDownLines, [])
    }

    func testExtraShotsAroundTheGreenAndMissedUpAndDownsNeedWork() {
        let card: [RoundHistorySummary.HoleRecord] = [
            .init(number: 1, par: 4, score: 6, putts: 2, shortGameShots: 3, upAndDown: false),
            .init(number: 2, par: 4, score: 5, putts: 2, shortGameShots: 1, upAndDown: false),
            .init(number: 3, par: 4, score: 5, putts: 2, shortGameShots: 1, upAndDown: false)
        ]
        let needs = RoundRecapWriter.needsWork(for: Self.summary(card))

        XCTAssertEqual(needs, [
            "Double bogey on the 1st, 2 of the 4 over par.",
            "Needed 3 shots around the green on the 1st.",
            "No up-and-downs from 3 chances."
        ])
    }

    func testBunkersWithNoSaveNeedWork() {
        let card: [RoundHistorySummary.HoleRecord] = [
            .init(number: 1, par: 4, score: 5, shortGameShots: 1, upAndDown: false, sandSave: false),
            .init(number: 2, par: 3, score: 4, shortGameShots: 1, upAndDown: false, sandSave: false)
        ]
        let needs = RoundRecapWriter.needsWork(for: Self.summary(card))
        XCTAssertEqual(needs.first, "No sand saves from 2 bunkers.")
    }

    func testShortGameNotesCiteAFigureAndStayOnTheGolf() {
        let lines: [String] = [
            "Up and down 1 time from 2 chances: the 1st.",
            "Up and down all 2 times: the 1st and 3rd.",
            "Up and down on the 4th.",
            "Sand save on the 3rd.",
            "Holed out from off the green on the 2nd.",
            "Needed 3 shots around the green on the 1st.",
            "No up-and-downs from 3 chances.",
            "No sand saves from 2 bunkers."
        ]
        for line in lines {
            XCTAssertTrue(FoundationModelsRoundSummaryAnalyzer.isUsable(line), line)
        }
    }

    func testNotesWrittenUnderTheOldRulesAreNotReused() {
        let summary = Self.summary(Self.sampleCard())
        XCTAssertTrue(RoundSummaryAnalysis.CacheKey(summary: summary).rawValue.hasPrefix(RoundSummaryAnalysis.CacheKey.version + "|"))
    }
}

// MARK: - Around the green, read from the logged shots

final class HoleShortGameSummaryTests: XCTestCase {
    private func hole(_ shots: [ShotEvent]) -> HoleSession {
        var hole = HoleSession(number: 1, par: 4)
        hole.shots = shots
        return hole
    }

    private var drive: ShotEvent {
        ShotEvent(clubName: "Driver", distanceToTargetMeters: 380, strokeNumber: 1, surface: .tee)
    }

    private var approach: ShotEvent {
        ShotEvent(clubName: "8i", distanceToTargetMeters: 140, strokeNumber: 2, surface: .fairway)
    }

    private func chip(
        _ type: ShotEvent.ShotType = .chip,
        from surface: ShotEvent.Surface = .rough,
        holed: Bool = false
    ) -> ShotEvent {
        ShotEvent(
            clubName: type == .fringePutt ? "Putter" : "SW",
            distanceToTargetMeters: 15,
            surface: surface,
            shotType: type,
            holedOut: holed,
            shortGameResult: holed ? .holed : nil
        )
    }

    private func putts(_ count: Int) -> ShotEvent {
        ShotEvent(
            clubName: "Putter",
            distanceToTargetMeters: 0,
            surface: .green,
            shotType: .putt,
            puttDetail: .init(puttCount: count, holed: true, puttsTogether: count)
        )
    }

    func testNoShotAroundTheGreenMeansNothingToSay() {
        XCTAssertNil(hole([drive, approach, putts(2)]).shortGameSummary)
    }

    func testAChipAndAPuttIsUpAndDown() throws {
        let summary = try XCTUnwrap(hole([drive, approach, chip(), putts(1)]).shortGameSummary)
        XCTAssertEqual(summary.shots, 1)
        XCTAssertFalse(summary.fromSand)
        XCTAssertFalse(summary.chippedIn)
        XCTAssertEqual(summary.upAndDown, true)
    }

    func testABunkerShotAndTwoPuttsIsNoSandSave() throws {
        let summary = try XCTUnwrap(hole([drive, approach, chip(.bunkerShot, from: .bunker), putts(2)]).shortGameSummary)
        XCTAssertTrue(summary.fromSand)
        XCTAssertEqual(summary.upAndDown, false)
    }

    func testTwoChipsAndAPuttIsNotUpAndDown() throws {
        let summary = try XCTUnwrap(hole([drive, approach, chip(), chip(), putts(1)]).shortGameSummary)
        XCTAssertEqual(summary.shots, 2)
        XCTAssertEqual(summary.upAndDown, false)
    }

    func testAChipInCounts() throws {
        let summary = try XCTUnwrap(hole([drive, approach, chip(holed: true)]).shortGameSummary)
        XCTAssertTrue(summary.chippedIn)
        XCTAssertEqual(summary.upAndDown, true)
    }

    func testAChipWithNothingAfterItSaysNothingAboutGettingDown() throws {
        let summary = try XCTUnwrap(hole([drive, approach, chip()]).shortGameSummary)
        XCTAssertEqual(summary.shots, 1)
        XCTAssertNil(summary.upAndDown)
    }

    func testThePutterFromOffTheGreenIsAShotAroundTheGreenNotAPutt() throws {
        let played = hole([drive, approach, chip(.fringePutt, from: .fairway), putts(1)])
        let summary = try XCTUnwrap(played.shortGameSummary)

        XCTAssertEqual(summary.shots, 1)
        XCTAssertEqual(summary.upAndDown, true)
        XCTAssertEqual(played.totalScore, 4)
        XCTAssertEqual(LiveRoundState.derivedPuttCount(for: played), 1, "Only the one on the green is a putt")
    }

    func testAnEnteredScoreTheShotsDoNotAddUpToLeavesItUnknown() throws {
        var played = hole([drive, approach, chip(), putts(1)])
        played.recordedScore = 4
        played.recordedPutts = 1
        XCTAssertEqual(played.shortGameSummary?.upAndDown, true)

        // A stroke went unlogged somewhere, so there's no telling where.
        played.recordedScore = 5
        let summary = try XCTUnwrap(played.shortGameSummary)
        XCTAssertNil(summary.upAndDown)
    }

    func testPuttsCountedOnTheCardDecideItWhenNoneWereLogged() throws {
        var played = hole([drive, approach, chip()])
        played.recordedScore = 5
        played.recordedPutts = 2
        XCTAssertEqual(played.shortGameSummary?.upAndDown, false)
    }
}
