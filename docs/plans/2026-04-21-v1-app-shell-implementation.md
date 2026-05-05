# SwingPal V1 App Shell Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the placeholder SwiftUI screen with a production-ready v1 application shell that implements the agreed navigation model, round setup flow, live round scaffold, profile/bag area, and auth/premium gating foundations.

**Architecture:** Build the app around a small shared state core with `AppState` coordinating tab selection, auth state, and active round context. Feature modules should live under `SwingPal/Features/` with lightweight state models that are testable in `SwingPalTests/`. Keep intelligence and entitlement decisions in normalized models so future iPhone, Apple Watch, and premium features can reuse the same logic.

**Tech Stack:** SwiftUI, XCTest, iOS 17, Swift 6 toolchain in Xcode 16.2, native Xcode project (`SwingPal.xcodeproj`)

**Implementation rules:** Follow @superpowers:test-driven-development for all stateful logic. Before claiming completion, follow @superpowers:verification-before-completion and run the listed `xcodebuild` commands.

## Pre-flight

- Read `docs/plans/2026-04-21-product-flow-design.md`
- Read `docs/iterations/2026-04-21-iteration-log.md`
- Keep changes scoped to the app shell and mocked data only
- Do not add networking, Supabase SDKs, or Apple Watch targets in this pass

### Task 1: Establish the app shell state and tab routing

**Files:**
- Create: `SwingPal/App/AppTab.swift`
- Create: `SwingPal/App/AuthState.swift`
- Create: `SwingPal/App/AppState.swift`
- Create: `SwingPal/App/AppShellView.swift`
- Modify: `SwingPal/SwingPalApp.swift`
- Modify: `SwingPal/ContentView.swift`
- Modify: `SwingPal.xcodeproj/project.pbxproj`
- Test: `SwingPalTests/AppStateTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import SwingPal

final class AppStateTests: XCTestCase {
    func testInitialStateDefaultsToHomeGuestAndNoActiveRound() {
        let state = AppState()

        XCTAssertEqual(state.selectedTab, .home)
        XCTAssertEqual(state.authState, .guest)
        XCTAssertNil(state.activeRoundID)
    }
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SwingPalTests/AppStateTests
```

Expected: FAIL because `AppState`, `AppTab`, and `AuthState` do not exist yet.

**Step 3: Write minimal implementation**

```swift
enum AppTab: Hashable {
    case home
    case social
    case round
    case profile
}

enum AuthState: Equatable {
    case guest
    case authenticated
}

@Observable
final class AppState {
    var selectedTab: AppTab = .home
    var authState: AuthState = .guest
    var activeRoundID: UUID?
}
```

```swift
import SwiftUI

struct AppShellView: View {
    @State private var appState = AppState()

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            Text("Home")
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            Text("Social")
                .tabItem { Label("Social", systemImage: "person.2") }
                .tag(AppTab.social)

            Text("Round")
                .tabItem { Label("Round", systemImage: "flag.filled.and.flag.crossed") }
                .tag(AppTab.round)

            Text("Profile")
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
    }
}
```

Update `SwingPalApp` and `ContentView` so the entry point renders `AppShellView`.

**Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command.

Expected: PASS for `AppStateTests`.

**Step 5: Commit**

```bash
git add SwingPal/App SwingPal/SwingPalApp.swift SwingPal/ContentView.swift SwingPal.xcodeproj/project.pbxproj SwingPalTests/AppStateTests.swift
git commit -m "feat: add app shell state and tab routing"
```

### Task 2: Build the Home command-center scaffold

**Files:**
- Create: `SwingPal/Features/Home/HomeView.swift`
- Create: `SwingPal/Features/Home/HomeViewModel.swift`
- Create: `SwingPal/Features/Home/HomeModule.swift`
- Create: `SwingPal/Features/Home/HomeInsight.swift`
- Create: `SwingPal/Features/Home/HomeHeroCard.swift`
- Modify: `SwingPal/App/AppShellView.swift`
- Modify: `SwingPal.xcodeproj/project.pbxproj`
- Test: `SwingPalTests/HomeViewModelTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import SwingPal

final class HomeViewModelTests: XCTestCase {
    func testResumeHeroAppearsBeforeInsightsWhenRoundIsActive() {
        let model = HomeViewModel(
            activeRoundTitle: "Royal Melbourne",
            recentRounds: [],
            insights: [.mock]
        )

        XCTAssertEqual(model.heroTitle, "Resume Round")
        XCTAssertEqual(model.modules, [.insights, .recentRounds, .nearbyCourses])
    }
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SwingPalTests/HomeViewModelTests
```

Expected: FAIL because `HomeViewModel`, `HomeModule`, and `HomeInsight` do not exist.

**Step 3: Write minimal implementation**

```swift
enum HomeModule: Equatable {
    case insights
    case recentRounds
    case nearbyCourses
}

struct HomeInsight: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String

    static let mock = HomeInsight(
        title: "Approach play cost you 4 shots",
        detail: "Your last two rounds lost the most strokes between 110m and 150m."
    )
}

struct HomeViewModel {
    let heroTitle: String
    let heroSubtitle: String
    let modules: [HomeModule]
    let insights: [HomeInsight]

    init(activeRoundTitle: String?, recentRounds: [String], insights: [HomeInsight]) {
        heroTitle = activeRoundTitle == nil ? "Start Round" : "Resume Round"
        heroSubtitle = activeRoundTitle ?? "Pick a nearby course and begin."
        modules = [.insights, .recentRounds, .nearbyCourses]
        self.insights = insights
    }
}
```

Build `HomeView` as a scrollable command center with:

- a hero card at the top
- one featured insight card
- placeholder sections for recent rounds and nearby courses

**Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command.

Expected: PASS for `HomeViewModelTests`.

**Step 5: Commit**

```bash
git add SwingPal/Features/Home SwingPal/App/AppShellView.swift SwingPal.xcodeproj/project.pbxproj SwingPalTests/HomeViewModelTests.swift
git commit -m "feat: scaffold home command center"
```

### Task 3: Add the Social feed scaffold

**Files:**
- Create: `SwingPal/Features/Social/SocialView.swift`
- Create: `SwingPal/Features/Social/SocialPost.swift`
- Create: `SwingPal/Features/Social/SocialFeedBuilder.swift`
- Create: `SwingPal/Features/Social/SocialPostCard.swift`
- Modify: `SwingPal/App/AppShellView.swift`
- Modify: `SwingPal.xcodeproj/project.pbxproj`
- Test: `SwingPalTests/SocialFeedBuilderTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import SwingPal

final class SocialFeedBuilderTests: XCTestCase {
    func testBuildRoundSummaryUsesStructuredRoundResult() {
        let post = SocialFeedBuilder.makeRoundSummary(
            playerName: "Gabe",
            courseName: "Royal Melbourne",
            scoreSummary: "+6"
        )

        XCTAssertEqual(post.title, "Gabe played Royal Melbourne")
        XCTAssertEqual(post.scoreSummary, "+6")
    }
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SwingPalTests/SocialFeedBuilderTests
```

Expected: FAIL because `SocialFeedBuilder` and `SocialPost` do not exist.

**Step 3: Write minimal implementation**

```swift
struct SocialPost: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let scoreSummary: String
}

enum SocialFeedBuilder {
    static func makeRoundSummary(
        playerName: String,
        courseName: String,
        scoreSummary: String
    ) -> SocialPost {
        SocialPost(
            title: "\(playerName) played \(courseName)",
            subtitle: "Round summary",
            scoreSummary: scoreSummary
        )
    }
}
```

Use this to populate a mocked `SocialView` with a short list of friend round posts.

**Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command.

Expected: PASS for `SocialFeedBuilderTests`.

**Step 5: Commit**

```bash
git add SwingPal/Features/Social SwingPal/App/AppShellView.swift SwingPal.xcodeproj/project.pbxproj SwingPalTests/SocialFeedBuilderTests.swift
git commit -m "feat: add social feed scaffold"
```

### Task 4: Implement the Round setup flow

**Files:**
- Create: `SwingPal/Features/Round/Models/CourseSummary.swift`
- Create: `SwingPal/Features/Round/Models/CourseDetail.swift`
- Create: `SwingPal/Features/Round/Models/RoundPlayerDraft.swift`
- Create: `SwingPal/Features/Round/RoundSetupState.swift`
- Create: `SwingPal/Features/Round/RoundRootView.swift`
- Create: `SwingPal/Features/Round/CourseListView.swift`
- Create: `SwingPal/Features/Round/CourseDetailView.swift`
- Create: `SwingPal/Features/Round/PlayerSelectionView.swift`
- Create: `SwingPal/Features/Round/AddGuestPlayerSheet.swift`
- Modify: `SwingPal/App/AppShellView.swift`
- Modify: `SwingPal.xcodeproj/project.pbxproj`
- Test: `SwingPalTests/RoundSetupStateTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import SwingPal

final class RoundSetupStateTests: XCTestCase {
    func testCoursesAreSortedByAscendingDistance() {
        let state = RoundSetupState(courses: [
            .init(name: "Course B", distanceKilometers: 12.0),
            .init(name: "Course A", distanceKilometers: 3.5)
        ])

        XCTAssertEqual(state.sortedCourses.map(\.name), ["Course A", "Course B"])
    }

    func testAddingGuestPlayerCreatesGuestDraft() {
        var state = RoundSetupState(courses: [])

        state.addGuest(named: "Ben")

        XCTAssertEqual(state.players.last?.name, "Ben")
        XCTAssertEqual(state.players.last?.kind, .guest)
    }
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SwingPalTests/RoundSetupStateTests
```

Expected: FAIL because `RoundSetupState`, `CourseSummary`, and `RoundPlayerDraft` do not exist.

**Step 3: Write minimal implementation**

```swift
struct CourseSummary: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let distanceKilometers: Double
}

struct RoundPlayerDraft: Identifiable, Equatable {
    enum Kind: Equatable {
        case selfPlayer
        case guest
    }

    let id = UUID()
    let name: String
    let kind: Kind
}

@Observable
final class RoundSetupState {
    var courses: [CourseSummary]
    var selectedCourse: CourseSummary?
    var players: [RoundPlayerDraft] = [
        .init(name: "You", kind: .selfPlayer)
    ]

    init(courses: [CourseSummary]) {
        self.courses = courses
    }

    var sortedCourses: [CourseSummary] {
        courses.sorted { $0.distanceKilometers < $1.distanceKilometers }
    }

    func addGuest(named name: String) {
        players.append(.init(name: name, kind: .guest))
    }
}
```

Build the flow as:

- nearby course list sorted nearest first
- course detail with tees and yardages
- player selection with guest add sheet
- a `Start Round` CTA that opens the live round scaffold

**Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command.

Expected: PASS for `RoundSetupStateTests`.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round SwingPal/App/AppShellView.swift SwingPal.xcodeproj/project.pbxproj SwingPalTests/RoundSetupStateTests.swift
git commit -m "feat: add round setup flow scaffold"
```

### Task 5: Add the live round HUD scaffold and round review flow

**Files:**
- Create: `SwingPal/Features/Round/Models/HoleSession.swift`
- Create: `SwingPal/Features/Round/Models/ShotEvent.swift`
- Create: `SwingPal/Features/Round/Models/PlayerScoreState.swift`
- Create: `SwingPal/Features/Round/LiveRoundState.swift`
- Create: `SwingPal/Features/Round/LiveRoundView.swift`
- Create: `SwingPal/Features/Round/HUD/DistanceHUDView.swift`
- Create: `SwingPal/Features/Round/HUD/ClubHUDView.swift`
- Create: `SwingPal/Features/Round/HUD/HoleInfoHUDView.swift`
- Create: `SwingPal/Features/Round/RoundReviewView.swift`
- Modify: `SwingPal.xcodeproj/project.pbxproj`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import SwingPal

final class LiveRoundStateTests: XCTestCase {
    func testLoggingShotAppendsShotAndIncrementsStrokeCount() {
        let hole = HoleSession(number: 1, par: 4)
        let state = LiveRoundState(hole: hole)

        state.logShot(clubName: "7i", distanceToTargetMeters: 152)

        XCTAssertEqual(state.hole.shots.count, 1)
        XCTAssertEqual(state.hole.strokeCount, 1)
    }
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SwingPalTests/LiveRoundStateTests
```

Expected: FAIL because `HoleSession`, `ShotEvent`, and `LiveRoundState` do not exist.

**Step 3: Write minimal implementation**

```swift
struct ShotEvent: Identifiable, Equatable {
    let id = UUID()
    let clubName: String
    let distanceToTargetMeters: Int
}

struct HoleSession: Equatable {
    let number: Int
    let par: Int
    var shots: [ShotEvent] = []

    var strokeCount: Int {
        shots.count
    }
}

@Observable
final class LiveRoundState {
    var hole: HoleSession

    init(hole: HoleSession) {
        self.hole = hole
    }

    func logShot(clubName: String, distanceToTargetMeters: Int) {
        hole.shots.append(.init(
            clubName: clubName,
            distanceToTargetMeters: distanceToTargetMeters
        ))
    }
}
```

Build `LiveRoundView` around:

- a map-style hero surface placeholder
- edge HUD modules for distance, club, and hole info
- bottom actions for shot logging and score entry
- a `Finish Hole` path into `RoundReviewView`

**Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command.

Expected: PASS for `LiveRoundStateTests`.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round SwingPal.xcodeproj/project.pbxproj SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: add live round hud scaffold"
```

### Task 6: Add Profile, Bag, and free intelligence scaffolding

**Files:**
- Create: `SwingPal/Features/Profile/ProfileView.swift`
- Create: `SwingPal/Features/Profile/BagView.swift`
- Create: `SwingPal/Features/Profile/Models/Club.swift`
- Create: `SwingPal/Features/Profile/Models/Bag.swift`
- Create: `SwingPal/Features/Profile/BagClubRecommendation.swift`
- Modify: `SwingPal/App/AppShellView.swift`
- Modify: `SwingPal.xcodeproj/project.pbxproj`
- Test: `SwingPalTests/BagClubRecommendationTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import SwingPal

final class BagClubRecommendationTests: XCTestCase {
    func testRecommendationExplainsSuggestionUsingBagDistance() {
        let bag = Bag(clubs: [
            .init(name: "7i", typicalDistanceMeters: 145),
            .init(name: "6i", typicalDistanceMeters: 158)
        ])

        let recommendation = BagClubRecommendation.make(
            bag: bag,
            playsLikeDistanceMeters: 160
        )

        XCTAssertEqual(recommendation.clubName, "6i")
        XCTAssertEqual(
            recommendation.reason,
            "Your 6i average is 158m and this shot plays like 160m."
        )
    }
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SwingPalTests/BagClubRecommendationTests
```

Expected: FAIL because `Bag`, `Club`, and `BagClubRecommendation` do not exist.

**Step 3: Write minimal implementation**

```swift
struct Club: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let typicalDistanceMeters: Int
}

struct Bag: Equatable {
    let clubs: [Club]
}

struct BagClubRecommendation: Equatable {
    let clubName: String
    let reason: String

    static func make(bag: Bag, playsLikeDistanceMeters: Int) -> Self {
        let club = bag.clubs.min {
            abs($0.typicalDistanceMeters - playsLikeDistanceMeters) <
            abs($1.typicalDistanceMeters - playsLikeDistanceMeters)
        } ?? .init(name: "Unknown", typicalDistanceMeters: 0)

        return Self(
            clubName: club.name,
            reason: "Your \(club.name) average is \(club.typicalDistanceMeters)m and this shot plays like \(playsLikeDistanceMeters)m."
        )
    }
}
```

Use the result in `ProfileView` and `BagView` to preview the free intelligence tone.

**Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command.

Expected: PASS for `BagClubRecommendationTests`.

**Step 5: Commit**

```bash
git add SwingPal/Features/Profile SwingPal/App/AppShellView.swift SwingPal.xcodeproj/project.pbxproj SwingPalTests/BagClubRecommendationTests.swift
git commit -m "feat: add profile and bag scaffold"
```

### Task 7: Add auth and premium gate resolution

**Files:**
- Create: `SwingPal/Features/Auth/AuthGateView.swift`
- Create: `SwingPal/Features/Premium/PremiumFeature.swift`
- Create: `SwingPal/Features/Premium/EntitlementState.swift`
- Create: `SwingPal/Features/Premium/GatedActionResolver.swift`
- Modify: `SwingPal/App/AppState.swift`
- Modify: `SwingPal/Features/Home/HomeView.swift`
- Modify: `SwingPal/Features/Profile/ProfileView.swift`
- Modify: `SwingPal.xcodeproj/project.pbxproj`
- Test: `SwingPalTests/GatedActionResolverTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import SwingPal

final class GatedActionResolverTests: XCTestCase {
    func testGuestSavingRoundRequiresAuth() {
        let resolver = GatedActionResolver(
            authState: .guest,
            entitlements: .free
        )

        XCTAssertEqual(resolver.requirement(for: .saveRound), .signIn)
    }

    func testFreeUserOpeningWatchCompanionRequiresPremium() {
        let resolver = GatedActionResolver(
            authState: .authenticated,
            entitlements: .free
        )

        XCTAssertEqual(resolver.requirement(for: .openWatchCompanion), .premium)
    }
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SwingPalTests/GatedActionResolverTests
```

Expected: FAIL because `GatedActionResolver`, `EntitlementState`, and `PremiumFeature` do not exist.

**Step 3: Write minimal implementation**

```swift
enum EntitlementState: Equatable {
    case free
    case premium
}

enum GatedAction {
    case saveRound
    case openWatchCompanion
}

enum GateRequirement: Equatable {
    case none
    case signIn
    case premium
}

struct GatedActionResolver {
    let authState: AuthState
    let entitlements: EntitlementState

    func requirement(for action: GatedAction) -> GateRequirement {
        switch action {
        case .saveRound:
            authState == .guest ? .signIn : .none
        case .openWatchCompanion:
            entitlements == .premium ? .none : .premium
        }
    }
}
```

Wire placeholder gates into:

- save or sync affordances
- premium callouts for Apple Watch and deeper intelligence

**Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command.

Expected: PASS for `GatedActionResolverTests`.

**Step 5: Commit**

```bash
git add SwingPal/Features/Auth SwingPal/Features/Premium SwingPal/App/AppState.swift SwingPal/Features/Home/HomeView.swift SwingPal/Features/Profile/ProfileView.swift SwingPal.xcodeproj/project.pbxproj SwingPalTests/GatedActionResolverTests.swift
git commit -m "feat: add auth and premium gate scaffolding"
```

### Task 8: Final integration and verification

**Files:**
- Modify: `SwingPal/ContentView.swift`
- Modify: `SwingPal/App/AppShellView.swift`
- Modify: `docs/iterations/2026-04-21-iteration-log.md`

**Step 1: Write the failing test**

Add one integration-oriented unit test to confirm the shell still boots into the expected tab flow:

```swift
import XCTest
@testable import SwingPal

final class ShellIntegrationTests: XCTestCase {
    func testRoundTabCanBeSelectedFromInitialState() {
        let state = AppState()

        state.selectedTab = .round

        XCTAssertEqual(state.selectedTab, .round)
    }
}
```

**Step 2: Run test to verify it fails**

If it already passes immediately, replace it with a stricter assertion on any new integration rule introduced in Tasks 1-7. Do not keep a test that proved nothing.

**Step 3: Write minimal implementation**

- Finish any remaining wiring between tabs and screens
- Remove the old placeholder-only content
- Update the iteration log with implementation notes

**Step 4: Run test suite and build verification**

Run:

```bash
xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS for all tests.

Run:

```bash
xcodebuild build -project SwingPal.xcodeproj -scheme SwingPal -destination 'generic/platform=iOS Simulator'
```

Expected: `** BUILD SUCCEEDED **`

**Step 5: Commit**

```bash
git add SwingPal SwingPalTests docs/iterations/2026-04-21-iteration-log.md SwingPal.xcodeproj/project.pbxproj
git commit -m "feat: implement v1 app shell scaffold"
```

## Notes for the Implementer

- Keep the first pass on mocked data; do not couple the shell to remote APIs yet
- Prefer pure Swift models for logic so XCTest can cover them cleanly
- Use iOS 17 SwiftUI presentation and navigation APIs where they materially improve polish
- Preserve the agreed product hierarchy:
  - `Home` = personal command center
  - `Social` = friend round updates
  - `Round` = emphasized center tab
  - `Profile` = account, bag, settings

Plan complete and saved to `docs/plans/2026-04-21-v1-app-shell-implementation.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
