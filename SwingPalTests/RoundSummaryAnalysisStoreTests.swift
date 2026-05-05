import XCTest
@testable import SwingPal

final class RoundSummaryAnalysisStoreTests: XCTestCase {
    func testCacheKeyChangesWhenRoundSummaryMetricsChange() {
        let summary = RoundHistorySummary(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            courseName: "Royal Melbourne",
            status: .unfinished,
            holeNumber: 7,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 27,
            completedHoleCount: 4,
            totalPutts: 6,
            totalPenalties: 2,
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        let firstKey = RoundSummaryAnalysis.CacheKey(summary: summary)

        let changedSummary = RoundHistorySummary(
            id: summary.id,
            courseName: summary.courseName,
            status: summary.status,
            holeNumber: summary.holeNumber,
            totalHoleCount: summary.totalHoleCount,
            playerCount: summary.playerCount,
            totalStrokes: 28,
            completedHoleCount: summary.completedHoleCount,
            totalPutts: summary.totalPutts,
            totalPenalties: summary.totalPenalties,
            updatedAt: summary.updatedAt
        )

        let secondKey = RoundSummaryAnalysis.CacheKey(summary: changedSummary)

        XCTAssertNotEqual(firstKey.rawValue, secondKey.rawValue)
    }

    func testUserDefaultsStoreRoundTripsAnalysis() throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = UserDefaultsRoundSummaryAnalysisStore(defaults: defaults, key: "round-analysis")

        let cached = RoundSummaryAnalysis(
            roundID: UUID(),
            cacheKey: "cache-key",
            provider: .deterministic,
            summary: "Steady scoring so far.",
            whatWentWell: ["Kept penalties down", "Tracked putts cleanly"],
            needsWork: ["Finish more holes", "Tighten iron control"],
            generatedAt: Date(timeIntervalSince1970: 123)
        )

        store.save([cached])

        XCTAssertEqual(store.load(), [cached])
    }
}
