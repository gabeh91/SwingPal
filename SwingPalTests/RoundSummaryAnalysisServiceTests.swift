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
