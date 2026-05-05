# Live Round Clean-Room Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebuild the active `Live Round` flow on top of the working clean-room screen so it matches the new map-first design: bounded satellite map, premium top strip, draggable launcher sheet, anchored club wheel, structured logger, hole confirmation, and app-side watch-sync preparation.

**Architecture:** Keep `FreshLiveRoundScreen` as the active live-round entry point and move complexity into `LiveRoundState` plus small supporting models so the SwiftUI view remains thin and trustworthy. Add phone UX in layered slices: state first, then map interactions, then launcher surfaces, then modal flows, then sync plumbing.

**Tech Stack:** SwiftUI, MapKit, CoreLocation, Combine, XCTest, iOS 17, native Xcode project (`SwingPal.xcodeproj`)

**Implementation rules:**
- Follow @superpowers:test-driven-development for every stateful change.
- Do not revive or patch the old `LiveRoundView` path.
- Keep `FreshLiveRoundScreen` as the routed live entry point during the whole rebuild.
- Before claiming completion, follow @superpowers:verification-before-completion and run the verification commands listed at the end of this plan.
- There is currently no watch target in this repo. Implement app-side sync abstractions and payloads only; do not invent a watch UI target in this plan.

## Pre-Flight

- Read `docs/plans/2026-04-23-live-round-clean-room-design.md`
- Read `docs/iterations/2026-04-21-iteration-log.md`
- Read `SwingPal/Features/Round/FreshLiveRoundScreen.swift`
- Read `SwingPal/Features/Round/LiveRoundState.swift`
- Keep the current fresh-screen button path working at every step

## Task 1: Add logger mode preference to app/profile state

**Files:**
- Modify: `SwingPal/App/AppState.swift`
- Modify: `SwingPal/Features/Profile/ProfileViewModel.swift`
- Modify: `SwingPal/Features/Profile/ProfileView.swift`
- Test: `SwingPalTests/ProfileViewModelTests.swift`
- Test: `SwingPalTests/AppStateTests.swift`

**Step 1: Write the failing tests**

Add a new app preference enum and test expectations:

```swift
func testLoggerModeDefaultsToBasic() {
    let state = AppState(
        store: InMemoryActiveRoundStore(),
        gpsModeStore: InMemoryGPSModeStore(),
        appearanceModeStore: InMemoryAppearanceModeStore(),
        liveRoundLoggerModeStore: InMemoryLiveRoundLoggerModeStore()
    )

    XCTAssertEqual(state.liveRoundLoggerMode, .basic)
}
```

```swift
func testProfileViewModelDescribesLiveRoundLoggingPreference() {
    let model = ProfileViewModel(
        authState: .authenticated,
        entitlements: .premium,
        bag: .mock,
        gpsMode: .live,
        loggerMode: .advanced
    )

    XCTAssertEqual(model.loggerModeTitle, "Shot Logging")
    XCTAssertEqual(model.loggerModeSubtitle, "Choose the default live round logging flow and still switch modes mid-round.")
}
```

**Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO
```

Expected: build/test failure because logger mode storage and profile copy do not exist.

**Step 3: Write minimal implementation**

Add a preference enum and store in `AppState.swift`:

```swift
enum LiveRoundLoggerMode: String, Equatable, Codable {
    case basic
    case advanced
}
```

Add store protocol and default user defaults implementation:

```swift
protocol LiveRoundLoggerModeStoring {
    func loadLiveRoundLoggerMode() -> LiveRoundLoggerMode
    func saveLiveRoundLoggerMode(_ mode: LiveRoundLoggerMode)
}
```

Expose:

```swift
@Published var liveRoundLoggerMode: LiveRoundLoggerMode

func setLiveRoundLoggerMode(_ mode: LiveRoundLoggerMode) {
    guard liveRoundLoggerMode != mode else { return }
    liveRoundLoggerMode = mode
    liveRoundLoggerModeStore.saveLiveRoundLoggerMode(mode)
}
```

Update `ProfileViewModel` and `ProfileView` to render a `Shot Logging` preference card beside existing display/GPS settings.

**Step 4: Run tests to verify they pass**

Run the same build-for-testing command.

Expected: build succeeds and the new profile/app-state assertions pass.

**Step 5: Commit**

```bash
git add SwingPal/App/AppState.swift SwingPal/Features/Profile/ProfileViewModel.swift SwingPal/Features/Profile/ProfileView.swift SwingPalTests/ProfileViewModelTests.swift SwingPalTests/AppStateTests.swift
git commit -m "feat: add live round logger mode preference"
```

## Task 2: Introduce inspection mode and confirmed-hole audit state

**Files:**
- Modify: `SwingPal/Features/Round/Models/HoleSession.swift`
- Modify: `SwingPal/Features/Round/LiveRoundState.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing tests**

Add tests for:

1. navigating to another hole enters inspection mode
2. inspection mode disables live targeting/logging affordances
3. editing a confirmed hole marks it as edited-after-confirmation

```swift
func testInspectingPreviousHoleEntersInspectionMode() {
    let state = LiveRoundState.mockWithThreeHoles()

    state.inspectHole(at: 0)

    XCTAssertTrue(state.isInspectingHole)
    XCTAssertEqual(state.displayedHoleNumber, 1)
    XCTAssertFalse(state.isDisplayedHoleLive)
}
```

```swift
func testEditingConfirmedHoleMarksHoleAsEditedAfterConfirmation() {
    let state = LiveRoundState.mock()

    state.confirmCurrentHole()
    state.updateInspectedHoleScore(5)

    XCTAssertTrue(state.hole.wasEditedAfterConfirmation)
}
```

**Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO
```

Expected: failure because there is no inspection mode or confirmed/edit audit state.

**Step 3: Write minimal implementation**

Add to `HoleSession`:

```swift
var isConfirmed: Bool
var wasEditedAfterConfirmation: Bool
```

Add to `LiveRoundState`:

- displayed hole index
- `isInspectingHole`
- `isDisplayedHoleLive`
- `inspectHole(at:)`
- `inspectPreviousHole()`
- `inspectNextHole()`
- hole summary edit methods that flip `wasEditedAfterConfirmation` when needed

Keep one hard rule:

```swift
var canLogLiveShotOnDisplayedHole: Bool { displayedHoleIndex == activeHoleIndex }
```

**Step 4: Run tests to verify they pass**

Run the same build-for-testing command.

Expected: inspection tests compile and pass.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/Models/HoleSession.swift SwingPal/Features/Round/LiveRoundState.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: add live round inspection mode and hole audit flags"
```

## Task 3: Add bounded map framing and free-drag target updates

**Files:**
- Modify: `SwingPal/Features/Round/Models/SwingPalCourse.swift`
- Modify: `SwingPal/Features/Round/LiveRoundState.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing tests**

Add tests that prove:

1. each displayed hole exposes a bounded region
2. free-drag target movement clamps to current hole limits
3. distance-to-target and remaining-to-hole update live as the reticle moves
4. recenter returns the preferred region for `player + selected target`

```swift
func testMovePlanningTargetClampsToDisplayedHoleBounds() {
    let state = LiveRoundState.mock()

    state.movePlanningTarget(to: CGPoint(x: 2.0, y: -2.0))

    XCTAssertLessThanOrEqual(state.planningReticlePoint.x, 1.0)
    XCTAssertGreaterThanOrEqual(state.planningReticlePoint.y, -1.0)
}
```

```swift
func testMovePlanningTargetUpdatesCarryAndRemainingDistances() {
    let state = LiveRoundState.mock()
    let originalCarry = state.planningCarryDistanceMeters

    state.movePlanningTarget(to: CGPoint(x: 0.4, y: -0.2))

    XCTAssertNotEqual(state.planningCarryDistanceMeters, originalCarry)
    XCTAssertGreaterThan(state.planningRemainingDistanceMeters, 0)
}
```

**Step 2: Run tests to verify they fail**

Run the same build-for-testing command.

Expected: failure because the fresh screen only displays passive targeting and the state does not expose full displayed-hole framing semantics.

**Step 3: Write minimal implementation**

Add small helpers on `SwingPalCourse.Hole`:

```swift
struct HoleViewportBounds: Equatable {
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double
}
```

Expose on `LiveRoundState`:

- `displayedHole`
- `displayedHoleRegion`
- `movePlanningTarget(to:)`
- `clampedPlanningPoint(_:)`
- `recenterViewportRegion`

Keep drag behavior free-form inside the hole bounds. Do not add smart snapping in this plan.

**Step 4: Run tests to verify they pass**

Run the same build-for-testing command.

Expected: map-bounds and distance-update tests pass.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/Models/SwingPalCourse.swift SwingPal/Features/Round/LiveRoundState.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: add bounded live round targeting state"
```

## Task 4: Rebuild the top strip and live map around current-vs-inspection state

**Files:**
- Modify: `SwingPal/Features/Round/FreshLiveRoundScreen.swift`
- Test: `SwingPalTests/ShellIntegrationTests.swift`

**Step 1: Write the failing test**

Add a shell-level test that proves the live step still prefers immersive chrome and that inspection remains part of the live-round surface contract.

```swift
func testLiveRoundStepRemainsImmersiveAfterCleanRoomRebuild() {
    XCTAssertTrue(RoundFlowStep.live.prefersImmersiveChrome)
}
```

Add a focused view-contract assertion only if there is existing seam coverage. Do not invent snapshot tooling in this task.

**Step 2: Run test to verify it fails only if you added a new contract**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO
```

Expected: red only if a new explicit seam/assertion is missing. If no meaningful red case is available here, proceed with minimal view implementation while relying on state tests from previous tasks.

**Step 3: Write minimal implementation**

In `FreshLiveRoundScreen.swift`:

- replace the current top strip with:
  - left/right hole arrows
  - centered `Hole X • Par Y`
  - current stroke
  - wind
  - front / pin / back distances
- hide the crosshair entirely when `!state.isDisplayedHoleLive`
- add a floating `Recenter` arrow button over the map
- drive map region from `state.displayedHoleRegion`

Keep the map style:

```swift
.mapStyle(.imagery(elevation: .realistic))
```

**Step 4: Run build verification**

Run the same build-for-testing command.

Expected: app builds with the new top strip and no regression in live routing.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/FreshLiveRoundScreen.swift SwingPalTests/ShellIntegrationTests.swift
git commit -m "feat: rebuild live round top strip and inspection map state"
```

## Task 5: Replace the static bottom panel with a draggable launcher sheet

**Files:**
- Modify: `SwingPal/Features/Round/FreshLiveRoundScreen.swift`
- Modify: `SwingPal/Features/Round/LiveRoundState.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing tests**

Add state tests for launcher-sheet visibility rules:

```swift
func testCurrentClubRemainsAvailableInCollapsedLauncherState() {
    let state = LiveRoundState.mock()

    XCTAssertEqual(state.currentClubLauncherTitle, state.selectedClubName)
}
```

```swift
func testInspectionModeDisablesLiveLauncherActions() {
    let state = LiveRoundState.mockWithThreeHoles()
    state.inspectHole(at: 0)

    XCTAssertFalse(state.canPresentShotLogger)
    XCTAssertFalse(state.showsAtBallAction)
}
```

**Step 2: Run tests to verify they fail**

Run the same build-for-testing command.

Expected: failure because the launcher-state contracts do not exist.

**Step 3: Write minimal implementation**

Add small presentation helpers in `LiveRoundState`:

- `canPresentShotLogger`
- `canMarkBallOnDisplayedHole`
- `currentClubLauncherTitle`
- `showsFinishHoleInvoker`

In `FreshLiveRoundScreen.swift`, replace the bottom static panel with a draggable glass sheet using `presentationDetents`-style behavior or a custom drag offset if needed. The sheet states should be:

- collapsed: `Log Shot`, `At My Ball`, current club
- expanded: invokers only, including `Finish Hole`

Do not place the full working forms inside the launcher sheet.

**Step 4: Run verification**

Run the same build-for-testing command.

Expected: state tests and build pass.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/FreshLiveRoundScreen.swift SwingPal/Features/Round/LiveRoundState.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: add draggable live round launcher sheet"
```

## Task 6: Replace the list club picker with an anchored radial club wheel

**Files:**
- Modify: `SwingPal/Features/Round/FreshLiveRoundScreen.swift`
- Modify: `SwingPal/Features/Round/LiveRoundState.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing tests**

Add tests for:

1. club wheel opens from live state
2. wheel selection updates selected club
3. club wheel center carry value uses player data, then falls back to amateur baseline

```swift
func testClubSelectionFallsBackToAmateurBaselineWhenNoCarryDataExists() {
    let state = LiveRoundState.mockWithoutCarryData()

    let club = state.clubWheelEntries.first { $0.clubName == "7i" }

    XCTAssertEqual(club?.displayCarryMeters, 128)
}
```

**Step 2: Run tests to verify they fail**

Run the same build-for-testing command.

Expected: failure because the wheel entry model and fallback display carry are missing.

**Step 3: Write minimal implementation**

Expose a small wheel-entry model in `LiveRoundState`:

```swift
struct ClubWheelEntry: Equatable, Identifiable {
    let id: String
    let clubName: String
    let displayCarryMeters: Int
}
```

Add:

- `isShowingClubWheel`
- `clubWheelEntries`
- `presentClubWheel()`
- `dismissClubWheel()`
- `selectClubFromWheel(named:)`

Replace the old list-style `FreshLiveRoundClubPickerSheet` with an anchored radial overlay in `FreshLiveRoundScreen.swift`. Keep release-to-select behavior and retain a separate manual `club used` override later in the logger.

**Step 4: Run verification**

Run the same build-for-testing command.

Expected: club-wheel tests pass and build stays green.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/FreshLiveRoundScreen.swift SwingPal/Features/Round/LiveRoundState.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: add anchored live round club wheel"
```

## Task 7: Rebuild the shot logger into Basic and Advanced modes

**Files:**
- Modify: `SwingPal/Features/Round/FreshLiveRoundScreen.swift`
- Modify: `SwingPal/Features/Round/Models/ShotEvent.swift`
- Modify: `SwingPal/Features/Round/LiveRoundState.swift`
- Modify: `SwingPal/App/AppState.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing tests**

Add tests for:

1. logger opens in app-preferred mode
2. logger mode can switch mid-round
3. basic mode captures required fields
4. advanced mode captures additional analytic fields
5. club used can diverge from currently selected club

```swift
func testShotLoggerUsesPreferredModeOnPresent() {
    let state = LiveRoundState.mock(loggerMode: .advanced)

    state.presentShotLogger()

    XCTAssertEqual(state.activeShotLoggerMode, .advanced)
}
```

```swift
func testConfirmPendingShotAllowsManualClubOverride() {
    let state = LiveRoundState.mock()

    state.presentShotLogger()
    state.overridePendingShotClubName("5W")
    state.selectShotDirection(.right)
    state.selectShotDistance(.long)
    state.confirmPendingShot()

    XCTAssertEqual(state.hole.shots.last?.clubName, "5W")
}
```

**Step 2: Run tests to verify they fail**

Run the same build-for-testing command.

Expected: failure because preferred logger mode, mid-round switching, and manual club override are not implemented.

**Step 3: Write minimal implementation**

In `ShotEvent.swift`, extend the model only with fields explicitly agreed in the design:

- stroke number at point
- penalties / drops
- optional lie / shot type / putt detail / note for advanced mode

In `LiveRoundState.swift`, add:

- `ShotLoggerMode`
- `activeShotLoggerMode`
- `switchShotLoggerMode(_:)`
- `pendingShotClubName`
- `overridePendingShotClubName(_:)`
- `pendingStrokeNumber`
- `pendingPenaltyCount`
- advanced optional fields

In `FreshLiveRoundScreen.swift`, replace the current logger sheet with:

- segmented `Basic / Advanced` control
- shared confirm button
- post-confirm top toast state: `Shot Logged`

**Step 4: Run verification**

Run the same build-for-testing command.

Expected: logger-mode tests pass, build stays green, and logger remains dismissible.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/FreshLiveRoundScreen.swift SwingPal/Features/Round/Models/ShotEvent.swift SwingPal/Features/Round/LiveRoundState.swift SwingPal/App/AppState.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: rebuild live round shot logger modes"
```

## Task 8: Add finish-hole confirmation and hole-summary editing

**Files:**
- Modify: `SwingPal/Features/Round/FreshLiveRoundScreen.swift`
- Modify: `SwingPal/Features/Round/LiveRoundState.swift`
- Modify: `SwingPal/Features/Round/Models/HoleSession.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing tests**

Add tests for:

1. finish-hole confirmation cannot advance with incomplete required summary fields
2. confirming the hole marks it confirmed
3. advancing moves to next hole after confirmation
4. revisiting and changing a confirmed hole sets the edit audit flag

```swift
func testConfirmCurrentHoleMarksHoleConfirmed() {
    let state = LiveRoundState.mock()

    state.setPendingHoleScore(4)
    state.setPendingHolePutts(2)
    state.confirmCurrentHole()

    XCTAssertTrue(state.hole.isConfirmed)
}
```

**Step 2: Run tests to verify they fail**

Run the same build-for-testing command.

Expected: failure because confirmation-sheet state and summary editing contracts do not exist.

**Step 3: Write minimal implementation**

In `LiveRoundState`, add:

- `isShowingHoleConfirmation`
- `presentHoleConfirmation()`
- `dismissHoleConfirmation()`
- pending summary edit values for score / putts / penalties / notes
- `confirmCurrentHole()`

In `FreshLiveRoundScreen.swift`, build a dedicated hole-confirmation bottom sheet launched only from the expanded live sheet’s `Finish Hole` invoker.

Keep summary editing at hole level only. Do not add per-shot editing UI here.

**Step 4: Run verification**

Run the same build-for-testing command.

Expected: hole confirmation tests pass and build stays green.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/FreshLiveRoundScreen.swift SwingPal/Features/Round/LiveRoundState.swift SwingPal/Features/Round/Models/HoleSession.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: add live round hole confirmation flow"
```

## Task 9: Prepare shared round-sync payloads for future watch companion

**Files:**
- Create: `SwingPal/Features/Round/Sync/RoundCompanionSyncing.swift`
- Modify: `SwingPal/App/AppState.swift`
- Modify: `SwingPal/Features/Round/LiveRoundState.swift`
- Test: `SwingPalTests/AppStateTests.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing tests**

Add tests proving that round-state mutations emit a sync payload suitable for a future watch companion:

```swift
func testSelectingClubPublishesRoundCompanionSnapshot() {
    let sync = RecordingRoundCompanionSync()
    let state = LiveRoundState.mock(sync: sync)

    state.selectClub(named: "5i")

    XCTAssertEqual(sync.lastSnapshot?.selectedClubName, "5i")
}
```

```swift
func testLoggingShotPublishesUpdatedCompanionSnapshot() {
    let sync = RecordingRoundCompanionSync()
    let state = LiveRoundState.mock(sync: sync)

    state.presentShotLogger()
    state.selectShotDirection(.hit)
    state.selectShotDistance(.onNumber)
    state.confirmPendingShot()

    XCTAssertEqual(sync.lastSnapshot?.loggedShotCount, 1)
}
```

**Step 2: Run tests to verify they fail**

Run the same build-for-testing command.

Expected: failure because no sync abstraction or snapshot payload exists.

**Step 3: Write minimal implementation**

Create a lightweight app-side sync contract only:

```swift
protocol RoundCompanionSyncing: AnyObject {
    func publish(snapshot: RoundCompanionSnapshot)
}

struct RoundCompanionSnapshot: Equatable, Codable {
    let holeNumber: Int
    let par: Int
    let selectedClubName: String
    let distanceToTargetMeters: Int
    let loggedShotCount: Int
    let isInspectingHole: Bool
}
```

Inject it into `LiveRoundState` and publish on key mutations:

- club change
- shot log
- hole navigation
- hole confirmation

Do not build watch transport or UI yet. This task is app-side sync preparation only.

**Step 4: Run verification**

Run the same build-for-testing command.

Expected: sync-payload tests pass and app build remains green.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/Sync/RoundCompanionSyncing.swift SwingPal/App/AppState.swift SwingPal/Features/Round/LiveRoundState.swift SwingPalTests/AppStateTests.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: add round companion sync payloads"
```

## Final Verification

Run all of these before claiming the rebuild slice complete:

```bash
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path); find SwingPal -name '*.swift' -print0 | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$SDK" -module-cache-path /tmp/swift-module-cache
```

Expected: no output, exit code `0`

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST BUILD SUCCEEDED **`

Manual runtime validation on device after each major slice:

- `Log Shot` still opens and dismisses correctly
- `At My Ball` still works on the active hole only
- `Change Club` / club wheel still changes selected club
- `Hole left/right` enters inspection correctly
- `Recenter` returns to player + target framing
- `Finish Hole` opens confirmation and can advance

## Notes

- If the club wheel or draggable live sheet threatens interaction reliability,
  prefer simpler but working presentation over clever gesture layering.
- Do not reintroduce the old `LiveRoundView` path during implementation.
- If a dedicated watch target is added later, use this plan’s sync payload task
  as the handoff seam rather than rebuilding round state again.
