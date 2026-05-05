# Live Round Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current cluttered and partially non-interactive live-round experience with a map-first shot-cycle flow that supports bounded targeting, contextual `At Ball`, and structured shot logging.

**Architecture:** Rebuild `Live Round` around a small interaction-state core in `LiveRoundState` and a thinner `LiveRoundView` that renders three layers only: map, action rail, and lightweight utility/presentation overlays. Keep shot semantics and hole-bounds logic in state/model types so the view can stay simple and testable.

**Tech Stack:** SwiftUI, MapKit, CoreLocation, XCTest, iOS 17, native Xcode project (`SwingPal.xcodeproj`)

**Implementation rules:** Follow @superpowers:test-driven-development for every stateful change. Before claiming completion, follow @superpowers:verification-before-completion and run the listed verification commands. Treat the current live-round non-interactive-control issue as a critical blocker and verify interaction architecture before polishing visuals.

## Pre-flight

- Read `docs/plans/2026-04-22-live-round-redesign-design.md`
- Read `docs/iterations/2026-04-21-iteration-log.md`
- Keep `Live Round` map-first at all times
- Do not add networking or backend work in this pass
- Do not expand scope into course ingestion or Supabase

### Task 1: Introduce structured shot-result models

**Files:**
- Modify: `SwingPal/Features/Round/Models/ShotEvent.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing test**

Add a focused test that proves a logged shot now records separate direction,
distance, and strike dimensions:

```swift
func testConfirmPendingShotStoresStructuredResultDimensions() {
    let state = LiveRoundState.mock()

    state.presentShotLogger()
    state.selectShotDirection(.left)
    state.selectShotDistance(.short)
    state.selectShotStrike(.thin)
    state.confirmPendingShot()

    let shot = try XCTUnwrap(state.hole.shots.last)
    XCTAssertEqual(shot.direction, .left)
    XCTAssertEqual(shot.distanceResult, .short)
    XCTAssertEqual(shot.strikeResult, .thin)
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO
```

Expected: build/test-target failure because `ShotEvent` and `LiveRoundState` do
not yet expose separate direction, distance, and strike dimensions.

**Step 3: Write minimal implementation**

Expand `ShotEvent` with small nested enums:

```swift
enum DirectionResult: String, Codable, Equatable, CaseIterable {
    case hit
    case left
    case farLeft
    case right
    case farRight
}

enum DistanceResult: String, Codable, Equatable, CaseIterable {
    case onNumber
    case long
    case short
}

enum StrikeResult: String, Codable, Equatable, CaseIterable {
    case pure
    case thin
    case chunk
    case top
    case slice
    case hook
}
```

Add them to `ShotEvent`:

```swift
let direction: DirectionResult
let distanceResult: DistanceResult
let strikeResult: StrikeResult
```

Update any existing `ShotEvent` construction in `LiveRoundState` with temporary
defaults so the app still compiles before the sheet is redesigned.

**Step 4: Run test to verify it passes**

Run the same build-for-testing command.

Expected: test-target now compiles and the new assertions pass.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/Models/ShotEvent.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: add structured shot result dimensions"
```

### Task 2: Add shot-cycle state and contextual ball-mark support

**Files:**
- Modify: `SwingPal/Features/Round/LiveRoundState.swift`
- Modify: `SwingPal/Features/Round/Models/HoleSession.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing tests**

Add tests for:

1. tee shot hides `At Ball`
2. later shots expose `At Ball`
3. `markBall()` stores current location as the preferred next-shot origin
4. if no ball mark exists, logging falls back to current location

Example:

```swift
func testAtBallBecomesAvailableAfterTeeShot() {
    let state = LiveRoundState.mock()

    XCTAssertFalse(state.showsAtBallAction)

    state.logMockTeeShot()

    XCTAssertTrue(state.showsAtBallAction)
}
```

```swift
func testMarkBallStoresPreferredShotOrigin() {
    let state = LiveRoundState.mockWithReadyLocation()

    state.logMockTeeShot()
    state.markBall()

    XCTAssertEqual(state.ballMarkStatus, .marked)
    XCTAssertEqual(state.pendingShotOriginSource, .ballMark)
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO
```

Expected: failure because the live-round state does not yet model shot cycle,
ball marks, or origin-source behavior explicitly.

**Step 3: Write minimal implementation**

In `LiveRoundState`, add:

- `ShotOriginSource`
- `BallMarkState`
- `showsAtBallAction`
- `markBall()`
- `clearBallMarkIfNeededAfterLogging()`
- `currentShotOriginCoordinate`
- `currentShotOriginSource`

Example shape:

```swift
enum ShotOriginSource: String, Codable, Equatable {
    case tee
    case ballMark
    case currentLocationFallback
}

struct BallMarkState: Equatable, Codable {
    let coordinate: MapCoordinate
    let headingDegrees: Double
    let recordedAt: Date
}
```

Keep the rule simple:

- zero logged shots => tee-shot mode
- after first shot => `At Ball` available
- `markBall()` updates stored mark from current location
- logging uses ball mark if present, otherwise current location fallback

**Step 4: Run test to verify it passes**

Run the same build-for-testing command.

Expected: test-target compiles and the new shot-cycle tests pass.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/LiveRoundState.swift SwingPal/Features/Round/Models/HoleSession.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: add live round shot cycle and ball mark state"
```

### Task 3: Add hole-bounds and bounded target movement models

**Files:**
- Modify: `SwingPal/Features/Round/Models/SwingPalCourse.swift`
- Modify: `SwingPal/Features/Round/LiveRoundState.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing tests**

Add tests that prove:

1. each hole can expose a bounded map region
2. the planning target is clamped to a valid tactical zone
3. `resetViewport()` reframes to player + selected target

Example:

```swift
func testMoveTargetClampsToHoleBounds() {
    let state = LiveRoundState.mock()

    state.moveTarget(to: CGPoint(x: 5, y: 5))

    XCTAssertLessThanOrEqual(state.planningReticlePoint.x, 1)
    XCTAssertLessThanOrEqual(state.planningReticlePoint.y, 1)
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO
```

Expected: failure because hole bounds and tactical target constraints are not
modeled explicitly enough.

**Step 3: Write minimal implementation**

Add small geometry helpers:

- `SwingPalCourse.Hole.Bounds`
- `SwingPalCourse.Hole.TargetZone`

Then expose from `LiveRoundState`:

- `currentHoleBounds`
- `currentTargetZone`
- `clampedReticlePoint(_:)`
- `preferredMapRegion`

Keep the first implementation pragmatic:

- derive bounds from current hole feature extents plus buffer
- derive target zones from fairway / green feature centroids and extents
- clamp reticle movement into those normalized zones

Do not build a complicated GIS engine in this step.

**Step 4: Run test to verify it passes**

Run the same build-for-testing command.

Expected: bounded movement tests pass.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/Models/SwingPalCourse.swift SwingPal/Features/Round/LiveRoundState.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: add bounded hole targeting model"
```

### Task 4: Replace the current live-round control stack with a shot-cycle action rail

**Files:**
- Modify: `SwingPal/Features/Round/LiveRoundView.swift`
- Modify: `SwingPal/Features/Round/LiveRoundState.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing tests**

Add state-level tests that prove the action rail hierarchy is real:

- `Log Shot` remains primary
- `At Ball` only appears after tee shot
- utility tray state no longer owns the primary flow

Example:

```swift
func testPrimaryActionStateAfterTeeShotShowsLogShotAndAtBall() {
    let state = LiveRoundState.mock()
    state.logMockTeeShot()

    XCTAssertTrue(state.showsAtBallAction)
    XCTAssertEqual(state.primaryActionTitle, "Log Shot")
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO
```

Expected: failure because those action-rail semantics do not exist yet.

**Step 3: Write minimal implementation**

Refactor `LiveRoundView` so the map is permanent and the controls become:

- top instrument strip
- bottom action rail with:
  - `Log Shot`
  - `At Ball` when allowed
  - `Hole / Green`
  - `Recenter`
  - quiet `More`

Keep utility actions behind `More`.

Important:

- remove the current many-button tray
- avoid equal-weight small buttons
- ensure the overlay hierarchy is rebuilt instead of further patched
- keep debug logs in place until the parked non-interactive-control bug is truly
  resolved

**Step 4: Run test to verify it passes**

Run the same build-for-testing command.

Expected: action-rail behavior compiles and tests pass.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/LiveRoundView.swift SwingPal/Features/Round/LiveRoundState.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: rebuild live round action rail"
```

### Task 5: Redesign the shot logger as a structured bottom sheet

**Files:**
- Modify: `SwingPal/Features/Round/LiveRoundView.swift`
- Modify: `SwingPal/Features/Round/LiveRoundState.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing tests**

Add tests that prove:

- presenting the logger resets pending direction / distance / strike selection
- selecting all three categories enables confirmation
- logged shot stores sheet context including origin source and selected target

Example:

```swift
func testShotLoggerRequiresDirectionDistanceAndStrikeBeforeConfirm() {
    let state = LiveRoundState.mock()

    state.presentShotLogger()
    XCTAssertFalse(state.canConfirmPendingShot)

    state.selectShotDirection(.hit)
    state.selectShotDistance(.onNumber)
    state.selectShotStrike(.pure)

    XCTAssertTrue(state.canConfirmPendingShot)
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO
```

Expected: failure because the current logger does not model those three steps.

**Step 3: Write minimal implementation**

Add pending selection state to `LiveRoundState`:

- `pendingShotDirection`
- `pendingShotDistance`
- `pendingShotStrike`
- `canConfirmPendingShot`

Update the sheet in `LiveRoundView` so it renders:

- direction chip grid
- distance chip grid
- strike chip grid
- compact context header

Keep it a bottom sheet over the live map. Do not navigate away from the hole.

**Step 4: Run test to verify it passes**

Run the same build-for-testing command.

Expected: logger state tests pass and the view compiles.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/LiveRoundView.swift SwingPal/Features/Round/LiveRoundState.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: add structured live round shot logger"
```

### Task 6: Make `At Ball` reminders contextual instead of automatic

**Files:**
- Modify: `SwingPal/Features/Round/LiveRoundState.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing tests**

Add tests that prove:

1. immediately after logging, the UI does not auto-prompt for `At Ball`
2. after meaningful location change, the state can suggest `At Ball`

Example:

```swift
func testAtBallSuggestionWaitsForMeaningfulMovement() {
    let state = LiveRoundState.mockWithReadyLocation()

    state.logMockTeeShot()
    state.confirmMockShot()
    XCTAssertFalse(state.shouldSuggestBallMark)

    state.ingestMockLocationMove(distanceMeters: 28)
    XCTAssertTrue(state.shouldSuggestBallMark)
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO
```

Expected: failure because contextual reminder logic does not exist.

**Step 3: Write minimal implementation**

Add simple heuristics:

- store last logged-shot location
- compute location delta after logging
- set `shouldSuggestBallMark` only after a meaningful move
- clear suggestion after `markBall()` or after shot confirm if a ball mark was used

Keep the threshold conservative and local to state for now.

**Step 4: Run test to verify it passes**

Run the same build-for-testing command.

Expected: contextual reminder tests pass.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/LiveRoundState.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: add contextual ball mark suggestions"
```

### Task 7: Finish the visual pass and remove the boxy HUD language

**Files:**
- Modify: `SwingPal/Features/Round/LiveRoundView.swift`
- Modify: `SwingPal/DesignSystem/DesignTokens/ShellTokens.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing test**

Add at least one small state-level regression test if any new visual state is
introduced, for example:

```swift
func testRecenterUsesPlayerAndSelectedTargetRegion() {
    let state = LiveRoundState.mockWithReadyLocation()

    state.resetViewport()

    XCTAssertEqual(state.viewportMode, .playerAndTarget)
}
```

If no new state is introduced, skip adding a meaningless test and document that
this task is visual-only after prior logic coverage.

**Step 2: Run verification before changing visuals**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO
```

Expected: clean baseline before the visual pass.

**Step 3: Write minimal implementation**

Refine `LiveRoundView` so it reads as one instrument, not stacked boxes:

- top HUD becomes one authored strip
- bottom action rail uses one main surface with fewer nested shapes
- secondary context chips become quieter
- map annotations and control surfaces share one visual language
- small-button clutter is removed

This is the first point where visual polish should be applied. Do not attempt
visual polish before the shot-cycle architecture exists.

**Step 4: Run verification**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path); find SwingPal -name '*.swift' -print0 | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$SDK" -module-cache-path /tmp/swift-module-cache
```

Expected:

- Xcode build-for-testing succeeds
- source-level typecheck succeeds

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/LiveRoundView.swift SwingPal/DesignSystem/DesignTokens/ShellTokens.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: polish live round instrument UI"
```

## Final verification

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path); find SwingPal -name '*.swift' -print0 | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$SDK" -module-cache-path /tmp/swift-module-cache
```

Expected:

- test target compiles successfully
- app source typechecks successfully

If simulator services are healthy at execution time, also run:

```bash
xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:SwingPalTests/LiveRoundStateTests
```

Expected:

- `LiveRoundStateTests` pass cleanly

## Notes for the implementing engineer

- Do not try to preserve the current button stack if it keeps the interaction bug
  alive. Rebuild the overlay hierarchy instead.
- Keep the current debug logging until device taps are verified again.
- Prefer small geometry helpers in state/models over view-local gesture math.
- Do not add backend persistence or analytics in this pass.
