# Round Summary AI Analysis Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a real on-demand AI analysis flow to the Profile `Previous Rounds` summary sheet using Apple `FoundationModels` on-device first, local caching second, and deterministic fallback last.

**Architecture:** Keep the sheet UI simple by moving analysis generation into a local `RoundSummaryAnalysisService`. The service computes a cache key from `RoundHistorySummary`, reads/writes a local persisted analysis cache, tries providers in order, and returns one normalized fixed-structure payload that the sheet renders. The first implementation should ship with `FoundationModels` + deterministic fallback, but the provider protocol must be shaped so a Kimi provider can be inserted later without changing the sheet.

**Tech Stack:** SwiftUI, Foundation, `FoundationModels`, `UserDefaults`, XCTest, existing `AppState` round-history persistence, existing Profile sheet UI in `SwingPal/Features/Profile/ProfileView.swift`.

### Task 1: Add persisted analysis models and storage

**Files:**
- Create: `SwingPal/Features/Profile/Analysis/RoundSummaryAnalysis.swift`
- Modify: `SwingPal/Features/Profile/ProfileViewModel.swift`
- Test: `SwingPalTests/ProfileViewModelTests.swift`
- Test: `SwingPalTests/RoundSummaryAnalysisStoreTests.swift`

**Step 1: Write the failing model/store tests**

Add a new test file `SwingPalTests/RoundSummaryAnalysisStoreTests.swift` with:

```swift
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
```

Extend `SwingPalTests/ProfileViewModelTests.swift` with:

```swift
func testPreviousRoundAnalysisModelCanBeBuiltFromCachedAnalysis() {
    let analysis = RoundSummaryAnalysis(
        roundID: UUID(),
        cacheKey: "cache-key",
        provider: .foundationModels,
        summary: "Your round stayed stable through the saved holes.",
        whatWentWell: ["Short-game logging stayed sharp", "Penalty damage stayed manageable"],
        needsWork: ["Keep the ball in play off the tee", "Convert more saved holes into confirmed holes"],
        generatedAt: .distantPast
    )

    let model = ProfileViewModel.previousRoundAnalysisModel(for: analysis)

    XCTAssertEqual(model.heading, "AI Round Analysis")
    XCTAssertEqual(model.summary, "Your round stayed stable through the saved holes.")
    XCTAssertEqual(model.strengths.count, 2)
    XCTAssertEqual(model.improvements.count, 2)
}
```

**Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedAnalysisTask1Red CODE_SIGNING_ALLOWED=NO
```

Expected: `RoundSummaryAnalysis`, `CacheKey`, and the store types are missing.

**Step 3: Write the minimal implementation**

Create `SwingPal/Features/Profile/Analysis/RoundSummaryAnalysis.swift`:

```swift
import Foundation

struct RoundSummaryAnalysis: Equatable, Codable, Identifiable {
    enum Provider: String, Equatable, Codable {
        case foundationModels
        case deterministic
    }

    struct CacheKey: Equatable, Codable {
        let rawValue: String

        init(summary: RoundHistorySummary) {
            rawValue = [
                summary.id.uuidString,
                summary.status.rawValue,
                "\(summary.holeNumber)",
                "\(summary.totalHoleCount)",
                "\(summary.playerCount)",
                "\(summary.totalStrokes)",
                "\(summary.completedHoleCount)",
                "\(summary.totalPutts)",
                "\(summary.totalPenalties)",
                "\(summary.updatedAt.timeIntervalSince1970)"
            ].joined(separator: "|")
        }
    }

    let roundID: UUID
    let cacheKey: String
    let provider: Provider
    let summary: String
    let whatWentWell: [String]
    let needsWork: [String]
    let generatedAt: Date

    var id: String { "\(roundID.uuidString)|\(cacheKey)" }
}

protocol RoundSummaryAnalysisStoring {
    func load() -> [RoundSummaryAnalysis]
    func save(_ analyses: [RoundSummaryAnalysis])
}

struct UserDefaultsRoundSummaryAnalysisStore: RoundSummaryAnalysisStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "com.ghtech.swingpal.round-summary-analysis") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [RoundSummaryAnalysis] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RoundSummaryAnalysis].self, from: data)) ?? []
    }

    func save(_ analyses: [RoundSummaryAnalysis]) {
        guard let data = try? JSONEncoder().encode(analyses) else { return }
        defaults.set(data, forKey: key)
    }
}
```

Update `ProfileViewModel.PreviousRoundAnalysisModel` in `SwingPal/Features/Profile/ProfileViewModel.swift`:

```swift
struct PreviousRoundAnalysisModel: Equatable {
    let heading: String
    let summary: String
    let strengths: [String]
    let improvements: [String]
}

static func previousRoundAnalysisModel(for analysis: RoundSummaryAnalysis) -> PreviousRoundAnalysisModel {
    .init(
        heading: "AI Round Analysis",
        summary: analysis.summary,
        strengths: analysis.whatWentWell,
        improvements: analysis.needsWork
    )
}
```

Do not remove the current deterministic `previousRoundAnalysisModel(for summary:)` yet; that will be replaced later by the service path.

**Step 4: Run tests to verify they pass**

Run the same build command:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedAnalysisTask1Green CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

**Step 5: Commit**

```bash
git add SwingPal/Features/Profile/Analysis/RoundSummaryAnalysis.swift SwingPal/Features/Profile/ProfileViewModel.swift SwingPalTests/ProfileViewModelTests.swift SwingPalTests/RoundSummaryAnalysisStoreTests.swift
git commit -m "feat: add round summary analysis cache model"
```

### Task 2: Add deterministic fallback generator and orchestrating service

**Files:**
- Create: `SwingPal/Features/Profile/Analysis/RoundSummaryAnalysisService.swift`
- Modify: `SwingPal/Features/Profile/ProfileViewModel.swift`
- Test: `SwingPalTests/RoundSummaryAnalysisServiceTests.swift`

**Step 1: Write the failing service tests**

Create `SwingPalTests/RoundSummaryAnalysisServiceTests.swift` with:

```swift
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
            generatedAt: .distantPast
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
                generatedAt: .distantPast
            )
        ))

        let service = RoundSummaryAnalysisService(store: store, generators: [failing, fallback])

        let result = try await service.analysis(for: summary)

        XCTAssertEqual(result.provider, .deterministic)
        XCTAssertEqual(failing.callCount, 1)
        XCTAssertEqual(fallback.callCount, 1)
        XCTAssertEqual(store.saved.last?.summary, "Fallback summary")
    }
}
```

Include local test doubles in that file:

```swift
private enum StubError: Error { case unavailable }

private final class StubRoundSummaryAnalysisStore: RoundSummaryAnalysisStoring {
    private let initial: [RoundSummaryAnalysis]
    var saved: [RoundSummaryAnalysis] = []

    init(analyses: [RoundSummaryAnalysis] = []) {
        initial = analyses
    }

    func load() -> [RoundSummaryAnalysis] { saved.isEmpty ? initial : saved }
    func save(_ analyses: [RoundSummaryAnalysis]) { saved = analyses }
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
```

**Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedAnalysisTask2Red CODE_SIGNING_ALLOWED=NO
```

Expected: `RoundSummaryAnalysisService` and `RoundSummaryAnalysisGenerating` are missing.

**Step 3: Write the minimal implementation**

Create `SwingPal/Features/Profile/Analysis/RoundSummaryAnalysisService.swift`:

```swift
import Foundation

protocol RoundSummaryAnalysisGenerating {
    func generateAnalysis(for summary: RoundHistorySummary) async throws -> RoundSummaryAnalysis
}

struct DeterministicRoundSummaryAnalysisGenerator: RoundSummaryAnalysisGenerating {
    func generateAnalysis(for summary: RoundHistorySummary) async throws -> RoundSummaryAnalysis {
        let strengths = ProfileViewModel.legacyStrengths(for: summary)
        let improvements = ProfileViewModel.legacyImprovements(for: summary)

        return RoundSummaryAnalysis(
            roundID: summary.id,
            cacheKey: RoundSummaryAnalysis.CacheKey(summary: summary).rawValue,
            provider: .deterministic,
            summary: "This saved round shows a usable snapshot of how the score was moving before you stopped.",
            whatWentWell: strengths,
            needsWork: improvements,
            generatedAt: Date()
        )
    }
}

final class RoundSummaryAnalysisService {
    private let store: RoundSummaryAnalysisStoring
    private let generators: [RoundSummaryAnalysisGenerating]

    init(
        store: RoundSummaryAnalysisStoring = UserDefaultsRoundSummaryAnalysisStore(),
        generators: [RoundSummaryAnalysisGenerating]
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

        throw NSError(domain: "RoundSummaryAnalysisService", code: 1)
    }

    private func persist(_ analysis: RoundSummaryAnalysis) {
        var all = store.load().filter { !($0.roundID == analysis.roundID && $0.cacheKey == analysis.cacheKey) }
        all.insert(analysis, at: 0)
        store.save(all)
    }
}
```

Expose the current deterministic list builders from `ProfileViewModel` as internal helpers:

```swift
static func legacyStrengths(for summary: RoundHistorySummary) -> [String] { ... }
static func legacyImprovements(for summary: RoundHistorySummary) -> [String] { ... }
```

This is temporary. They will stop being “legacy” once the service is in place.

**Step 4: Run tests to verify they pass**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedAnalysisTask2Green CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

**Step 5: Commit**

```bash
git add SwingPal/Features/Profile/Analysis/RoundSummaryAnalysisService.swift SwingPal/Features/Profile/ProfileViewModel.swift SwingPalTests/RoundSummaryAnalysisServiceTests.swift
git commit -m "feat: add round summary analysis service"
```

### Task 3: Add FoundationModels provider with structured output

**Files:**
- Create: `SwingPal/Features/Profile/Analysis/FoundationModelsRoundSummaryAnalyzer.swift`
- Modify: `SwingPal/Features/Profile/Analysis/RoundSummaryAnalysisService.swift`
- Test: `SwingPalTests/FoundationModelsRoundSummaryAnalyzerTests.swift`

**Step 1: Write the failing provider tests**

Create `SwingPalTests/FoundationModelsRoundSummaryAnalyzerTests.swift` with:

```swift
import XCTest
@testable import SwingPal

final class FoundationModelsRoundSummaryAnalyzerTests: XCTestCase {
    func testStructuredPromptModelMapsIntoRoundSummaryAnalysis() async throws {
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

        let session = StubFoundationModelsSession(result: .init(
            summary: "You kept the round organized through the holes you completed.",
            whatWentWell: ["You tracked the short game well.", "You gave yourself a usable scoring baseline."],
            needsWork: ["Penalties were the clearest scoring leak.", "Finishing more holes will strengthen the pattern."]
        ))

        let analyzer = FoundationModelsRoundSummaryAnalyzer(session: session)

        let analysis = try await analyzer.generateAnalysis(for: summary)

        XCTAssertEqual(analysis.provider, .foundationModels)
        XCTAssertEqual(analysis.whatWentWell.count, 2)
        XCTAssertEqual(analysis.needsWork.count, 2)
    }
}
```

**Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedAnalysisTask3Red CODE_SIGNING_ALLOWED=NO
```

Expected: `FoundationModelsRoundSummaryAnalyzer` and `StubFoundationModelsSession` protocol surface are missing.

**Step 3: Write the minimal implementation**

Create `SwingPal/Features/Profile/Analysis/FoundationModelsRoundSummaryAnalyzer.swift`:

```swift
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

struct FoundationModelsRoundSummaryAnalyzer: RoundSummaryAnalysisGenerating {
    private let session: FoundationModelsRoundSummarySessioning

    init(session: FoundationModelsRoundSummarySessioning = LiveFoundationModelsRoundSummarySession()) {
        self.session = session
    }

    func generateAnalysis(for summary: RoundHistorySummary) async throws -> RoundSummaryAnalysis {
        let response = try await session.generate(prompt: makePrompt(for: summary))
        return RoundSummaryAnalysis(
            roundID: summary.id,
            cacheKey: RoundSummaryAnalysis.CacheKey(summary: summary).rawValue,
            provider: .foundationModels,
            summary: response.summary,
            whatWentWell: Array(response.whatWentWell.prefix(2)),
            needsWork: Array(response.needsWork.prefix(2)),
            generatedAt: Date()
        )
    }

    private func makePrompt(for summary: RoundHistorySummary) -> String {
        """
        You are a golf round analyst. Use only the provided facts.
        Return one short summary, two strengths, and two improvement bullets.
        Do not invent shots, clubs, or conditions that were not provided.

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
```

Use `#if canImport(FoundationModels)` inside `LiveFoundationModelsRoundSummarySession` so unsupported environments throw a typed availability error cleanly.

Update the default service construction in `RoundSummaryAnalysisService.swift`:

```swift
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
```

Do not implement Kimi yet. The provider protocol is the extension point.

**Step 4: Run tests to verify they pass**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedAnalysisTask3Green CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

**Step 5: Commit**

```bash
git add SwingPal/Features/Profile/Analysis/FoundationModelsRoundSummaryAnalyzer.swift SwingPal/Features/Profile/Analysis/RoundSummaryAnalysisService.swift SwingPalTests/FoundationModelsRoundSummaryAnalyzerTests.swift
git commit -m "feat: add foundation models round analysis provider"
```

### Task 4: Integrate the service into the profile summary sheet

**Files:**
- Modify: `SwingPal/Features/Profile/ProfileView.swift:656-778`
- Modify: `SwingPal/Features/Profile/ProfileViewModel.swift`
- Test: `SwingPalTests/ProfileViewModelTests.swift`

**Step 1: Write the failing UI-state tests**

Extend `SwingPalTests/ProfileViewModelTests.swift` with:

```swift
func testAnalysisActionLabelsReflectIdleLoadingAndReadyStates() {
    XCTAssertEqual(ProfileViewModel.previousRoundAnalysisButtonTitle(for: .idle), "View Analysis")
    XCTAssertEqual(ProfileViewModel.previousRoundAnalysisButtonTitle(for: .loading), "Analyzing…")
    XCTAssertEqual(ProfileViewModel.previousRoundAnalysisButtonTitle(for: .ready), "Analysis Ready")
}
```

**Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedAnalysisTask4Red CODE_SIGNING_ALLOWED=NO
```

Expected: `previousRoundAnalysisButtonTitle` and sheet state types are missing.

**Step 3: Write the minimal implementation**

In `ProfileViewModel.swift`, add:

```swift
enum PreviousRoundAnalysisState: Equatable {
    case idle
    case loading
    case ready(RoundSummaryAnalysis)
}

static func previousRoundAnalysisButtonTitle(for state: PreviousRoundAnalysisState) -> String {
    switch state {
    case .idle:
        return "View Analysis"
    case .loading:
        return "Analyzing…"
    case .ready:
        return "Analysis Ready"
    }
}
```

In `ProfileView.swift`, update `PreviousRoundSummarySheet`:

- replace `@State private var isShowingAnalysis = false` with:

```swift
@State private var analysisState: ProfileViewModel.PreviousRoundAnalysisState = .idle
@State private var analysisService = RoundSummaryAnalysisService()
```

- on appear, preload cache:

```swift
.task {
    if let cached = analysisService.cachedAnalysis(for: summary) {
        analysisState = .ready(cached)
    }
}
```

- replace the current toggle button with:

```swift
Button {
    switch analysisState {
    case .idle:
        analysisState = .loading
        Task {
            let result = try? await analysisService.analysis(for: summary)
            await MainActor.run {
                if let result {
                    analysisState = .ready(result)
                } else {
                    analysisState = .ready(
                        RoundSummaryAnalysis(
                            roundID: summary.id,
                            cacheKey: RoundSummaryAnalysis.CacheKey(summary: summary).rawValue,
                            provider: .deterministic,
                            summary: "We could not run a richer analysis, so this recap is using the saved round summary only.",
                            whatWentWell: ProfileViewModel.legacyStrengths(for: summary),
                            needsWork: ProfileViewModel.legacyImprovements(for: summary),
                            generatedAt: Date()
                        )
                    )
                }
            }
        }
    case .loading:
        break
    case .ready:
        break
    }
} label: {
    HStack(spacing: 10) {
        if case .loading = analysisState {
            RoundSummaryAnalysisLoadingGlyph()
        }
        Text(ProfileViewModel.previousRoundAnalysisButtonTitle(for: analysisState))
    }
}
.disabled({
    if case .loading = analysisState { return true }
    return false
}())
```

- reveal analysis content only when `analysisState` is `.ready(let analysis)`
- use `ProfileViewModel.previousRoundAnalysisModel(for: analysis)` for rendering

Add a code-native loading animation inside `ProfileView.swift`:

```swift
private struct RoundSummaryAnalysisLoadingGlyph: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.25), lineWidth: 1.5)
                .frame(width: 18, height: 18)

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.green)
                    .frame(width: 4, height: 4)
                    .offset(y: -9)
                    .rotationEffect(.degrees(Double(index) * 120))
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .easeInOut(duration: 1.1)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.08),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}
```

Keep the sheet’s dynamic `Color.primary`, `Color.secondary`, and material-backed rows. Do not regress dark-mode readability.

**Step 4: Run tests to verify they pass**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedAnalysisTask4Green CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

**Step 5: Commit**

```bash
git add SwingPal/Features/Profile/ProfileView.swift SwingPal/Features/Profile/ProfileViewModel.swift SwingPalTests/ProfileViewModelTests.swift
git commit -m "feat: wire cached round analysis into profile sheet"
```

### Task 5: Polish cache replacement and future Kimi insertion point

**Files:**
- Modify: `SwingPal/Features/Profile/Analysis/RoundSummaryAnalysisService.swift`
- Test: `SwingPalTests/RoundSummaryAnalysisServiceTests.swift`
- Optional docs note: `docs/plans/2026-04-27-round-summary-ai-analysis-implementation.md`

**Step 1: Write the failing test**

Add:

```swift
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
        generatedAt: .distantPast
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
            generatedAt: .distantPast
        )
    ))

    let service = RoundSummaryAnalysisService(store: store, generators: [fresh])

    _ = try await service.analysis(for: summary)

    XCTAssertEqual(store.saved.count, 1)
    XCTAssertEqual(store.saved.first?.summary, "Fresh")
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedAnalysisTask5Red CODE_SIGNING_ALLOWED=NO
```

Expected: stale cache replacement is wrong or missing.

**Step 3: Write minimal implementation**

In `RoundSummaryAnalysisService.persist(_:)`, replace all analyses for the same `roundID` before inserting the fresh one:

```swift
var all = store.load().filter { $0.roundID != analysis.roundID }
all.insert(analysis, at: 0)
store.save(all)
```

Add a comment near the default generator construction:

```swift
// Future provider slot: insert Kimi between FoundationModels and deterministic fallback.
```

**Step 4: Run test to verify it passes**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedAnalysisTask5Green CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

**Step 5: Commit**

```bash
git add SwingPal/Features/Profile/Analysis/RoundSummaryAnalysisService.swift SwingPalTests/RoundSummaryAnalysisServiceTests.swift docs/plans/2026-04-27-round-summary-ai-analysis-implementation.md
git commit -m "chore: harden round analysis cache behavior"
```

## Final Verification

After all tasks:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedRoundSummaryAnalysisFinal CODE_SIGNING_ALLOWED=NO
```

Expected:
- `** TEST BUILD SUCCEEDED **`
- no simulator-backed test run
- no regressions in Profile, AppState, or round-history build surfaces

## Notes for Implementation

- Do not launch simulator-backed tests. Use `build-for-testing` only.
- Keep the Profile sheet stats-first. Cached analysis should not auto-expand on first open.
- Use dynamic system colors/material inside the summary sheet. Do not reintroduce `ShellTokens.ColorRole.textPrimary` / `surfacePrimary` there.
- `FoundationModels` output must stay fixed-shape and short. No free-form coaching in this sheet.
- The Home screen coach widget is a separate later feature and should not share this exact response schema.
- Kimi is not implemented in this plan. The provider protocol and service ordering should make the insertion trivial later.
