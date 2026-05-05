# Apple Watch V1 Companion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a real Apple Watch live-round companion that stays in sync with the phone, prioritizes yardage, club selection, and low-friction shot actions, and respects premium gating.

**Architecture:** Keep the phone and watch on one shared round session. Expand the existing app-side sync seam into a bidirectional phone/watch protocol with one snapshot model and one action-intent model. The iPhone remains the source of truth for persisted round state, while the watch can issue fast tactical actions that are immediately applied on phone and then echoed back as updated snapshots.

**Tech Stack:** SwiftUI, WatchConnectivity, existing `LiveRoundState` / `AppState`, existing premium gating, existing `RoundCompanionSyncing` seam, watchOS SwiftUI app target.

## Product Scope

V1 watch surfaces:

- Yardage glance
- Current club
- Quick club change
- Quick shot logging
- Penalty / drop
- Putt +1
- Finish hole
- Undo last action
- Connection / sync trust state

Explicitly out of scope for V1:

- Watch map
- Full advanced logger
- Deep hole editing
- Stats / AI analysis on watch
- Autonomous round persistence on watch without the phone

## UX Rules

- The watch is a tactical companion, not a mirror of every phone screen.
- A golfer should be able to complete a live round from phone + watch together without state drift.
- Every watch action must have a matching phone-side action handler.
- When sync is degraded, the watch must say so clearly.
- If the user is in the add-shot / finish-hole critical path, the watch must prefer fast confirmations and haptics over decorative UI.

## Shared Model Direction

Expand the current sync payload beyond the existing:

- `holeNumber`
- `par`
- `selectedClubName`
- `distanceToTargetMeters`
- `loggedShotCount`
- `isInspectingHole`

Add these V1 fields:

- `frontDistanceMeters`
- `backDistanceMeters`
- `holeScore`
- `puttCount`
- `penaltyCount`
- `shotNumber`
- `currentSurface`
- `canFinishHole`
- `lastMutationSource`
- `lastMutationAt`
- `connectionState`

Add a companion action envelope for watch-to-phone intents:

- `changeClub(name:)`
- `logShot(direction:distance:surface:)`
- `addPenalty`
- `markDrop`
- `addPutt`
- `finishHole`
- `undoLastAction`
- `recenterTarget`

### Task 1: Expand the shared round companion snapshot model

**Files:**
- Modify: `SwingPal/Features/Round/Sync/RoundCompanionSyncing.swift`
- Modify: `SwingPal/Features/Round/LiveRoundState.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing tests**

Add tests proving the snapshot carries richer round context:

```swift
func testCompanionSnapshotIncludesFrontPinAndBackYardages() {
    let sync = RecordingRoundCompanionSync()
    let state = LiveRoundState.mock(sync: sync)

    state.setTargetDistances(front: 144, pin: 152, back: 168)

    XCTAssertEqual(sync.lastSnapshot?.frontDistanceMeters, 144)
    XCTAssertEqual(sync.lastSnapshot?.distanceToTargetMeters, 152)
    XCTAssertEqual(sync.lastSnapshot?.backDistanceMeters, 168)
}
```

```swift
func testCompanionSnapshotReflectsHoleScoringAndShotCounts() {
    let sync = RecordingRoundCompanionSync()
    let state = LiveRoundState.mock(sync: sync)

    state.confirmPendingShot()
    state.addPutt()
    state.addPenalty()

    XCTAssertEqual(sync.lastSnapshot?.shotNumber, 2)
    XCTAssertEqual(sync.lastSnapshot?.puttCount, 1)
    XCTAssertEqual(sync.lastSnapshot?.penaltyCount, 1)
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedWatchV1Task1 CODE_SIGNING_ALLOWED=NO
```

Expected: failure because the snapshot fields do not exist yet.

**Step 3: Write minimal implementation**

Expand `RoundCompanionSnapshot` in `SwingPal/Features/Round/Sync/RoundCompanionSyncing.swift`:

```swift
enum RoundCompanionMutationSource: String, Equatable, Codable {
    case phone
    case watch
}

enum RoundCompanionConnectionState: String, Equatable, Codable {
    case connected
    case syncing
    case disconnected
}

struct RoundCompanionSnapshot: Equatable, Codable {
    let holeNumber: Int
    let par: Int
    let selectedClubName: String
    let frontDistanceMeters: Int
    let distanceToTargetMeters: Int
    let backDistanceMeters: Int
    let loggedShotCount: Int
    let shotNumber: Int
    let puttCount: Int
    let penaltyCount: Int
    let currentSurface: String
    let holeScore: Int
    let canFinishHole: Bool
    let isInspectingHole: Bool
    let lastMutationSource: RoundCompanionMutationSource
    let lastMutationAt: Date
    let connectionState: RoundCompanionConnectionState
}
```

Update `LiveRoundState` snapshot publishing so it emits those fields on:

- club selection
- shot confirmation
- putt updates
- penalty updates
- hole navigation
- finish-hole readiness changes

**Step 4: Run test to verify it passes**

Run the same `xcodebuild build-for-testing` command.

Expected: new snapshot tests pass.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/Sync/RoundCompanionSyncing.swift SwingPal/Features/Round/LiveRoundState.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: enrich round companion snapshot for watch v1"
```

### Task 2: Add watch-to-phone action intents and a phone-side action handler

**Files:**
- Modify: `SwingPal/Features/Round/Sync/RoundCompanionSyncing.swift`
- Modify: `SwingPal/Features/Round/LiveRoundState.swift`
- Modify: `SwingPal/App/AppState.swift`
- Test: `SwingPalTests/AppStateTests.swift`
- Test: `SwingPalTests/LiveRoundStateTests.swift`

**Step 1: Write the failing tests**

Add tests for incoming watch intents:

```swift
func testWatchIntentCanChangeSelectedClub() {
    let state = LiveRoundState.mock()

    state.applyCompanionAction(.changeClub(name: "7i"), source: .watch)

    XCTAssertEqual(state.selectedClubName, "7i")
}
```

```swift
func testWatchIntentCanAddPuttWithoutOpeningPhoneLogger() {
    let state = LiveRoundState.mock()

    state.applyCompanionAction(.addPutt, source: .watch)

    XCTAssertEqual(state.currentPlayerTotalPutts, 1)
}
```

**Step 2: Run test to verify it fails**

Run the same `xcodebuild build-for-testing` command with a fresh derived-data path.

Expected: failure because no companion action type or handler exists.

**Step 3: Write minimal implementation**

In `SwingPal/Features/Round/Sync/RoundCompanionSyncing.swift`, add:

```swift
enum RoundCompanionAction: Equatable, Codable {
    case changeClub(name: String)
    case logShot(direction: String, distance: String, surface: String?)
    case addPenalty
    case markDrop
    case addPutt
    case finishHole
    case undoLastAction
    case recenterTarget
}
```

In `LiveRoundState`, add:

```swift
func applyCompanionAction(_ action: RoundCompanionAction, source: RoundCompanionMutationSource)
```

Keep the implementation thin and reuse existing live-round actions wherever possible.

In `AppState`, add a small dispatch entry point that routes incoming watch actions to the active round only:

```swift
func handleRoundCompanionAction(_ action: RoundCompanionAction)
```

If there is no active round, drop the action safely.

**Step 4: Run test to verify it passes**

Run the same `xcodebuild build-for-testing` command.

Expected: intent tests pass.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/Sync/RoundCompanionSyncing.swift SwingPal/Features/Round/LiveRoundState.swift SwingPal/App/AppState.swift SwingPalTests/AppStateTests.swift SwingPalTests/LiveRoundStateTests.swift
git commit -m "feat: add watch companion action intents"
```

### Task 3: Add phone-side WatchConnectivity transport

**Files:**
- Create: `SwingPal/Features/Round/Sync/WatchConnectivityRoundCompanionSync.swift`
- Modify: `SwingPal/App/AppState.swift`
- Modify: `SwingPal/Features/Round/Sync/RoundCompanionSyncing.swift`
- Test: `SwingPalTests/AppStateTests.swift`

**Step 1: Write the failing tests**

Add tests for transport wiring:

```swift
func testAppStatePublishesSnapshotsToWatchTransportWhenRoundChanges() {
    let sync = RecordingRoundCompanionSync()
    let state = AppState(roundCompanionSync: sync)

    state.activeRoundState?.selectClub(named: "5i")

    XCTAssertEqual(sync.lastSnapshot?.selectedClubName, "5i")
}
```

**Step 2: Run test to verify it fails**

Expected: failure because the injected transport shape does not exist yet.

**Step 3: Write minimal implementation**

Create a transport that conforms to `RoundCompanionSyncing` and later also handles incoming watch intents:

```swift
final class WatchConnectivityRoundCompanionSync: NSObject, RoundCompanionSyncing {
    func publish(snapshot: RoundCompanionSnapshot) { /* encode + send */ }
    func clear() { /* clear session context */ }
}
```

For V1:

- use `WCSession` application context for latest snapshot
- use interactive messaging for incoming watch actions where reachable
- fall back to queued user info for actions when necessary

Do not put watch UI code in this file.

**Step 4: Run test to verify it passes**

Run the same `xcodebuild build-for-testing` command.

Expected: phone-side sync wiring tests pass.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/Sync/WatchConnectivityRoundCompanionSync.swift SwingPal/App/AppState.swift SwingPal/Features/Round/Sync/RoundCompanionSyncing.swift SwingPalTests/AppStateTests.swift
git commit -m "feat: add phone watch connectivity transport"
```

### Task 4: Create the watch app target and shared companion view model

**Files:**
- Create: `SwingPalWatch Watch App/SwingPalWatchApp.swift`
- Create: `SwingPalWatch Watch App/WatchRoundCompanionStore.swift`
- Create: `SwingPalWatch Watch App/WatchRoundCompanionViewModel.swift`
- Modify: `SwingPal.xcodeproj/project.pbxproj`

**Step 1: Write the failing test**

Create a watch-side unit test target and add:

```swift
func testWatchViewModelReflectsLatestSnapshot() {
    let snapshot = RoundCompanionSnapshot(...)
    let model = WatchRoundCompanionViewModel(snapshot: snapshot)

    XCTAssertEqual(model.primaryYardage, "152")
    XCTAssertEqual(model.clubLabel, "7i")
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPalWatch -sdk watchsimulator -destination 'generic/platform=watchOS Simulator' -derivedDataPath /tmp/SwingPalDerivedWatchV1Task4 CODE_SIGNING_ALLOWED=NO
```

Expected: failure because no watch target or files exist.

**Step 3: Write minimal implementation**

Create the watch app target and add:

- `SwingPalWatchApp.swift`
- `WatchRoundCompanionStore.swift` for `WCSession` listening
- `WatchRoundCompanionViewModel.swift` for presentation-only mapping

Keep the watch store responsible for:

- latest snapshot
- connection state
- sending action intents back to phone

**Step 4: Run test to verify it passes**

Run the same watch `xcodebuild build-for-testing` command.

Expected: watch build succeeds.

**Step 5: Commit**

```bash
git add "SwingPalWatch Watch App" SwingPal.xcodeproj/project.pbxproj
git commit -m "feat: create watch companion target"
```

### Task 5: Build the watch yardage home screen

**Files:**
- Create: `SwingPalWatch Watch App/WatchRoundHomeView.swift`
- Modify: `SwingPalWatch Watch App/WatchRoundCompanionViewModel.swift`
- Test: watch target UI/unit tests as available

**Step 1: Write the failing test**

Add tests that the view model exposes:

- main pin yardage
- front/back yardage
- selected club
- shot count
- sync badge text

**Step 2: Run test to verify it fails**

Run the watch build-for-testing command.

**Step 3: Write minimal implementation**

Build one primary watch home view with:

- large central pin yardage
- smaller `Front` / `Back`
- selected club row
- hole / par row
- sync trust badge
- one primary `Log Shot` button

Support outdoor readability first.

**Step 4: Run test to verify it passes**

Run the same watch build-for-testing command.

**Step 5: Commit**

```bash
git add "SwingPalWatch Watch App/WatchRoundHomeView.swift" "SwingPalWatch Watch App/WatchRoundCompanionViewModel.swift"
git commit -m "feat: add watch round home screen"
```

### Task 6: Build quick actions for club change, shot, putt, penalty, and finish hole

**Files:**
- Create: `SwingPalWatch Watch App/WatchClubPickerView.swift`
- Create: `SwingPalWatch Watch App/WatchQuickShotView.swift`
- Create: `SwingPalWatch Watch App/WatchHoleFinishView.swift`
- Modify: `SwingPalWatch Watch App/WatchRoundCompanionStore.swift`
- Test: watch unit tests

**Step 1: Write the failing tests**

Add tests for watch actions:

```swift
func testClubPickerSendsChangeClubIntent() { ... }
func testQuickShotSendsLogShotIntent() { ... }
func testFinishHoleSendsFinishHoleIntent() { ... }
```

**Step 2: Run test to verify it fails**

Run the watch build-for-testing command.

**Step 3: Write minimal implementation**

Watch action screens:

- `WatchClubPickerView`
  - searchable or crown-scrollable club list from latest snapshot / bag context
- `WatchQuickShotView`
  - `Hit`
  - `Left`
  - `Right`
  - `Long`
  - `Short`
  - optional quick putt increment
- `WatchHoleFinishView`
  - current hole score summary
  - confirm finish
  - undo last action

Every action should:

- send a `RoundCompanionAction`
- show optimistic local feedback
- then reconcile against the next phone snapshot

**Step 4: Run test to verify it passes**

Run the same watch build-for-testing command.

**Step 5: Commit**

```bash
git add "SwingPalWatch Watch App/WatchClubPickerView.swift" "SwingPalWatch Watch App/WatchQuickShotView.swift" "SwingPalWatch Watch App/WatchHoleFinishView.swift" "SwingPalWatch Watch App/WatchRoundCompanionStore.swift"
git commit -m "feat: add watch quick round actions"
```

### Task 7: Add sync trust UX and offline behavior

**Files:**
- Modify: `SwingPal/Features/Round/Sync/WatchConnectivityRoundCompanionSync.swift`
- Modify: `SwingPalWatch Watch App/WatchRoundCompanionStore.swift`
- Modify: `SwingPalWatch Watch App/WatchRoundCompanionViewModel.swift`
- Test: phone and watch transport tests

**Step 1: Write the failing tests**

Add tests for:

- disconnected state
- reconnect state
- queued action replay
- latest mutation source tracking

**Step 2: Run test to verify it fails**

Run phone and watch build-for-testing commands.

**Step 3: Write minimal implementation**

Add:

- `connected`
- `syncing`
- `disconnected`

state propagation through the snapshot / store layer.

Rules:

- if watch cannot reach phone, show `Offline`
- if action is queued, show `Syncing`
- on next confirmed snapshot, clear queued state
- if action fails, revert optimistic watch badge state

**Step 4: Run test to verify it passes**

Run the phone and watch build-for-testing commands again.

**Step 5: Commit**

```bash
git add SwingPal/Features/Round/Sync/WatchConnectivityRoundCompanionSync.swift "SwingPalWatch Watch App/WatchRoundCompanionStore.swift" "SwingPalWatch Watch App/WatchRoundCompanionViewModel.swift"
git commit -m "feat: add watch sync trust states"
```

### Task 8: Wire premium gating and upsell entry points to the real watch companion

**Files:**
- Modify: `SwingPal/App/AppShellView.swift`
- Modify: `SwingPal/Features/Profile/ProfileView.swift`
- Modify: `SwingPal/Features/Home/HomeView.swift`
- Modify: `SwingPal/Features/Premium/GatedActionResolver.swift`
- Test: `SwingPalTests/ShellIntegrationTests.swift`

**Step 1: Write the failing tests**

Add tests proving:

- free users still hit premium gate
- premium users open the real watch companion entry point

**Step 2: Run test to verify it fails**

Run the iOS build-for-testing command.

**Step 3: Write minimal implementation**

Keep the existing premium gate behavior for free users.

For premium users:

- route `Open Watch Companion` to a real phone-side watch companion landing / help screen
- show connection state and setup readiness
- deep-link into live round if a round is active

**Step 4: Run test to verify it passes**

Run the same iOS build-for-testing command.

**Step 5: Commit**

```bash
git add SwingPal/App/AppShellView.swift SwingPal/Features/Profile/ProfileView.swift SwingPal/Features/Home/HomeView.swift SwingPal/Features/Premium/GatedActionResolver.swift SwingPalTests/ShellIntegrationTests.swift
git commit -m "feat: connect premium watch companion entry points"
```

## Final Verification

Run all of these before claiming the watch V1 slice complete:

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedWatchV1Phone CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST BUILD SUCCEEDED **`

```bash
xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPalWatch -sdk watchsimulator -destination 'generic/platform=watchOS Simulator' -derivedDataPath /tmp/SwingPalDerivedWatchV1Watch CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST BUILD SUCCEEDED **`

Manual runtime validation on devices:

- start a round on phone and see the watch home view populate
- change club on watch and confirm phone updates
- log shot on watch and confirm phone updates
- add putt / penalty on watch and confirm score reflects it
- finish hole on watch and confirm phone advances
- disconnect watch temporarily and confirm trust state changes visibly
- reconnect and confirm queued / latest state reconciles without duplicate actions

## Notes

- Reuse current `LiveRoundState` actions wherever possible. Do not build a second round engine for watch.
- Keep `RoundCompanionSnapshot` and `RoundCompanionAction` Codable and versionable.
- If conflict handling starts getting complicated, prefer phone-authoritative reconciliation plus visible watch status over hidden magic.
- Do not add analytics, map, or full advanced edit flows to the watch in V1.
- If watch target setup threatens the schedule, finish Tasks 1-3 first so the phone-side sync core is correct before UI work.
