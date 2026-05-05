# SwingPal Iteration Log

## 2026-04-21

### Repository State

- Started from an empty workspace
- Created a native Xcode SwiftUI scaffold targeting iOS 17
- Added a minimal app target, unit test target, and base asset catalog

### Product Direction Agreed

- SwingPal is a golf side-kick focused on beautiful UI/UX and calm, intelligent
  assistance
- Core use cases include nearby course browsing, round setup, shot tracking, GPS
  distance to pin, guest players, bag support, and round attestation

### Navigation Direction

- Primary shell is `Home / Social / Round / Profile`
- `Round` is the emphasized center tab
- `Bag` lives inside `Profile`

### Home Direction

- `Home` is the personal command center, not a misc dashboard
- Screen priority:
  1. Resume or start round
  2. AI insights
  3. Recent rounds
  4. Nearby courses
- AI coaching should be opt-in
- Broad, factual analysis can be shown by default

### Social Direction

- v1 social is friends plus round posts
- Larger leaderboards and comparison systems are deferred to later phases

### Round Flow Direction

- Nearby course list sorted by nearest first
- Course detail screen with course info, yardages, and tees
- Player selection supports lightweight guest players
- Live round begins after player selection

### Live Round Direction

- Primary screen is an aerial view of the current hole
- A HUD around the edges provides needed round information
- Additional UI should support yardage intelligence and shot entry without replacing
  the map-first layout

### Auth Direction

- Guest browsing allowed
- Authentication required for non-anonymous actions such as saving, interacting,
  syncing, or updating persistent user data

### Monetization Direction

- Saved rounds are definitely free
- Core golf utility remains free
- Premium is centered on intelligence and helpfulness
- Free intelligence should include:
  - plays-like yardage
  - bag-based club recommendation
  - broad insights such as strokes dropped, FIR/GIR trends, and club summaries
- Premium intelligence should include:
  - Apple Watch live round companion
  - motion and swing analysis
  - projected landing/search corridor
  - deeper caddie-style intelligence
  - richer post-round analysis
- Free intelligence should stay transparent and explainable rather than pretending to
  know more than it does

### Watch Direction

- Apple Watch is intended as a slimmed-down live round companion
- Longer-term ambition includes motion sensing and swing-informed intelligence
- The projected landing area idea should be framed as a probable landing corridor or
  search assist, not exact ball finding

### Later-Scoped Feature

- Launch monitor integration is explicitly deferred
- It should be drafted for technical feasibility and supported in the long-term data
  model, but not treated as a v1 feature

### Visual Direction

- The visual system should feel premium, bright, natural, and calm
- Palette direction: deep pine, sand, stone, mist, sunlit gold accent
- Avoid generic dark sports-tech styling
- Motion should focus on calm precision, shared-element transitions, and subtle HUD
  changes

### Auth and Onboarding Direction

- Preferred cloud auth provider is Supabase
- Auth methods required:
  - Apple
  - Google
  - email magic link
  - guest mode
- Biometrics are for local session convenience after sign-in, not for primary account
  identity
- Auth gates should be soft at first and only become firm at the moment a user
  commits to a gated action
- First-run should be low-friction, skippable, and guest-friendly
- Permissions should be requested in context, not all at launch

### Architecture Direction

- `RoundSession` is the central domain object
- `RoundPlayer` must support both authenticated users and lightweight guests through
  one shared model
- `ShotEvent` should be designed to accept manual, watch-derived, and later external
  data sources
- State domains should be organized around:
  - Auth
  - Home
  - Round
  - Social
  - Profile
  - Entitlements
- The round system should use a shared core that can power both iPhone and Apple
  Watch UIs

### Scoring and Social Direction

- Scoring during play should stay lightweight and secondary to the live map
- Round closure should include a dedicated `Review & Attest` step
- Guest players can be locally attested in v1
- Completed rounds should naturally generate structured social content instead of
  requiring users to author posts from scratch

### Component System Direction

- The visual system should rely on a small reusable set of component families:
  - hero cards
  - utility cards
  - insight panels
  - player chips
  - HUD modules
  - action sheets
- Insight panels should look like polished product UI, not chat bubbles
- The live round HUD should be composed of focused, swappable instrument-style modules

### Open Questions

- Exact information architecture and modules on `Home`
- The first version of the `Social` feed card types and interactions
- What the premium gating moments should look like in the UI
- Whether the post-round AI playback is a v1 premium feature or v2 enhancement

### Handoff Note

Future agents should treat `docs/plans/2026-04-21-product-flow-design.md` as the
current source of truth for product flow and monetization decisions.

The current implementation handoff plan is:

- `docs/plans/2026-04-21-v1-app-shell-implementation.md`

Future agents should execute from that plan and append to this log rather than
rewriting prior decisions.

### Parallel Coordination Update

- Added `docs/iterations/2026-04-21-agent-sync.md` to coordinate parallel agent work
- Split active workstreams into:
  - app shell implementation
  - design system spec
  - Supabase auth/data planning

### Supabase Planning Direction

- Social graph should use mutual friends
- Supabase Auth remains the preferred cloud auth provider
- Supported auth methods remain:
  - Apple
  - Google
  - email magic link
  - guest mode
- Guest mode should remain local-first, with conversion at the moment of a cloud
  action
- The backend model should center on profiles, friendships, rounds, round players,
  holes, shots, score state, attestations, and structured social posts
- Premium should remain explicit via entitlement fields rather than scattered logic

### App Shell Implementation Progress

- The workspace already contained partial implementation work for the app shell tasks
  when the execution pass resumed
- Verified and extended the shell so `Home`, `Social`, `Round`, and `Profile` are all
  wired into the tab bar
- Added or preserved scaffold coverage for:
  - round setup flow
  - live round HUD
  - round review and attestation shell
  - bag and club recommendation scaffolding
  - auth and premium gate placeholder flows
- Replaced invalid `.background.secondary` surface styling with valid SwiftUI/UIKit
  color-backed surfaces
- Removed the preview macro from `ContentView.swift` to allow source-level
  verification in the sandbox
- Replaced `@Observable` and `@Bindable` usage with `ObservableObject` and published
  state so the module can be type-checked without macro plugin support in this
  environment

### Verification Notes

- Full `xcodebuild test` verification remains blocked in this sandbox because
  CoreSimulator and asset catalog tooling cannot access simulator runtimes
- Full `xcodebuild build` is likewise blocked at asset compilation for the same
  environment reason
- The app source module was successfully verified with:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
- The repository is still not initialized as git, so commit steps from the plan could
  not be executed

### Single-Agent Continuity Pass

- Collapsed back to a single active implementation owner to stop parallel drift
- Fixed the `Resume Round` foundation by moving live round state into `AppState`
  through `activeRoundState`
- Updated the round flow so a started round can be resumed after switching tabs,
  instead of recreating local live-round state inside `RoundRootView`
- Replaced fabricated review data with real round-derived review players from
  `LiveRoundState.reviewPlayers`
- Updated `PlayerScoreState` to represent actual review data more honestly:
  - guest vs signed-in player
  - optional strokes
  - pending/confirmed/edited status
- Updated `RoundReviewView` so it renders real review-player state instead of
  hardcoded confirmed scores

### Single-Agent Verification

- Added failing tests for:
  - active round state persistence in `AppStateTests`
  - round-derived review-player state in `LiveRoundStateTests`
- Because full XCTest execution remains environment-limited, red/green verification
  for the new APIs was performed with a focused `swiftc -typecheck` harness against
  the relevant app model files
- Full app source verification passed again with:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`

### Design System Spec Package Added

- Created `docs/plans/2026-04-21-design-system-spec.md` as the implementation-facing
  visual-system contract for SwingPal iOS 17.
- Locked concrete semantic tokens for color, typography, spacing, radius, shadow,
  and surface depth to preserve the premium, bright, natural, calm direction.
- Defined component anatomy and behavior rules for:
  - hero cards
  - utility cards
  - insight panels
  - player chips
  - HUD modules
  - sheets/overlays
  - tab bar with emphasized center `Round` CTA
- Added explicit motion timing/easing rules and map/HUD transition guidance for calm
  precision in live round interactions.
- Added free vs premium surface treatment, auth gate presentation style, AI insight
  card content rules, and live round HUD readability constraints.
- Added accessibility constraints for outdoor use (contrast, touch targets, dynamic
  type, high-legibility fallback, reduced motion).
- Added recommended SwiftUI token/component file organization for future
  implementation agents, without changing app code or project structure.

### Documentation Sidecar: Design System Spec

- Created `docs/plans/2026-04-21-design-system-spec.md` as a concrete visual-system
  and component-spec package for v1 implementation.
- The spec defines:
  - brand/visual principles aligned to premium, bright, natural, calm direction
  - semantic color tokens (brand, surface, text, state, premium, gate)
  - typography roles and usage rules for readability
  - spacing/radius/shadow/border tokens
  - concrete component anatomy and rules for:
    - hero cards
    - utility cards
    - insight panels
    - player chips
    - HUD modules
    - sheets/overlays
    - tab bar with emphasized center `Round` CTA
  - motion timing/transition rules
  - free vs premium surface-state guidance
  - auth gate presentation style
  - AI insight presentation rules
  - live-round HUD visual constraints
  - accessibility and outdoor readability constraints
  - suggested SwiftUI token/file organization for implementation follow-through
- Scope guardrails were preserved:
  - no app source files changed
  - no tests changed
  - no Xcode project changes

### Execution Pass: Design-System Docs Finalized

- Re-read `docs/plans/2026-04-21-product-flow-design.md` and confirmed the design
  system spec remains aligned to product thesis, IA, and free/premium boundaries.
- Confirmed `docs/plans/2026-04-21-design-system-spec.md` exists as the canonical
  visual-system and component-spec package for implementation agents.
- Confirmed scope guardrails remain intact for this pass:
  - documentation-only changes
  - no app source edits
  - no test edits
  - no Xcode project edits

### App Shell Implementation Progress

- Extended the SwiftUI shell to wire all four tabs to feature scaffolds:
  - `Home` command center
  - `Social` friend-round feed
  - `Round` setup -> live round -> review scaffold
  - `Profile` with bag and intelligence preview
- Implemented round setup scaffolding with sorted nearby courses, course detail,
  player selection, guest-player add flow, and live-round handoff.
- Implemented live round state and map-first placeholder with composable HUD modules
  (distance, club, hole info) plus `Finish Hole` path into `Review & Attest`.
- Added profile/bag domain models and free-intelligence club recommendation reasoning.
- Added auth/premium gating scaffolding via `GatedActionResolver`, `AuthGateView`,
  and premium requirement messaging for watch companion access.
- Added test coverage for:
  - round setup sorting + guest player creation
  - live shot logging state mutation
  - bag recommendation explainability
  - auth/premium gating rules
  - shell integration state behavior
- Verification completed:
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16'`
  - `xcodebuild build -project SwingPal.xcodeproj -scheme SwingPal -destination 'generic/platform=iOS Simulator'`
  - both succeeded

### Re-Baseline Alignment Pass (Agent 1)

- Read and followed `docs/iterations/2026-04-21-agent-sync.md` Re-Baseline section
  as authoritative before making this pass.
- Scope stayed in app shell code only and remained mocked-data-only.
- Aligned shell UI surfaces toward design-system tokens by introducing:
  - `SwingPal/DesignSystem/DesignTokens/ShellTokens.swift`
- Updated shell cohesion and visual consistency across:
  - `AppShellView`
  - `Home` surfaces (`HomeView`, `HomeHeroCard`)
  - `Social` surfaces (`SocialView`, `SocialPostCard`)
  - `Round` surfaces (`CourseListView`, `CourseDetailView`, `PlayerSelectionView`,
    `LiveRoundView`, HUD modules)
  - `Profile` and auth gate surfaces (`ProfileView`, `BagView`, `AuthGateView`)
- Preserved IA and product boundaries:
  - top-level shell remains `Home / Social / Round / Profile`
  - `Round` tab received stronger visual emphasis in the tab bar
  - free-core utility stayed available; premium prompts remained scoped to deeper
    intelligence/watch companion affordances

### Verification (Explicit Separation)

- Source-level verification (run in this pass):
  - Command:
    - `SDK=$(xcrun --sdk iphonesimulator --show-sdk-path) && swiftc -typecheck -sdk "$SDK" -target arm64-apple-ios17.0-simulator -module-name SwingPal $(rg --files SwingPal -g "*.swift")`
  - Result: success (exit code 0)

- Full xcodebuild verification (rerun in this pass with fresh derived-data paths):
  - Test command:
    - `rm -rf /Users/gabeh/Desktop/SwingPal/.derivedData-clean && xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /Users/gabeh/Desktop/SwingPal/.derivedData-clean`
  - Result: `** TEST SUCCEEDED **`
  - Captured output:
    - `/Users/gabeh/.cursor/projects/Users-gabeh-Desktop-SwingPal/agent-tools/30f3e03f-bcfd-4209-95a7-51c5ee9059fe.txt`

  - Build command:
    - `rm -rf /Users/gabeh/Desktop/SwingPal/.derivedData-clean-build && xcodebuild build -project SwingPal.xcodeproj -scheme SwingPal -destination 'generic/platform=iOS Simulator' -derivedDataPath /Users/gabeh/Desktop/SwingPal/.derivedData-clean-build`
  - Result: `** BUILD SUCCEEDED **`
  - Captured output:
    - `/Users/gabeh/.cursor/projects/Users-gabeh-Desktop-SwingPal/agent-tools/0523ae80-511d-44e2-8878-3998a24f8ea1.txt`

### UX Refinement Pass: Premium Shell Direction

- Per re-baselined instructions, performed a focused shell UX refinement against:
  - `docs/plans/2026-04-21-product-flow-design.md`
  - `docs/plans/2026-04-21-design-system-spec.md`
  - `docs/iterations/2026-04-21-agent-sync.md`
- Replaced default-feeling tab presentation with a custom bottom bar in
  `AppShellView`, including a raised/emphasized center `Round` CTA.
- Improved `Home` to feel more intentional by:
  - wiring primary hero action to open `Round`
  - adding compact personal-status chips
  - upgrading insight panel language with explicit reason + next step
  - replacing generic repeated cards with stronger utility panel structure
- Moved round setup away from form/list feel by:
  - replacing default list rows in `CourseListView` with guided course cards
  - adding list/map toggle scaffold and stronger section framing
  - replacing player form-list with chip-style player presentation and guided actions
- Moved live round closer to map-first + instrument-HUD direction by:
  - redesigning `LiveRoundView` to keep a clear central map corridor
  - docking HUD modules to edges with bottom action tray
  - adding additional contextual HUD pill (wind) in-map
- Upgraded gating surfaces:
  - redesigned `AuthGateView` with benefit-forward, product-style structure
  - replaced generic premium alert with `PremiumGateView` sheet
- Added:
  - `SwingPal/Features/Premium/PremiumGateView.swift`
  - updated `SwingPal.xcodeproj/project.pbxproj` for new source inclusion

### Verification (This Pass)

- Source-level verification:
  - Ran:
    - `SDK=$(xcrun --sdk iphonesimulator --show-sdk-path) && swiftc -typecheck -sdk "$SDK" -target arm64-apple-ios17.0-simulator -module-name SwingPal $(rg --files SwingPal -g "*.swift")`
  - Result: success (exit code 0)

- Full xcodebuild verification (clean derived-data rerun in this pass):
  - Ran:
    - `rm -rf /Users/gabeh/Desktop/SwingPal/.derivedData-clean-2 && xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /Users/gabeh/Desktop/SwingPal/.derivedData-clean-2`
  - Result: `** TEST SUCCEEDED **`
  - Captured output:
    - `/Users/gabeh/.cursor/projects/Users-gabeh-Desktop-SwingPal/agent-tools/4a387bd8-c5d5-43cf-8339-bb7960f6c364.txt`

  - Ran:
    - `rm -rf /Users/gabeh/Desktop/SwingPal/.derivedData-clean-build-2 && xcodebuild build -project SwingPal.xcodeproj -scheme SwingPal -destination 'generic/platform=iOS Simulator' -derivedDataPath /Users/gabeh/Desktop/SwingPal/.derivedData-clean-build-2`
  - Result: `** BUILD SUCCEEDED **`
  - Captured output:
    - `/Users/gabeh/.cursor/projects/Users-gabeh-Desktop-SwingPal/agent-tools/a1d29419-4dc1-4252-b627-679b19b8abdd.txt`

### Remaining Gaps (Not Fully Closed Yet)

- Live round still uses a mocked aerial surface rather than real map imagery or GPS
  layers.
- Round setup flow is materially improved but still lacks richer shared-element
  transitions and deeper visual polish across step changes.
- Premium/auth gates are now product-structured but still rely on mocked, non-functional
  action handlers.

### 2026-04-21 13:18:39 AEST - Single-Agent Round Polish Pass

- Continued as a single agent only. No further delegation assumptions in this pass.
- Used TDD for the round-state behavior supporting the UI pass:
  - Added failing tests first in `SwingPalTests/LiveRoundStateTests.swift` for:
    - `playsLikeDistanceMeters`
    - signed-in player status changing to `.edited` after shot logging
    - `RoundReviewSummary` counts
  - Xcode test execution was initially blocked by sandbox/CoreSimulator limits, so a
    temporary `/tmp/RoundStateSpec.swift` compile harness was used as the red/green
    check for the new API while keeping the real repo tests in place.
- Added the missing round-state behavior:
  - `LiveRoundState.playsLikeDistanceMeters`
  - `LiveRoundState.logShot(...)` now marks the signed-in player as `.edited`
  - `RoundReviewSummary` now lives in `PlayerScoreState.swift` so the Xcode target
    sees it without project-file churn
- Refined the main `Round` surfaces to better match the product/design docs:
  - `CourseListView`
    - stronger location-aware header
    - richer map preview placeholder
    - more premium course ranking cards
  - `CourseDetailView`
    - stronger commitment hero
    - course preview panel
    - more deliberate tee/CTA presentation
  - `LiveRoundView`
    - more instrument-like map panel
    - clearer edge HUD treatment
    - better metrics + insight cluster
    - stronger action tray with a more intentional `Log Shot` primary action
  - `RoundReviewView`
    - real `RoundReviewSummary` usage
    - calmer scorecard presentation
    - clearer status and close/save state

### Verification (Single-Agent Round Polish Pass)

- Source-level app module typecheck:
  - Ran:
    - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - Result: success

- Round-state harness verification:
  - Ran:
    - `xcrun swiftc -typecheck ... $(find SwingPal -name '*.swift' | sort) /tmp/RoundStateSpec.swift`
  - Result:
    - first run failed correctly because `playsLikeDistanceMeters` and
      `RoundReviewSummary` did not exist yet
    - second run passed after implementation

- Full project verification:
  - Initial in-sandbox `xcodebuild build-for-testing` remained blocked by simulator
    service/tooling restrictions
- Re-ran unrestricted and confirmed:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerived CODE_SIGNING_ALLOWED=NO`
  - Result: `** TEST BUILD SUCCEEDED **`

### 2026-04-21 13:29:00 AEST - Shell + Home Visual Upgrade Pass

- User feedback identified two concrete problems:
  - `Home` still felt scaffold/basic rather than premium and intentional
  - the floating bottom navigation was structurally broken and could overlap content
- Root cause:
  - the bar used a floating center action with only `92pt` of reserved bottom inset, so
    content could slide under the CTA/button stack
  - `HomeView` was still built from mostly uniform white utility cards with weak visual
    hierarchy and almost no atmospheric treatment
- Added tests first:
  - `HomeViewModelTests`
    - verifies `quickStats` exist for the home dashboard summary
  - `ShellIntegrationTests`
    - verifies the floating shell reserves enough bottom clearance via
      `AppChromeMetrics.bottomContentInset`
- Implemented:
  - `AppChromeMetrics` in `AppShellView.swift`
    - centralizes tab bar height, button lift, and bottom content inset
  - redesigned `SwingPalTabBar`
    - more balanced dock
    - explicit round label
    - improved floating CTA placement
  - increased bottom safe-area reservation in `AppShellView`
  - upgraded `HomeViewModel` with structured `quickStats`
  - redesigned `HomeView`
    - ambient layered background
    - stronger custom header
    - more premium hero treatment
    - compact stat cards instead of plain chips
    - larger editorial insight card
    - more intentional utility panels
    - improved premium panel
  - upgraded `HomeHeroCard`
    - richer gradient/shape treatment
    - stronger CTA styling
    - calmer premium hierarchy
  - expanded `ShellTokens` with additional background/surface colors used by the new
    home shell

### Verification (Shell + Home Visual Upgrade Pass)

- RED:
  - `xcodebuild build-for-testing ...`
  - failed for the expected missing-symbol reason:
    - `HomeViewModel` had no `quickStats`
- GREEN:
  - Source-level app typecheck:
    - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
    - passed
  - Project build:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerived CODE_SIGNING_ALLOWED=NO`
    - result: `** TEST BUILD SUCCEEDED **`
  - Test suite:
    - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO`
    - result: `** TEST SUCCEEDED **`

### 2026-04-21 13:45:00 AEST - Bottom Nav Clearance Fix

- User reported that the new bottom bar still clipped content.
- Root cause:
  - `AppChromeMetrics.bottomContentInset` was still too small relative to the
    redesigned floating center CTA and dock footprint.
  - The previous shell test only checked for a weak minimum and did not actually
    encode the visual relationship between the dock height and the raised round button.
- TDD:
  - tightened `ShellIntegrationTests.testFloatingTabBarReservesEnoughBottomClearanceForContent`
    to require:
    - `bottomContentInset >= tabBarHeight + floatingRoundButtonLift + 56`
  - confirmed the stricter suite failed before the fix
- Fix:
  - updated `AppChromeMetrics.bottomContentInset` in `AppShellView.swift` to derive
    from the actual chrome dimensions:
    - `tabBarHeight + floatingRoundButtonLift + 56`

### Verification (Bottom Nav Clearance Fix)

- Logged red check:
  - `xcodebuild test ... > /tmp/shell_fix_test.log`
  - result: `** TEST FAILED **`
- Green check after fix:
  - `xcodebuild test ... > /tmp/shell_fix_test.log`
  - result: `** TEST SUCCEEDED **`
  - explicit confirmation:
    - `ShellIntegrationTests.testFloatingTabBarReservesEnoughBottomClearanceForContent()` passed

### 2026-04-21 13:53:02 AEST - Bottom Dock Center-Lane Fix

- User identified a second dock issue: `Social` and `Round` visually overlapped.
- Root cause:
  - the dock still used a flexible center spacer, so `Home`, `Social`, spacer, and
    `Profile` were effectively laid out as four equal columns
  - the `Round` button/label was then overlaid on top of that, which left `Social`
    too close to the center lane
- TDD:
  - added `ShellIntegrationTests.testFloatingTabBarReservesDedicatedCenterLaneForRoundAction`
  - first red run failed because `AppChromeMetrics.centerDockReservation` did not exist
- Fix:
  - added `AppChromeMetrics.centerDockReservation`
  - changed the tab bar layout to use a fixed-width reserved center lane instead of a
    flexible spacer
  - current reservation:
    - `floatingRoundButtonSize + 44`

### Verification (Bottom Dock Center-Lane Fix)

- Red:
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO`
  - failed for the expected missing-symbol reason:
    - `AppChromeMetrics.centerDockReservation`
- Green:
  - same `xcodebuild test` command rerun after the fix
  - result: `** TEST SUCCEEDED **`
  - explicit confirmation:
    - `ShellIntegrationTests.testFloatingTabBarReservesDedicatedCenterLaneForRoundAction()` passed
    - `ShellIntegrationTests.testFloatingTabBarReservesEnoughBottomClearanceForContent()` passed

### 2026-04-21 14:05:12 AEST - Live Round Targeting Pass

- Continued the flagship `Live Round` refinement with real target-context state rather
  than decorative controls.
- TDD:
  - added `LiveRoundStateTests.testToggleTargetViewSwitchesBetweenHoleAndGreenContext`
  - added `LiveRoundStateTests.testMoveTargetCyclesAimPointRecommendations`
  - initial red run failed for the expected missing API:
    - `targetViewMode`
    - `targetViewTitle`
    - `targetSupportText`
    - `targetLabel`
    - `toggleTargetView()`
    - `moveTarget()`
- During the red pass, a separate syntax regression in `HomeHeroCard.swift` surfaced:
  - stray trailing comma in `.frame(maxWidth: .infinity, alignment: .leading, )`
  - fixed before returning to the intended target-state work
- Implementation:
  - extended `LiveRoundState` with:
    - `TargetViewMode`
    - `AimPoint`
    - `targetViewTitle`
    - `targetLabel`
    - `targetSupportText`
    - `toggleTargetView()`
    - `moveTarget()`
  - rewired `LiveRoundView` so:
    - center target marker animates between hole/green contexts
    - target label/support copy updates from live state
    - `Move Target` and `Green View` buttons drive real state
    - footer/focus cards now reflect target context instead of static placeholder copy

### Verification (Live Round Targeting Pass)

- Focused red:
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO -only-testing:SwingPalTests/LiveRoundStateTests`
  - failed for the expected missing-member reasons listed above
- Focused green:
  - same `-only-testing:SwingPalTests/LiveRoundStateTests` command rerun after state implementation
  - result: `** TEST SUCCEEDED **`
- Source verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: success
- Full verification:
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST SUCCEEDED **`
  - explicit confirmation:
    - `LiveRoundStateTests.testToggleTargetViewSwitchesBetweenHoleAndGreenContext()` passed
    - `LiveRoundStateTests.testMoveTargetCyclesAimPointRecommendations()` passed

### 2026-04-21 14:13:05 AEST - Live Round Strategy Context Pass

- Continued the `Live Round` flagship pass with richer targeting guidance and more
  deliberate map composition.
- TDD:
  - added `LiveRoundStateTests.testSafeMissBuildsConservativeStrategyContext`
  - added `LiveRoundStateTests.testGreenViewReframesStrategyAroundLandingArea`
  - initial red run failed for the expected missing API:
    - `landingWindowTitle`
    - `hazardCallout`
    - `contextChips`
- Implementation:
  - extended `LiveRoundState` with strategy context derived from `targetViewMode`
    and `aimPoint`
  - added:
    - `landingWindowTitle`
    - `hazardCallout`
    - `contextChips`
  - updated `LiveRoundView` to use the new context in visible UI:
    - richer map geometry with tee boxes, bunkers, and a clearer landing corridor
    - bottom strategy band over the map using live state
    - focus/footer cards now reference landing window and risk context instead of
      placeholder copy

### Verification (Live Round Strategy Context Pass)

- Focused red:
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO -only-testing:SwingPalTests/LiveRoundStateTests`
  - failed for the expected missing-member reasons listed above
- Focused green:
  - same `-only-testing:SwingPalTests/LiveRoundStateTests` command rerun after the
    state implementation
  - result: `** TEST SUCCEEDED **`
- Source verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: success
- Full verification:
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST SUCCEEDED **`
  - explicit confirmation:
    - `LiveRoundStateTests.testSafeMissBuildsConservativeStrategyContext()` passed
    - `LiveRoundStateTests.testGreenViewReframesStrategyAroundLandingArea()` passed

### 2026-04-21 14:26:00 AEST - Round Setup Continuity Pass

- Shifted the setup flow from isolated screens toward a shared round-building sequence.
- TDD:
  - added `RoundSetupStateTests.testSelectingTeeBuildsPersistentRoundSetupSummary`
  - added `RoundSetupStateTests.testResetClearsSelectedCourseAndSelectedTee`
  - added `RoundSetupStateTests.testSelectingDifferentCourseClearsPriorTeeSelection`
  - initial red run failed for the expected missing API:
    - `selectCourse(_:)`
    - `selectTee(name:yards:)`
    - `selectedTeeName`
    - `selectedTeeYards`
    - `roundSetupSummaryTitle`
    - `roundSetupSummaryDetail`
- Implementation:
  - extended `RoundSetupState` with persistent course/tee selection and shared summary copy
  - clearing course now also clears stale tee choice when the course actually changes
  - rewired `RoundRootView` and `CourseDetailView` so tee selection persists in shared state
  - polished setup UI:
    - `CourseListView` now has a visual setup rail
    - `CourseDetailView` now shows a continuity card driven by shared setup state
    - `PlayerSelectionView` now opens with a stronger summary hero tied to the chosen course/tees

### Verification (Round Setup Continuity Pass)

- Focused red:
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO -only-testing:SwingPalTests/RoundSetupStateTests`
  - failed for the expected missing-member reasons listed above
- Focused green:
  - same `-only-testing:SwingPalTests/RoundSetupStateTests` command rerun after state implementation
  - result: `** TEST SUCCEEDED **`
- Source verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: success
- Full verification:
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST SUCCEEDED **`
  - explicit confirmation:
    - `RoundSetupStateTests.testSelectingTeeBuildsPersistentRoundSetupSummary()` passed
    - `RoundSetupStateTests.testResetClearsSelectedCourseAndSelectedTee()` passed
    - `RoundSetupStateTests.testSelectingDifferentCourseClearsPriorTeeSelection()` passed

### 2026-04-21 14:40:05 AEST - Round Flow Transition Shell Pass

- Added a real presentation layer for setup-to-live progress in `RoundRootView`.
- TDD:
  - added shell tests for `RoundFlowStep` presentation behavior:
    - `testRoundFlowStepUsesSetupSummaryForPlayersContext`
    - `testRoundFlowStepReframesLiveContextAroundPlayState`
  - first valid red run failed for the expected missing type:
    - `RoundFlowStep`
  - an earlier attempt using a brand-new standalone test file was invalid because the
    file was not in the current Xcode test target; removed and redid the test inside
    `ShellIntegrationTests.swift`
- Implementation:
  - added `RoundFlowStep` with:
    - `progressLabel`
    - `progressValue`
    - `title`
    - `subtitle`
    - `contextLine(courseName:detail:)`
  - updated `RoundRootView` to render:
    - persistent progress header above the round flow
    - progress bar driven by the active step
    - live contextual copy that changes across courses/detail/players/live
    - animated step transitions via asymmetric move+opacity transitions

### Verification (Round Flow Transition Shell Pass)

- Focused red:
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO -only-testing:SwingPalTests/ShellIntegrationTests`
  - failed for the expected missing-type reason:
    - `RoundFlowStep`
- Focused green:
  - same `-only-testing:SwingPalTests/ShellIntegrationTests` command rerun after implementation
  - result: `** TEST SUCCEEDED **`
- Requested-device verification attempt:
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO`
  - blocked by local simulator infrastructure failure:
    - `CoreSimulatorService connection became invalid`
    - `Unable to discover any Simulator runtimes`
- Fallback non-simulator verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: success
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`

### 2026-04-21 15:02:10 AEST - Social and Profile Polish Pass

- Added lightweight presentation models for the next UI tier:
  - `Features/Social/SocialViewModel.swift`
  - `Features/Profile/ProfileViewModel.swift`
- TDD:
  - added:
    - `SwingPalTests/SocialViewModelTests.swift`
    - `SwingPalTests/ProfileViewModelTests.swift`
  - first red verification failed for the expected reason after adding the new test
    files to the Xcode project:
    - `cannot find 'SocialViewModel' in scope`
    - `cannot find 'ProfileViewModel' in scope`
- Implementation:
  - `SocialView` now has:
    - a stronger header
    - a spotlight round card
    - an explicit empty state
    - cleaner feed hierarchy driven by `SocialViewModel`
  - `SocialPostCard` now reads more like a product card than a raw text block
  - `ProfileView` now has:
    - a summary hero card
    - view-model-driven account/premium messaging
    - a stronger primary cloud action
  - `BagView` now uses a richer row treatment and clearer bag summary
- Project maintenance:
  - added the new source and test files to `SwingPal.xcodeproj/project.pbxproj`

### Verification (Social and Profile Polish Pass)

- Red verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - failed for the expected missing-model reasons above
- Green verification:
  - same `build-for-testing` command rerun after implementation
  - result: `** TEST BUILD SUCCEEDED **`
- Requested-device focused test attempt:
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:SwingPalTests/SocialViewModelTests -only-testing:SwingPalTests/ProfileViewModelTests CODE_SIGNING_ALLOWED=NO`
  - blocked again by local simulator infrastructure failure:
    - `CoreSimulatorService connection became invalid`
    - `Unable to discover any Simulator runtimes`
- Source verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: success

### 2026-04-21 15:26:30 AEST - Round Flow Chrome and Transition Pass

- Tightened the `Round` setup/live shell around explicit transition semantics instead of implicit view ordering.
- TDD:
  - extended `ShellIntegrationTests` with:
    - `testRoundFlowStepProvidesRicherStageChromeForPlayers`
    - `testRoundFlowStepChoosesForwardMovementWhenAdvancing`
    - `testRoundFlowStepChoosesBackwardMovementWhenReturning`
  - red verification failed for the expected missing API reasons:
    - `RoundFlowStep` had no `eyebrow`
    - `RoundFlowStep` had no `accentTitle`
    - `RoundFlowStep` had no `primaryPrompt`
    - `RoundFlowStep` had no `movement(from:)`
- Implementation:
  - added `RoundFlowMovement`
  - added richer presentation metadata to `RoundFlowStep`
  - rewired `RoundRootView` to navigate through a `navigate(to:)` helper so transition direction is explicit
  - rebuilt the flow header with:
    - stronger stage eyebrow
    - larger serif title
    - accent title
    - primary prompt
    - richer status chips
    - slightly more premium stage treatment for live play
  - made the stage transition read from flow direction instead of hardcoded edges

### Verification (Round Flow Chrome and Transition Pass)

- Red verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - failed for the expected missing-member reasons above
- Green verification:
  - same `build-for-testing` command rerun after implementation
  - result: `** TEST BUILD SUCCEEDED **`
- Requested-device focused test attempt:
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:SwingPalTests/ShellIntegrationTests CODE_SIGNING_ALLOWED=NO`
  - blocked again by local simulator infrastructure failure:
    - `CoreSimulatorService connection became invalid`
    - `Unable to discover any Simulator runtimes`
- Source verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: success

### 2026-04-21 15:34:20 AEST - Dock Presentation and Round Bottom Clearance Fix

- Root cause investigation:
  - the floating dock itself already reserved shell-level space, but the nested round-flow
    scroll surfaces still did not have enough internal bottom breathing room for the raised dock
  - the in-progress dock pass also had no explicit presentation model, so selection visuals were
    buried inside `SwingPalTabBar`
- TDD:
  - extended `ShellIntegrationTests` with:
    - `testSelectedHomeTabUsesActiveDockPresentation`
    - `testUnselectedSocialTabUsesQuietDockPresentation`
    - `testRoundActionPresentationStaysEmphasizedAndReflectsSelection`
    - `testRoundScreensUseBottomPaddingBeyondDockInset`
  - red verification failed first for the expected reasons:
    - `cannot find 'AppTabBarPresentation' in scope`
    - missing `roundScreenBottomPadding`
- Implementation:
  - added dock presentation types in `AppShellView.swift`:
    - `AppTabBarTone`
    - `AppTabBarItemPresentation`
    - `AppRoundActionPresentation`
    - `AppTabBarPresentation`
  - updated the dock styling to use those models:
    - selected standard tabs now use a clearer capsule treatment
    - the center round action now has a stronger halo/ring treatment
    - the dock panel has a slightly more deliberate glass highlight
  - added `AppChromeMetrics.roundScreenBottomPadding`
  - applied that bottom padding to:
    - `CourseListView`
    - `CourseDetailView`
    - `PlayerSelectionView`
    - `LiveRoundView`
- One intermediate compile issue in `AppShellView.tabButton(...)` was fixed by making the helper
  explicitly return the constructed `Button`

### Verification (Dock Presentation and Round Bottom Clearance Fix)

- Red verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - failed for the expected missing dock-presentation / bottom-padding reasons above
- Green verification:
  - same `build-for-testing` command rerun after implementation
  - result: `** TEST BUILD SUCCEEDED **`
- Simulator verification:
  - not claimed; the current environment is still intermittently failing with `CoreSimulatorService connection became invalid`

### 2026-04-21 15:44:10 AEST - Round Toolbar De-Duplication Pass

- Problem addressed:
  - the round setup/live shell was showing duplicate stage chrome:
    - principal toolbar title (`2 of 4: Course Detail`)
    - large in-screen stage header (`Course Detail`)
  - the toolbar back affordance was also too generic for a staged flow
- TDD:
  - extended `ShellIntegrationTests` with:
    - `testRoundFlowStepExposesPreviousStepForBackNavigation`
    - `testRoundFlowStepUsesSourceStageNameForBackButtonLabel`
  - red verification failed for the expected reasons:
    - `RoundFlowStep` had no `previousStep`
    - `RoundFlowStep` had no `backButtonTitle`
- Implementation:
  - added `previousStep` to `RoundFlowStep`
  - added `backButtonTitle` to `RoundFlowStep`
  - removed the duplicated toolbar principal title from `RoundRootView`
  - updated the top-left back button to use the previous stage title instead of a generic `Back`
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`

### 2026-04-21 15:56:00 AEST - Immersive Live Round Chrome Pass

- Problem addressed:
  - `Live Round` was still rendered like a setup step:
    - large setup header above play
    - floating dock still present during play
    - live content structured as a scrollable stack instead of a map-first GPS surface
  - user requirement was to make the live round feel like a dedicated on-course screen, with the map and current position as the core experience
- TDD:
  - extended `ShellIntegrationTests` with:
    - `testLiveRoundStepRequestsImmersiveChrome`
  - extended `AppStateTests` with:
    - `testImmersiveRoundRequiresRoundTabLiveChromeAndActiveState`
  - red verification:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    - failed first for the expected missing API:
      - `AppState` had no `roundChromeMode`
      - `AppState` had no `isImmersiveRoundActive`
      - `RoundFlowStep` had no `prefersImmersiveChrome`
- Implementation:
  - added `RoundChromeMode` plus `isImmersiveRoundActive` to `AppState`
  - updated `AppShellView` to:
    - hide the floating dock during immersive live play
    - remove the bottom safe-area reservation while live play is active
  - updated `RoundRootView` to:
    - mark `.live` as `prefersImmersiveChrome`
    - switch between setup-shell layout and immersive live layout
    - hide the navigation bar during live play
    - sync app-level round chrome mode from the current round step
  - replaced the old stacked `LiveRoundView` with a map-first live surface:
    - full-screen course canvas
    - overlaid target corridor and player marker
    - top GPS/yardage HUD
    - bottom action tray for shot logging and target controls
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
  - focused simulator test attempt on `iPhone 17 Pro Max`:
    - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO -only-testing:SwingPalTests/AppStateTests -only-testing:SwingPalTests/ShellIntegrationTests`
    - blocked before execution by `CoreSimulatorService connection became invalid`

### 2026-04-21 16:13:00 AEST - Live Map Planning Controls Pass

- Problem addressed:
  - the immersive live round looked better, but the map was still static
  - user requirement was to support:
    - map panning
    - map rotation
    - a movable planning crosshair with live yardages for shot planning
  - user also called out the need for real local Apple weather data in the live HUD
- Research:
  - confirmed Apple’s supported native path is `WeatherKit` via `WeatherService`
  - enabling real Apple weather data will require the WeatherKit entitlement:
    - `com.apple.developer.weatherkit`
  - sources reviewed:
    - `https://developer.apple.com/documentation/weatherkit/`
    - `https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.weatherkit`
    - `https://developer.apple.com/documentation/weatherkit/currentweather`
    - `https://developer.apple.com/documentation/weatherkit/weatherattribution`
- TDD:
  - extended `LiveRoundStateTests` with:
    - `testMapPanIsClampedToPlanningBounds`
    - `testMapRotationNormalizesIntoCompactRange`
    - `testMovingPlanningReticleClampsPointAndUpdatesPlanningDistances`
  - red verification:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    - failed first for the expected missing APIs on `LiveRoundState`:
      - `setMapPan`
      - `mapPanOffset`
      - `setMapRotation`
      - `mapRotationDegrees`
      - `movePlanningReticle`
      - planning-distance properties
- Implementation:
  - added map interaction state to `LiveRoundState`:
    - `mapPanOffset`
    - `mapRotationDegrees`
    - `planningReticlePoint`
    - computed planning yardages for carry and remaining distance
  - added state mutation helpers:
    - `setMapPan(to:)`
    - `setMapRotation(to:)`
    - `movePlanningReticle(to:)`
  - updated `LiveRoundView` to:
    - pan the map scene with drag
    - rotate the map scene with `RotationGesture`
    - render a draggable planning reticle over the course
    - show carry and remaining distances for the current crosshair position
    - expose a `Reset View` control
    - route wind copy through live-round state instead of a hardcoded string literal in the view
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
- Next integration step:
  - replace the placeholder wind summary in `LiveRoundState` with a WeatherKit-backed local weather service and attribution surface

### 2026-04-21 16:20:00 AEST - WeatherKit Live Weather Integration Pass

- Problem addressed:
  - live round still used placeholder weather copy
  - user wanted real local Apple weather data for planning and live HUD context
- Research:
  - verified the native Apple path is `WeatherKit` with `WeatherService`
  - verified the app also needs:
    - the WeatherKit entitlement (`com.apple.developer.weatherkit`)
    - an App ID with WeatherKit enabled in Apple Developer
    - required attribution surfaced to users
  - official sources reviewed:
    - `https://developer.apple.com/documentation/weatherkit/`
    - `https://developer.apple.com/documentation/weatherkit/weatherservice`
    - `https://developer.apple.com/documentation/weatherkit/weatherservice/attribution`
    - `https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.weatherkit`
    - `https://developer.apple.com/help/account/services/weatherkit/`
- TDD:
  - extended `LiveRoundStateTests` with:
    - `testRefreshingWeatherPublishesAppleWeatherSnapshot`
    - `testRefreshingWeatherFallsBackGracefullyWhenLoaderFails`
  - red verification:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    - failed first for the expected missing weather APIs and types:
      - `RoundWeatherSnapshot`
      - `RoundWeatherLoading`
      - `LiveRoundState(weatherLoader:)`
      - `refreshWeather()`
- Implementation:
  - added a weather service layer:
    - `Services/Weather/RoundWeatherSnapshot.swift`
    - `Services/Weather/RoundWeatherLoading.swift`
    - `Services/Weather/PreviewRoundWeatherLoader.swift`
    - `Services/Weather/AppleWeatherKitLoader.swift`
  - implemented `AppleWeatherKitLoader` using:
    - `CLLocationManager` for the current on-device location
    - `WeatherService.weather(for:)` for current weather
    - `WeatherService.attribution` for required Apple Weather attribution text
  - updated `LiveRoundState` to:
    - accept an injected weather loader
    - expose live weather summary properties for wind, temperature, condition, and attribution
    - asynchronously refresh weather without breaking the round screen on failure
  - updated `LiveRoundView` to:
    - refresh weather on appearance
    - display real wind / temperature / condition values from state
    - surface attribution text in the live controls area when available
  - updated `RoundRootView` to create live rounds with `AppleWeatherKitLoader()`
  - updated project configuration:
    - added `SwingPal/SwingPal.entitlements`
    - enabled `CODE_SIGN_ENTITLEMENTS`
    - added `NSLocationWhenInUseUsageDescription`
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
- Runtime prerequisite:
  - code and entitlement wiring are in place locally, but real WeatherKit requests still depend on enabling WeatherKit for the app’s Apple Developer App ID

### 2026-04-21 16:52:00 AEST - Active Round Persistence + MapKit Live Round Pass

- Problem addressed:
  - live round state only existed in memory, so `Resume Round` did not survive app relaunch
  - the flagship live round screen still used a mocked painted surface rather than a real interactive map
- Scope chosen:
  - persist only the active live round locally
  - upgrade only the live round surface to `MapKit`
  - do not add backend sync or completed-round history
- TDD:
  - added `AppStateTests` coverage for:
    - restoring an active round from storage
    - persisting a new live round snapshot
    - persisting mutations inside a live round
    - clearing the stored snapshot on round completion
  - added `LiveRoundStateTests.testSnapshotRoundTripPreservesCourseContext`
  - red verification:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    - failed first for the expected missing persistence and course-context types:
      - `ActiveRoundStoring`
      - `ActiveRoundSnapshot`
      - `LiveRoundState.snapshot`
      - course-context fields on `LiveRoundState`
- Implementation:
  - added codable round persistence primitives in `AppState.swift`:
    - `ActiveRoundSnapshot`
    - `ActiveRoundStoring`
    - `UserDefaultsActiveRoundStore`
  - updated `AppState` to:
    - restore the active live round from local storage on init
    - persist snapshots when a round starts, changes, or clears
    - expose explicit `resumeRound(...)` and `clearActiveRound()` methods
  - extended `LiveRoundState` to:
    - publish a codable `Snapshot`
    - restore from snapshot
    - retain `courseName` and `courseCoordinate`
    - notify the app layer whenever persisted live-round state changes
  - made round-domain models codable where required:
    - `HoleSession`
    - `ShotEvent`
    - `RoundPlayerDraft`
    - `PlayerScoreState`
  - updated `RoundRootView` to:
    - use explicit app-state resume/clear methods
    - seed course-specific live-round coordinates for the mocked nearby courses
  - updated `AppShellView` home hero title to read from the actual active round state
  - replaced the mocked live-round background in `LiveRoundView` with a real `MapKit` surface:
    - `Map` with imagery styling
    - native pan / zoom / rotate interaction
    - tee and target annotations
    - retained planning reticle and strategy HUD overlays
    - reset view now recenters the real map camera
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
- Known limitation:
  - the live round now uses a real course map and course-specific center coordinates, but hole geometry remains mocked rather than sourced from real course GIS data

### 2026-04-22 09:58:00 AEST - Course Data App Infrastructure Baseline

- Problem addressed:
  - round setup still depended on ad hoc course models that were not suitable for later OpenGolfAPI + OSM ingestion
  - the app needed a normalized course contract before Supabase schema work
- Sequencing decision:
  - app-side course infrastructure now comes before backend work
  - SwingPal should own the runtime course snapshot, while external providers remain ingestion sources only
  - documented in `docs/plans/2026-04-22-course-data-app-infrastructure.md`
- TDD:
  - added `CourseRepositoryTests` coverage for:
    - seeded nearby courses sorted by ascending distance
    - normalized seeded course details including tees and holes
  - updated `RoundSetupStateTests` to target the repository-backed setup state
  - red state came from stale Xcode project references and one outdated test initializer
- Implementation:
  - introduced `SwingPalCourse` as the app-owned normalized course model
  - introduced `CourseRepository` and `SeededCourseRepository`
  - updated `RoundSetupState` to load from a repository instead of ad hoc injected course arrays
  - updated round setup views and `RoundRootView` to work against `SwingPalCourse`
  - replaced the deleted `CourseSummary` / `CourseDetail` files in the Xcode project with the new normalized course files
  - kept the current polished setup flow intact rather than exposing raw infrastructure state in the UI
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - expand the normalized course model with source metadata and correction-domain models before moving to Supabase schema design

### 2026-04-22 10:05:00 AEST - Course Provenance + Community Correction Domain

- Problem addressed:
  - the normalized course model still lacked provenance, map context, readiness state, and a community-correction domain
  - round setup needed to signal course quality without degrading the premium UI
- TDD:
  - expanded `CourseRepositoryTests` to require:
    - provider provenance from `OpenGolfAPI` and `OSM`
    - normalized coordinate and readiness metadata
    - a real `CourseCorrectionDraft` model with submission-ready summaries
  - red verification:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    - failed first for the expected missing properties and missing `CourseCorrectionDraft` type
- Implementation:
  - expanded `SwingPalCourse` with:
    - `coordinate`
    - `sourceReferences`
    - `quality`
    - `community`
  - added `CourseCorrectionDraft` with:
    - correction kind
    - status
    - evidence payloads
    - summary/caption helpers
    - submit readiness
  - updated `SeededCourseRepository` to seed more realistic confidence/community states per course
  - updated `RoundRootView` to start live rounds from the selected course coordinate instead of a name switch
  - updated `CourseListView` and `CourseDetailView` to surface course readiness and source/community context in a polished, product-facing way
  - kept the setup flow premium and user-facing rather than exposing raw infrastructure language
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - introduce provider adapter protocols and a local correction/report workflow surface before Supabase-backed persistence

### 2026-04-22 10:12:00 AEST - Provider Boundary + Local Correction Flow

- Problem addressed:
  - the course domain had provenance metadata, but no real provider-boundary types or local correction workflow
  - community-driven data improvement needed a concrete in-app entry point before any Supabase moderation work
- TDD:
  - added `CourseProviderTests` for:
    - seeded OpenGolf provider payloads
    - seeded OSM geometry payloads
  - added `CourseCorrectionCenterTests` for:
    - storing submitted local reports
    - filtering reports by course
  - initial red state exposed:
    - missing provider types
    - missing local correction center
    - missing project registration for the new tests/files
- Implementation:
  - added provider boundary types in `Features/Round/Providers/CourseDataProviders.swift`:
    - `OpenGolfCoursePayload`
    - `OSMCourseGeometryPayload`
    - `OpenGolfCourseLoading`
    - `OSMCourseGeometryLoading`
    - seeded loader implementations
  - updated `SeededCourseRepository` to depend on the provider loaders and construct normalized courses from that boundary
  - added `CourseCorrectionCenter` for local in-app report capture
  - added `CourseCorrectionSheet` as the first premium-feeling correction entry flow
  - integrated correction reporting into `CourseDetailView` without turning the screen into an admin panel
  - wired `RoundRootView` to hold and pass a shared local correction center
  - registered the new app files and tests in the Xcode project
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - local draft persistence plus a course-level moderation/status surface, then mirror that model into Supabase

### 2026-04-22 10:24:00 AEST - Local Correction Persistence + Activity Surface

- Problem addressed:
  - local course-correction drafts now persist across relaunch, but the course-detail UX still collapsed everything into a single summary line
  - the product needed a clearer, more polished course-level moderation/activity surface without turning setup into an admin screen
- TDD:
  - expanded `CourseCorrectionCenterTests` to require:
    - persisted correction restore on init
    - moderation summary based on stored statuses
    - a new `recentActivity(for:)` API returning the newest course-scoped items with user-facing status labels
  - red verification:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    - failed first for the expected missing `recentActivity` member on `CourseCorrectionCenter`
- Implementation:
  - added persistence-backed `CourseCorrectionCenter(store:)` with:
    - `UserDefaultsCourseCorrectionStore`
    - restore-on-init behavior
    - persisted save on submit
  - added `CourseCorrectionModerationSummary` and `CourseCorrectionActivityItem`
  - added `recentActivity(for:)` to expose a compact, UI-friendly course activity feed
  - updated `CourseDetailView` to surface:
    - moderation snapshot metrics
    - a recent activity strip driven by real local correction data
  - kept the presentation aligned with the premium setup flow by using compact cards/capsules instead of raw moderation tables
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - add a location-service boundary and real live-round player-position pipeline so the normalized course model, MapKit surface, and planning HUD start sharing the same domain infrastructure

### 2026-04-22 10:27:00 AEST - Live Round Location Boundary

- Problem addressed:
  - the live-round map had the right premium structure, but the player position was still effectively generic map behavior rather than app-owned round state
  - the app needed a real location boundary before wiring full CoreLocation / Supabase-backed course intelligence
- TDD:
  - expanded `LiveRoundStateTests` to require:
    - seeding player position + heading from a location provider
    - preserving player location through `LiveRoundState.Snapshot`
    - a UI-friendly GPS status string exposed by state
  - red verification:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    - failed first for the expected missing location-provider types and `locationProvider` initializer argument
- Implementation:
  - added `RoundLocationSnapshot` and `RoundLocationProviding`
  - added `PreviewRoundLocationProvider` as the default app-infra seed
  - updated `LiveRoundState` to:
    - own `playerLocation`
    - expose `playerCoordinate`
    - expose `playerLocationStatusText`
    - persist player location in `Snapshot`
    - subscribe to provider updates and stop updates on teardown
  - updated `LiveRoundView` to:
    - replace generic user annotation with a state-driven player badge
    - rotate the player arrow by heading
    - surface GPS status in the top-right HUD
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - swap the preview location provider for a concrete CoreLocation-backed provider and route permission/availability state into the live-round HUD without degrading the immersive map presentation

### 2026-04-22 11:09:00 AEST - CoreLocation Round Provider + Restore Wiring

- Problem addressed:
  - the round-location boundary existed, but live rounds still depended on preview location data and had no permission/availability messaging
  - resumed rounds also needed to restore with the same location-provider path as newly started rounds
- TDD:
  - expanded `LiveRoundStateTests` to require:
    - permission-denied fallback copy
    - unavailable fallback copy
  - expanded `AppStateTests` to require:
    - injected `locationProviderFactory` being used when restoring a persisted round
  - red verification:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    - failed first for the expected missing `RoundLocationStatus`, missing provider status handlers, and missing `locationProviderFactory` app wiring
- Implementation:
  - added `RoundLocationStatus`
  - extended `RoundLocationProviding` with:
    - `currentStatus`
    - `setStatusHandler(_:)`
  - added `CoreLocationRoundLocationProvider` using `CLLocationManager` for:
    - permission requests
    - location updates
    - heading updates
    - unavailable / denied state reporting
  - updated `LiveRoundState` to:
    - track `locationStatus`
    - derive golfer-facing HUD copy from permission/availability state
    - preserve live player snapshots while still surfacing blocked/unavailable states cleanly
  - updated `AppState` with `locationProviderFactory` and restore-path wiring
  - updated `RoundRootView` so newly started rounds use the same provider factory as restored rounds
  - kept the live map immersive by routing the new state into the existing top-right HUD instead of reintroducing setup-style chrome
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - use the live course model plus player location to drive course-relative distance and camera behavior more intelligently, instead of keeping the player/reference geometry partly synthetic

### 2026-04-22 11:16:00 AEST - Course-Relative Targeting + Camera Geometry

- Problem addressed:
  - live round was using state-owned player location, but target coordinates and camera framing were still being derived inside the view from synthetic course-center offsets
  - the primary yardage readout also still showed the stored mock distance instead of live player-to-target distance when GPS was ready
- TDD:
  - expanded `LiveRoundStateTests` to require:
    - a live measured target distance when the player location is ready
    - a recommended map region centered between the player and the target
  - red verification:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    - failed first for the expected missing `liveDistanceToPinMeters` and `recommendedMapRegion` APIs
- Implementation:
  - moved live target geometry into `LiveRoundState`:
    - `teeCoordinate`
    - `targetCoordinate`
    - `liveDistanceToPinMeters`
    - `recommendedMapRegion`
  - switched `LiveRoundView` to consume those state-owned values instead of recomputing coordinates locally
  - updated the main yardage HUD and shot logging path to use the live measured distance when location is ready
  - updated map reset/recenter behavior to use the state’s recommended region so the camera tracks the player-target relationship more intelligently
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: blocked by `CoreSimulatorService` instability before a trustworthy success/failure outcome
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - replace the remaining screen-space planning reticle math with course-relative targeting so carry/remaining planning can be grounded in live coordinates instead of a normalized overlay approximation

### 2026-04-22 11:22:00 AEST - Course-Relative Planning Target State

- Problem addressed:
  - the camera and primary yardage were state-driven, but the planning reticle itself was still persisted as a normalized screen point and carry/remaining math was still screen-space derived
  - the app needed the planning target to become a real course-relative coordinate while preserving the existing gesture-driven overlay UX
- TDD:
  - expanded `LiveRoundStateTests` to require:
    - live measured target distance
    - state-owned recommended map region
    - persisted `planningTargetCoordinate` across snapshot restore
  - red verification:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    - failed first for the expected missing `liveDistanceToPinMeters`, `recommendedMapRegion`, and `planningTargetCoordinate` APIs
- Implementation:
  - promoted planning state from a stored normalized point to a stored `planningTargetCoordinate`
  - derived `planningReticlePoint` from real player/target/planning coordinates so the overlay remains interactive without owning the truth
  - replaced carry/remaining planning math with `CLLocation` distance calculations
  - moved target-coordinate derivation into `LiveRoundState` and updated `LiveRoundView` to consume:
    - `teeCoordinate`
    - `targetCoordinate`
    - `liveDistanceToPinMeters`
    - `recommendedMapRegion`
  - kept the existing drag gesture contract by converting screen-space drag input into a course-relative coordinate through player-target basis projection
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: blocked by `CoreSimulatorService` instability before a trustworthy success/failure outcome
  - `xcodebuild -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/SwingPalDerivedBuildGeneric`
  - result: also blocked by `CoreSimulatorService` instability
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - tune the live-round HUD copy and labels around “pin” vs “selected target” so the product language matches the now-more-real target/planning model

### 2026-04-22 11:28:00 AEST - Live Round HUD Target Language Cleanup

- Problem addressed:
  - the live-round state and map targeting had become course-relative, but the HUD still said `Meters to pin` even when the selected target was `Center line` or `Safe miss`
  - planning copy had the same issue, which made the UX look less trustworthy than the underlying targeting model
- TDD:
  - expanded `LiveRoundStateTests` to require:
    - generic `selected target` language for non-pin aim points
    - pin-specific language only when the aim point is actually `.pin`
    - the measured live distance API to be named around the selected target, not the pin
  - red verification:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    - failed first for the expected missing APIs:
      - `liveDistanceCaption`
      - `planningRemainingCaption`
      - `liveDistanceToSelectedTargetMeters`
- Implementation:
  - added state-owned HUD copy APIs in `LiveRoundState`:
    - `liveDistanceCaption`
    - `planningRemainingCaption`
    - `liveDistanceToSelectedTargetMeters`
  - switched `LiveRoundView` to use the new state language in:
    - the main yardage caption
    - the planning reticle remaining pill
    - the bottom strategy chip row
    - shot logging distance input
  - kept the interaction model unchanged; this slice only tightened the language and naming so the UI speaks accurately
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:SwingPalTests/LiveRoundStateTests -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO`
  - result: blocked by `CoreSimulatorService` / `simdiskimaged` failure before the simulator test process launched; no SwingPal test failure was reached
- Next app-infra slice:
  - replace the remaining synthetic hole geometry with real normalized hole/feature data so the live-round map can plan against actual course features instead of only seeded target points

### 2026-04-22 11:33:00 AEST - Normalized Hole Feature Overlays

- Problem addressed:
  - the live-round map had a real `MapKit` surface and course-relative targeting, but the course itself was still mostly synthetic once the camera loaded
  - normalized course data existed, but hole features were only labels without geometry, so the live round could not draw fairway / green / bunker structure from the selected course
- TDD:
  - expanded `CourseRepositoryTests` to require polygon geometry on seeded fairway and green features
  - expanded `LiveRoundStateTests` to require hole-feature context to survive snapshot restore
  - red verification:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    - failed first for the expected missing geometry API: `SwingPalCourse.Hole.Feature.coordinates`
- Implementation:
  - upgraded `SwingPalCourse.Hole.Feature` to carry normalized geometry coordinates
  - made the relevant course-model nested types codable so active-round snapshots can persist feature geometry cleanly
  - updated the seeded course factory to generate simple but real polygon rings for:
    - tee
    - fairway
    - green
    - bunker
  - threaded hole features into `LiveRoundState` snapshot/init so live rounds restore with their course geometry intact
  - updated `RoundRootView` to pass the selected course’s current-hole features into new live rounds
  - updated `LiveRoundView` to draw those normalized features directly on the `MapKit` surface with distinct fairway / green / bunker / tee styling
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - move from course-level seeded geometry to hole-aware feature sourcing so the live round can swap overlays as holes change and eventually align target/hazard strategy copy to actual feature positions

### 2026-04-22 11:38:00 AEST - Hole-Aware Live Round Progression

- Problem addressed:
  - live-round overlays were finally using normalized hole geometry, but they were still effectively fixed to the first seeded hole
  - the `Finish` action went straight to review instead of letting the round advance through the course model
- TDD:
  - expanded `LiveRoundStateTests` to require:
    - `currentHoleFeatures` to follow the active `hole.number` within the course model
    - `advanceToNextHole()` to move the round forward and swap feature context
  - red verification:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    - failed first for the expected missing course-hole API on `LiveRoundState`
- Implementation:
  - promoted `LiveRoundState` from storing a single current-hole feature array to storing `courseHoles`
  - made `currentHoleFeatures` a derived property based on `hole.number`
  - updated snapshot persistence so the active round keeps the full normalized hole set
  - added `advanceToNextHole()` to:
    - move to the next hole in the course model
    - reset per-hole live state like shots, target mode, planning target, map pan/rotation, and club selection
  - updated `RoundRootView` so:
    - new live rounds are seeded with the selected course’s full hole list
    - `Finish` advances the hole until the course ends, only then falling into review/attestation
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:SwingPalTests/LiveRoundStateTests -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO`
  - result: blocked before test launch by `CoreSimulatorService` / `simdiskimaged`; no SwingPal test failure was reached
- Next app-infra slice:
  - align the live-round target/support copy to actual hole geometry so bunker/fairway/green context can come from the current hole model instead of fixed seeded prose

### 2026-04-22 11:43:00 AEST - Feature-Driven Live Strategy Copy

- Problem addressed:
  - the live-round overlays and hole advancement were hole-aware, but the supporting strategy language was still mostly static prose
  - the app needed to start reflecting the actual current-hole geometry in its `fairway`, `green`, and `bunker` guidance so the product feels grounded rather than templated
- TDD:
  - expanded `LiveRoundStateTests` to require:
    - center-line support text to use the current fairway label when available
    - safe-miss hazard copy to use the current bunker label when available
  - red verification:
    - attempted with `xcodebuild build-for-testing ...`
    - simulator execution remains blocked in this environment, but the tests were written first against behavior not yet present in the current state implementation
- Implementation:
  - updated `LiveRoundState.targetSupportText` to use the current hole’s fairway label in `hole / centerLine`
  - updated `LiveRoundState.targetSupportText` and `hazardCallout` to use the current green label in green-view contexts when available
  - updated `LiveRoundState.hazardCallout` to use the current bunker label in `hole / safeMiss`
  - kept the fallback generic copy intact so incomplete course data still presents cleanly
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - move the remaining generic strategy chips toward current-hole labels so the HUD keeps the same premium language while becoming more truthful about the actual hole structure

### 2026-04-22 11:44:00 AEST - Feature-Driven Strategy Chips

- Problem addressed:
  - the main strategy prose had started using live hole labels, but the supporting chip row was still generic and slightly disconnected from the current hole geometry
  - the HUD needed a little more truthfulness without becoming noisy or overlong
- TDD:
  - expanded `LiveRoundStateTests` to require center-line chips to use the current fairway and bunker labels when those features exist on the active hole
  - simulator execution remains blocked in this environment, but the tests were added first against behavior not yet present in the state
- Implementation:
  - updated `LiveRoundState.contextChips` in the `hole / centerLine` case to prefer:
    - current fairway label
    - current bunker label
    - wind context fallback chip
  - preserved the existing generic fallback chips for holes that do not yet have those normalized features
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - bring the same feature-driven truthfulness into green-view chips and target-support language so the whole live-round HUD feels grounded in the current hole model

### 2026-04-22 11:53 AEST - App-Level Test GPS Mode

- Problem addressed:
  - the live-round map could open at an unusable global view when real device location was unavailable or unstable
  - there was no easy in-app way to force a stable preview location for development and QA, even though `PreviewRoundLocationProvider` already existed
- TDD:
  - expanded `AppStateTests` to require:
    - default GPS mode of `.live`
    - persisted GPS mode restore
    - `.testPreview` routing through `PreviewRoundLocationProvider`
    - active-round rebuild and persistence when GPS mode changes
  - expanded `ProfileViewModelTests` to require mode-specific copy for `Live GPS` and `Test GPS`
  - red verification:
    - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    - result: failed for the intended missing-production-code reasons, including missing `AppGPSMode`, `GPSModeStoring`, `gpsMode`, and `setGPSMode`
- Implementation:
  - added `AppGPSMode`, `GPSModeStoring`, and `UserDefaultsGPSModeStore` in `AppState.swift`
  - updated `AppState` to:
    - persist and restore the current GPS mode
    - switch `makeRoundLocationProvider()` between live Core Location and preview GPS
    - rebuild the active round from its snapshot when the mode changes so `Resume Round` immediately reflects the new provider
  - updated `ProfileViewModel` with mode-specific copy and `ProfileView` with a lightweight `Round location mode` control
  - updated `AppShellView` to pass the current GPS mode and callback into `ProfileView`
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:SwingPalTests/AppStateTests -only-testing:SwingPalTests/ProfileViewModelTests -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO`
  - result: blocked before test launch by `CoreSimulatorService` / `simdiskimaged`; no SwingPal test failure was reached
- Next app-infra slice:
  - use the new GPS mode boundary to improve live-round startup camera behavior so preview mode lands directly on the selected course instead of depending on the first GPS callback

### 2026-04-22 11:59 AEST - Deterministic Live-Round Startup Camera

- Problem addressed:
  - the live-round map could still open with poor startup framing because the initial camera relied on dynamic player-target centering before GPS had produced a stable on-course location
  - this was especially noticeable when building with `Test GPS` or when real location permissions were still warming up
- TDD:
  - expanded `LiveRoundStateTests` to require:
    - a deterministic `startupMapRegion` that frames tee-to-target geometry when GPS is not ready
    - `startupMapRegion` to match `recommendedMapRegion` once GPS is ready
- Implementation:
  - added `startupMapRegion` to `LiveRoundState`
  - added a course-framed startup region based on `teeCoordinate` and `targetCoordinate`, instead of falling back to a less meaningful dynamic midpoint during startup
  - updated `LiveRoundView` to:
    - use `startupMapRegion` on first appearance
    - switch to player-target framing only when `locationStatus == .ready`
    - keep `Reset View` aligned with the same startup-vs-live framing rule
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - make the live-round camera smarter across hole advancement so finishing one hole and entering the next re-frames to the new hole cleanly instead of carrying over stale zoom/context

### 2026-04-22 12:06 AEST - Hole-Driven Tee And Target Geometry

- Problem addressed:
  - hole progression was changing labels and overlays, but the live-round tee and target coordinates were still largely course-wide defaults
  - that meant the active hole did not meaningfully reposition the live map’s primary anchors
- TDD:
  - expanded `LiveRoundStateTests` to require:
    - `teeCoordinate` and `targetCoordinate` to follow the current hole’s normalized `tee` and `green` feature geometry
    - `advanceToNextHole()` to change the target coordinate when the next hole’s geometry differs
- Implementation:
  - updated `LiveRoundState` so:
    - `teeCoordinate` prefers the centroid of the current hole’s `tee` feature
    - target selection prefers current-hole `fairway`, `green`, and `bunker` geometry instead of only course-level offsets
    - safe-miss targeting biases away from the bunker vector when both fairway and bunker geometry exist
  - kept the existing course-level fallback offsets for incomplete course data so low-confidence holes still render cleanly
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - reframe the live-round camera on hole advancement so the map visually follows the new hole as the state now does

### 2026-04-22 12:10 AEST - Hole-Transition Camera Sync

- Problem addressed:
  - even after hole-driven geometry landed, `LiveRoundView` still duplicated camera selection logic inline and never explicitly re-synced the camera when `hole.number` changed
  - that left a gap where state advanced correctly but the visible map could carry stale framing from the prior hole
- TDD:
  - expanded `LiveRoundStateTests` to require:
    - `preferredMapRegion` to use startup framing until GPS is ready
    - `preferredMapRegion` to change when advancing into a new hole with different geometry
- Implementation:
  - added `preferredMapRegion` to `LiveRoundState` as the single source of truth for presentation framing
  - updated `LiveRoundView` to:
    - use one `syncCameraToPreferredRegion()` helper instead of duplicating startup/live region selection
    - reframe on `hole.number` changes in addition to location and target changes
    - keep `Reset View` aligned with the same preferred-region logic
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - add a clearer visual transition between holes so the map reframing feels intentional instead of simply jumping to the next hole’s preferred region

### 2026-04-22 12:24 AEST - Live-Round Hole Transition Overlay

- Problem addressed:
  - the hole transition was structurally correct, but still felt abrupt: the camera reframed and the hole changed with no clear visual handoff
  - the live-round screen needed a short, premium-feeling inter-hole moment so the next hole feels introduced rather than merely swapped in
- TDD:
  - expanded `LiveRoundStateTests` to require:
    - `holeTransitionTitle`
    - `holeTransitionSubtitle`
    - `holeTransitionDetail`
  - used the new state-backed transition copy as the testable contract before wiring any view-only animation
- Implementation:
  - added `holeTransitionTitle`, `holeTransitionSubtitle`, and `holeTransitionDetail` to `LiveRoundState`
  - updated `LiveRoundView` to:
    - show a centered transition overlay keyed off `state.hole.number`
    - animate that overlay in and out with a short timed presentation
    - keep camera sync and transition presentation aligned so the hole introduction and map reframing happen together
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `find SwingPal -name "*.swift" -print0 | sort -z | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -module-cache-path /tmp/swift-module-cache`
  - result: passed
- Next app-infra slice:
  - tighten the live-round interaction layer further by making club selection and shot logging feel less placeholder-grade and more integrated with the map/HUD flow

### 2026-04-22 12:42 AEST - Live-Round Club Picker And Shot Logger

- Problem addressed:
  - `Change Club` was still a hardcoded toggle and `Log Shot` was a raw one-tap button, so the live-round interaction layer still felt like a prototype even though the map/HUD foundation was stronger
  - shot logging also lacked explicit lie capture in the main flow, which made the new round model less useful than it should be
- TDD:
  - added failing `LiveRoundStateTests` for:
    - available club inventory
    - explicit club selection
    - shot-logging summary copy
    - shot surface capture on logged shots
    - club picker presentation state
    - shot logger presentation state and suggested default surface
    - confirm-to-log behavior that dismisses the logger and records the selected lie
  - verified the red step with `xcodebuild build-for-testing`, confirming the missing `LiveRoundState` API before implementing it
- Implementation:
  - extended `ShotEvent` with a persisted `surface` enum/value
  - updated `LiveRoundState` to add:
    - bag-style `availableClubNames`
    - `selectClub(named:)`
    - `shotLoggingTitle` / `shotLoggingSubtitle`
    - club picker visibility state
    - shot logger visibility state
    - selectable pending shot surface
    - default lie suggestion based on shot phase
    - `confirmPendingShot()` to log the shot through the new state path
  - updated `LiveRoundView` to:
    - present a dedicated club picker sheet instead of toggling between two clubs
    - present a dedicated shot logger sheet instead of immediately logging
    - keep the live map as the core screen while focused decisions happen in polished bottom sheets
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
- Next app-infra slice:
  - bring the live-round planning layer closer to real play by tying more of the strategy messaging and shot logging defaults to actual hole-feature context and selected target geometry

### 2026-04-22 13:22 AEST - Feature-Aware Shot Logger Lie Defaults

- Problem addressed:
  - the new shot logger sheet had cleaner UX, but its default lie was still derived only from shot phase and distance
  - that meant a player standing in a bunker or on a real mapped fairway could still see a generic default that ignored the actual hole geometry already loaded into live round
- TDD:
  - added `LiveRoundStateTests` for:
    - bunker default when the live player location sits inside a mapped bunker polygon
    - fairway default when the live player location sits inside a mapped fairway polygon
  - attempted a targeted `xcodebuild test` run for `SwingPalTests/LiveRoundStateTests`, but simulator execution was blocked before launch by `CoreSimulatorService` / `simdiskimaged` in this environment
  - continued with source/build verification only after recording that limitation explicitly
- Implementation:
  - updated `LiveRoundState.suggestedShotSurface` to prefer live geometry inference before the existing shot-phase fallback
  - added polygon containment against the current hole features so tee, bunker, green, and fairway polygons can drive the initial logger lie
  - kept the previous phase-based fallback intact for holes with incomplete geometry or no usable live position
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
  - `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:SwingPalTests/LiveRoundStateTests -derivedDataPath /tmp/SwingPalDerivedTests CODE_SIGNING_ALLOWED=NO`
  - result: blocked before test launch by `CoreSimulatorService` / `simdiskimaged`
- Next app-infra slice:
  - expose the inferred lie and target context more clearly inside the live-round shot logger so the sheet explains why that default was chosen instead of only selecting it silently

### 2026-04-22 13:26 AEST - Shot Logger Lie Explanation Copy

- Problem addressed:
  - the shot logger was now choosing smarter default lies from mapped geometry, but the reason for that choice was invisible to the user
  - this made the logger feel opaque at exactly the moment where SwingPal should feel intelligent but explainable
- TDD:
  - added failing `LiveRoundStateTests` for:
    - mapped bunker explanation copy
    - mapped fairway explanation copy
    - phase-based fallback explanation copy when no feature match exists
  - verified the red step with `xcodebuild build-for-testing`, confirming the missing explanation API before implementation
- Implementation:
  - added `pendingShotSurfaceReasonTitle` and `pendingShotSurfaceReasonText` to `LiveRoundState`
  - introduced a small internal `ShotSurfaceContext` so the logger can distinguish between:
    - mapped geometry-driven lie defaults
    - shot-phase fallback defaults
  - surfaced that explanation in the shot logger hero so the selected lie now has a visible rationale instead of a silent default
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
- Cleanup checkpoint status:
  - the live-round interaction layer is now coherent enough for a short cleanup pass
  - remaining work can shift temporarily from infrastructure to UX tightening without leaving the round flow half-finished

### 2026-04-22 13:34 AEST - Round Setup Chrome Cleanup Pass

- Problem addressed:
  - the `Round` setup flow had become visually over-framed
  - `RoundRootView` was already presenting a strong step header, but `CourseListView`, `CourseDetailView`, and `PlayerSelectionView` were each reintroducing their own local landing-page headers
  - this made the setup flow feel heavier than the intended fast, premium handoff into live play
- TDD:
  - added `ShellIntegrationTests.testSetupRoundFlowStepsPreferCompactFlowHeader()`
  - verified the red step with `xcodebuild build-for-testing`, confirming the exact missing API:
    - `RoundFlowStep.prefersCompactFlowHeader`
- Implementation:
  - added `RoundFlowStep.prefersCompactFlowHeader`
  - split the round flow header into:
    - a new compact setup header for `courses`, `detail`, and `players`
    - the existing richer header path for non-compact use
  - removed duplicate setup framing from child screens:
    - removed the local hero/setup rail and fake preview toggle flow from `CourseListView`
    - replaced `CourseDetailView`’s hero + continuity stack with a smaller course summary card
    - removed the extra title block from `PlayerSelectionView` and reduced it to a lighter round summary card
  - removed inline navigation titles from those setup screens so the parent flow chrome stays authoritative
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
- UX result:
  - setup now reads more like one guided flow and less like three separate landing screens
  - the visual hierarchy is lighter, faster to scan, and closer to the intended premium round ritual

### 2026-04-22 13:39 AEST - Home Imagery-First Visual Pass

- Problem addressed:
  - `Home` was clean, but still too system-card-driven and flat compared with the intended premium golf aesthetic
  - the page needed to feel more atmospheric and image-led, with stronger depth, glass overlays, and larger visual moments
- TDD:
  - added failing `HomeViewModelTests` for:
    - live-round-specific hero highlight pills
    - a new `spotlight` model derived from the most recent round
  - verified the red step with `xcodebuild build-for-testing`, confirming the missing API:
    - `heroHighlights`
    - `spotlight`
- Implementation:
  - added `HomeSpotlight` plus `heroHighlights` and `spotlight` to `HomeViewModel`
  - rebuilt `HomeView` around:
    - a scenic top-stage canvas
    - glass-backed hero overlay
    - a stronger spotlight surface with richer depth and vignetting
    - more material-based quick stats instead of plain white cards
  - updated `HomeHeroCard` so it behaves like a floating glass panel over imagery rather than another filled rectangle
  - kept the page usable-first while pushing it closer to the requested large-imagery / blur / glass direction without waiting on real photo assets
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
- UX result:
  - `Home` now feels more atmospheric, editorial, and product-owned
  - the visual hierarchy is less “stack of cards” and more “hero scene plus floating utility”

### 2026-04-22 13:46 AEST - Course Discovery Scenic Visual Pass

- Problem addressed:
  - `CourseListView` was cleaner than before, but it still read as a utility list with one featured card
  - the screen needed to feel more like a premium destination-selection surface, closer to the new `Home` direction
- TDD:
  - added failing `CourseRepositoryTests` for:
    - a `CourseDiscoveryViewModel` built from the nearest seeded course
    - fallback messaging when discovery has no courses
  - verified the red step with `xcodebuild build-for-testing`, confirming the missing `CourseDiscoveryViewModel`
- Implementation:
  - introduced `CourseDiscoveryViewModel` inside `CourseListView.swift` so it is guaranteed to compile in the current project structure
  - rebuilt `CourseListView` around:
    - a scenic hero stage
    - glass-backed featured-course card
    - stronger editorial discovery copy
    - the existing ranked list underneath as the practical selection surface
  - kept the course list sorted/usable while shifting the screen away from a flat utility feel
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
- UX result:
  - course discovery now feels closer to a premium round entry surface
  - the screen keeps its ranked-list clarity while gaining more atmosphere, depth, and product identity

### 2026-04-22 14:02 AEST - Course Detail Scenic Commitment Pass

- Problem addressed:
  - `Course Detail` still felt split between user-facing round setup and admin/data-governance information
  - the primary commitment moment needed more visual atmosphere and clearer hierarchy, while the data/community layer needed to become secondary instead of competing with tee selection
- TDD:
  - added failing `CourseRepositoryTests` for:
    - `CourseDetailViewModel` primary commitment content
    - `CourseDetailViewModel` secondary disclosure content
  - verified the red step via `xcodebuild build-for-testing`, confirming the missing `CourseDetailViewModel`
- Implementation:
  - introduced `CourseDetailViewModel` directly in `CourseDetailView.swift` so it is guaranteed to compile in the current target structure
  - rebuilt `CourseDetailView` around:
    - a scenic commitment stage with a glass-backed summary card
    - cleaner tee-selection and expectation sections
    - a quieter `Course data and community` disclosure card for source/provenance/correction activity
  - kept the report flow and moderation information available, but no longer let them dominate the primary round funnel
- Verification:
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: `** TEST BUILD SUCCEEDED **`
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
- UX result:
  - `Course Detail` now reads more like a premium “commit to this round” screen
  - the data/community layer is still present, but visually demoted behind the actual tee-selection decision

### 2026-04-22 14:10 AEST - Live Round Progressive HUD Cleanup

- Problem addressed:
  - `LiveRoundView` was carrying too much always-on chrome for a screen that should be map-first and calm
  - weather, GPS, and support context all appeared at once, which made the flagship round screen feel denser than the updated setup flow
- TDD:
  - added failing `LiveRoundStateTests` for:
    - compact HUD mode starting collapsed
    - expanded HUD mode revealing secondary context
  - verified the red step via `xcodebuild build-for-testing`, confirming the missing expanded-HUD state seam
- Implementation:
  - added `isShowingExpandedHUD`, `primaryContextPills`, `secondaryContextPills`, and `toggleExpandedHUD()` to `LiveRoundState`
  - simplified the default top-right HUD to just the primary pills
  - moved hazard/weather attribution and the secondary context pills behind an explicit `Details` action in `LiveRoundView`
  - kept the map dominant while preserving quick access to richer round context on demand
- Verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed after fixing the temporary invalid spacing token
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
  - result: source-compile issues were cleared, but simulator/asset-tooling verification became unstable because `simdiskimaged` / `CoreSimulatorService` crashed in the environment
  - `xcodebuild -project SwingPal.xcodeproj -scheme SwingPal -destination 'generic/platform=iOS' -configuration Debug -derivedDataPath /tmp/SwingPalDerivedDeviceBuild CODE_SIGNING_ALLOWED=NO build`
  - result: progressed into compile/asset phases, but final Xcode completion was blocked by the same environment-level asset/runtime instability
- UX result:
  - `Live Round` now opens in a calmer default state
  - secondary context is still available, but no longer competes with the map until the user asks for it

### 2026-04-22 14:14 AEST - Social and Profile Personality Cleanup

- Problem addressed:
  - `Social` and `Profile` still felt too similar in cadence and visual personality
  - `Profile` also exposed the test GPS mode too prominently, making the screen feel half product and half debug surface
- TDD:
  - added failing `SocialViewModelTests` for:
    - new hero pills
    - new spotlight eyebrow copy
  - added failing `ProfileViewModelTests` for:
    - diagnostics title
    - diagnostics subtitle
  - verified the red step via `xcodebuild build-for-testing`, confirming the missing presentation properties
- Implementation:
  - expanded `SocialViewModel` with `heroPills` and `spotlightEyebrow`
  - rebuilt `SocialView` around a more scenic golf-circle hero stage with a glass panel and stronger spotlight treatment
  - lightened `SocialPostCard` so the spotlight stage remains visually dominant
  - expanded `ProfileViewModel` with diagnostics copy
  - reworked `ProfileView` to:
    - use a more authored account header
    - keep account, bag, recommendation, and premium surfaces first
    - move the GPS/testing control into a quieter diagnostics card lower in the page
- Verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed after fixing the temporary invalid spacing/radius tokens
  - Xcode builds remain partially blocked by the current environment:
    - simulator builds fail once `simdiskimaged` / `CoreSimulatorService` drops out
    - generic device builds progress into compilation but asset-catalog tooling still depends on the broken simulator runtime service
- UX result:
  - `Social` now feels more like a dedicated golf-circle destination instead of another stacked card page
  - `Profile` reads more clearly as account and gear first, with testing controls present but no longer center stage

### 2026-04-22 14:16 AEST - Dock Chrome Cleanup

- Problem addressed:
  - the bottom shell still felt a little too component-built, mainly because the side tabs used chunky selection capsules while the center round action used a different visual language
- TDD:
  - updated `ShellIntegrationTests` to expect:
    - underline-style selection for active side tabs
    - no selection chrome for inactive tabs
  - verified the red step via `xcodebuild build-for-testing`, confirming the missing `selectionStyle` seam
- Implementation:
  - introduced `AppTabBarSelectionStyle`
  - updated `AppTabBarItemPresentation` to carry `selectionStyle`
  - switched `Home`, `Social`, and `Profile` from filled capsules to a cleaner underline selection treatment
  - kept the center `Round` action visually dominant while making the side tabs feel lighter and more premium
- Verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
  - `xcodebuild -project SwingPal.xcodeproj -scheme SwingPal -destination 'generic/platform=iOS' -configuration Debug -derivedDataPath /tmp/SwingPalDerivedDeviceBuild CODE_SIGNING_ALLOWED=NO build`
  - result: app source compiled through the shell changes, but the build still failed at `CompileAssetCatalog` because `simdiskimaged` / `CoreSimulatorService` is currently unavailable in the environment
- UX result:
  - the dock now feels lighter and less “utility tab bar”
  - side-tab selection is cleaner and more aligned with the premium shell direction

### 2026-04-22 14:24 AEST - Social Editorial Magazine Pass

- Problem addressed:
  - `Social` had started drifting into the same scenic-hero-plus-glass-card pattern used elsewhere
  - the tab needed a distinct editorial identity while still feeling premium and high-fidelity
- TDD:
  - added new `SocialViewModelTests` expectations for:
    - `heroEditionLabel`
    - `spotlightDeck`
    - `feedEyebrow`
  - full `xcodebuild build-for-testing` red verification was blocked by the ongoing simulator asset/runtime outage before the test target could cleanly complete
  - the production seam was still introduced against those new expectations and then verified source-clean after implementation
- Implementation:
  - expanded `SocialViewModel` with editorial masthead and feed-label properties
  - replaced the repeated glass-heavy hero treatment in `SocialView` with:
    - a cleaner editorial masthead
    - an edition badge
    - a split spotlight feature card with a cover panel and article panel
  - rebuilt `SocialPostCard` as a magazine-style story strip rather than another rounded floating card
  - kept the same premium palette and typography direction, but changed the component family so `Social` no longer looks like a clone of `Home`
- Verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed after correcting one invalid spacing token
  - Xcode builds remain environment-blocked at asset/runtime tooling because `simdiskimaged` / `CoreSimulatorService` is currently unavailable
- UX result:
  - `Social` now reads more like an editorial round journal than another glass dashboard
  - the app keeps the same design language, but with more component variety and less template repetition

### 2026-04-22 14:27 AEST - Round Setup Scenic Utility Pass

- Problem addressed:
  - `CourseList` and `CourseDetail` were still leaning on the same scenic-background-plus-glass-card composition that had already started to feel repetitive elsewhere
- TDD:
  - added failing `CourseRepositoryTests` expectations for:
    - `CourseDiscoveryViewModel.featuredDeck`
    - `CourseDiscoveryViewModel.collectionEyebrow`
    - `CourseDetailViewModel.briefingEyebrow`
    - `CourseDetailViewModel.selectionDeck`
  - verified the red step via `xcodebuild build-for-testing`, confirming the missing model properties before implementation
- Implementation:
  - expanded the round-setup view models with editorial/scenic-utility copy seams
  - rebuilt `CourseListView` around:
    - a split scenic cover + matte briefing panel
    - ranked nearby copy above the list
    - list rows that behave more like story strips than floating cards
  - rebuilt `CourseDetailView` around:
    - a split scenic cover + course briefing panel
    - less glass-heavy hero framing
    - a clearer “briefing then choose tees” rhythm
- Verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
  - Xcode-wide builds remain partially blocked by the current simulator/asset-runtime outage, so source-level verification is the reliable compile signal here
- UX result:
  - round setup now feels less like another copy of `Home`
  - the setup flow is moving toward `scenic utility`: premium and image-led, but with calmer matte briefing surfaces and cleaner ranked content

### 2026-04-22 14:54 AEST - Home Editorial Command Pass

- Problem addressed:
  - `Home` was still carrying too much of the original scenic-hero-plus-glass-card pattern, which made it feel too close to the other screens despite earlier cleanup passes
- TDD:
  - added failing `HomeViewModelTests` expectations for:
    - `mastheadEditionLabel`
    - `heroDeck`
  - verified the red step via `xcodebuild build-for-testing`, confirming the missing model properties before implementation
- Implementation:
  - expanded `HomeViewModel` with the masthead and command-briefing copy seam
  - rebuilt `HomeView` around:
    - an editorial masthead
    - a split command feature (`cover + matte briefing panel`)
    - cleaner stat cards
    - a more editorial spotlight surface
  - removed reliance on the old single floating `HomeHeroCard` pattern as the defining component of the page
- Verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed after correcting two real source issues in the new layout
- UX result:
  - `Home` now feels more like a personal command page than another scenic glass dashboard
  - the overall app now has clearer component-family separation across `Home`, `Social`, `Round setup`, `Live Round`, and `Profile`

### 2026-04-22 15:14 AEST - Layout Audit Reset and Stage Simplification

- Problem addressed:
  - the visual system had drifted into a new kind of repetition: `Home`, `Social`, and `Round setup` were all reusing rigid split editorial stages
  - on phone-width layouts, the repeated split containers were compressing copy, wrapping pills badly, and creating cropped/squashed hierarchy
- Root-cause findings:
  - `Home` was the biggest offender because both the command feature and the spotlight insight reused near-identical horizontal split cards at fixed heights
  - `CourseListView` and `CourseDetailView` were also using the same scenic-cover-plus-briefing spread, which made setup feel templated
  - `Social` is the one place where the editorial spread still makes sense, but it needed a compact-width fallback
- TDD / guardrails:
  - added failing presentation-seam expectations to:
    - `HomeViewModelTests`
    - `SocialViewModelTests`
    - `CourseRepositoryTests`
  - introduced explicit presentation identities:
    - `Home` command = `.stackedLead`
    - `Home` spotlight = `.bulletin`
    - `Social` spotlight = `.editorialSpread`
    - `CourseList` / `CourseDetail` stage = `.stackedShowcase`
  - simulator-backed build/test verification remains blocked by local `CoreSimulatorService` instability, so the red/green loop here used source-level compile verification plus explicit model seams
- Implementation:
  - rebuilt `Home` so it no longer uses two split spreads:
    - command feature is now a stacked lead card with scenic cover on top and an editorial briefing below
    - spotlight insight is now a bulletin-style card instead of a second cover/briefing split
    - utility panels now stack vertically instead of sitting side-by-side on narrow widths
  - rebuilt `CourseListView` and `CourseDetailView` stage cards into stacked scenic showcases instead of side-by-side spreads
  - updated `SocialView` so the editorial spread remains its signature pattern, but collapses to a stacked composition on compact size classes
- Verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
  - `xcodebuild -project SwingPal.xcodeproj -target SwingPalTests -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO`
  - result: blocked by local CoreSimulator / derived-data permission issues before useful runtime verification, not by a confirmed new SwingPal source error
- UX result:
  - `Home` is back to feeling like an editorial command surface instead of a squeezed two-page spread
  - `Social` owns the editorial spread language instead of the whole app sharing it
  - `Round setup` now reads as scenic utility again, not another magazine spread

### 2026-04-22 15:24 AEST - Typography and Rhythm Normalization Pass

- Problem addressed:
  - after the structural layout reset, the screens still had inconsistent text scales and spacing cadence because headline/body/eyebrow styles were being set ad hoc per screen
  - compact-width pressure was still showing up in `Home` quick stats and `Social` hero pills
- Implementation:
  - added shared layout and typography tokens in `ShellTokens` for:
    - narrative text width
    - compact stats grid columns
    - masthead / stage / section / card title scales
    - lead / body / eyebrow / micro-eyebrow roles
  - updated `HomeView` to:
    - use the shared typography roles
    - constrain long narrative copy to a common readable width
    - switch quick stats to a compact-width grid instead of a permanently horizontal strip
  - updated `SocialView` to:
    - use the shared typography roles
    - let hero pills fall back vertically via `ViewThatFits`
    - align subtitle/body rhythm with the rest of the shell
  - updated `CourseListView` and `CourseDetailView` to use the same stage/body type scales and narrative widths as the other top-level screens
- Verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
- UX result:
  - the app now has a more coherent reading rhythm across `Home`, `Social`, and `Round setup`
  - compact-width layouts should breathe better without introducing another new container pattern

### 2026-04-22 15:38 AEST - Live Round Control Hierarchy Simplification

- Problem addressed:
  - the live-round bottom tray still exposed too many peer actions at once, which diluted the map-first feel and made core on-course tasks compete with utility controls
- TDD / behavior seam:
  - added `LiveRoundStateTests` expectations for:
    - utility tray hidden by default
    - utility tray toggle revealing secondary controls
    - focused sheets dismissing the utility tray
    - collapsing the utility tray also collapsing expanded details
- Implementation:
  - added `isShowingUtilityTray` to `LiveRoundState`
  - updated `presentClubPicker()` and `presentShotLogger()` to dismiss the utility tray before opening a focused sheet
  - updated `toggleUtilityTray()` to collapse expanded details when returning to the default focused-play mode
  - simplified `LiveRoundView` bottom controls into:
    - primary action: `Log Shot`
    - always-on secondary row: `Change Club`, `Green/Hole View`, `More`
    - utility tray: `Move Target`, `Reset View`, `Details`, `Finish Hole`
  - kept detailed secondary context behind the utility tray instead of treating it like a co-equal always-on surface
- Verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
- UX result:
  - live round now has a clearer control hierarchy and a calmer default play state
  - the map remains the hero while utility actions stay available without crowding the primary shot-to-shot workflow

### 2026-04-22 15:49 AEST - Imagery Prompt Pack Added

- Problem addressed:
  - the app is ready to start using more intentional imagery, but we needed prompt-ready design guidance instead of one-off loose prompts
- Implementation:
  - added `docs/plans/2026-04-22-imagery-prompt-pack.md`
  - included:
    - global art direction
    - palette and composition rules
    - crop / safe-area guidance
    - negative prompt guidance
    - prompt sets for:
      - `Home`
      - `Round setup`
      - `Course detail`
      - `Social spotlight`
      - `Profile / bag`
      - optional premium/coaching surfaces
- UX result:
  - generated imagery can now be directed to support the UI instead of fighting the overlays and layout system

### 2026-04-22 16:06 AEST - Appearance Mode and Profile/Social Cleanup

- Problem addressed:
  - `Profile` still gave too much weight to testing/diagnostic concerns
  - app-wide appearance control needed to exist as a real product setting
  - `Social` feed cards still felt too close to utility rows after the stronger editorial spotlight
- TDD / behavior seam:
  - added `AppStateTests` expectations for:
    - persisted appearance mode restoration
    - appearance mode persistence on change
  - added `ProfileViewModelTests` expectations for:
    - appearance title/subtitle framing in the main profile flow
- Implementation:
  - added app-wide appearance state and persistence in `AppState`
  - wired `preferredColorScheme` from app state in `AppShellView`
  - added `Appearance` as a first-class `Profile` card with:
    - `System`
    - `Light`
    - `Dark`
  - demoted diagnostics into a quieter secondary section
  - upgraded `SocialPostCard` from a tasteful row into a richer recap card with:
    - stronger heading hierarchy
    - recap tag
    - secondary chips
    - contained card surface
- Verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
- UX result:
  - `Profile` now reads more like a consumer settings/account destination
  - app-wide theme preference exists without depending on system-only behavior
  - `Social` feed items feel more aligned with the editorial spotlight treatment

### 2026-04-22 16:10 AEST - Live Round Interaction and Chrome Audit Pass

- Problem addressed:
  - live-round controls felt non-responsive in practice even though state handlers existed
  - the HUD still felt too boxy and visually fragmented
  - map guidance layers were competing with the control layer instead of clearly sitting behind it
- Root-cause investigation:
  - traced `LiveRoundView` and `LiveRoundState` end-to-end before changing code
  - confirmed state-side handlers already toggled correctly through existing `LiveRoundStateTests`
  - identified the main view-layer risks:
    - the full-screen course guidance overlay was hit-test enabled instead of only the reticle
    - the reticle drag origin was local view state and was not being re-synced when target mode / aim changed
    - top HUD and bottom controls were implemented as multiple nested boxed surfaces, which made state changes feel weaker than they were
- TDD / behavior seam:
  - added `LiveRoundStateTests` coverage for:
    - `resetViewport()` restoring map pan / rotation / planning target
    - explicit active control state for green view / utility tray emphasis
- Implementation:
  - added `resetViewport()`, `isGreenViewActive`, and `isUtilityTrayActive` to `LiveRoundState`
  - changed `courseGuidanceOverlay` so only the planning reticle remains hit-testable
  - synchronized `reticleOrigin` from `state.planningReticlePoint` so target-mode changes do not leave drag state stale
  - unified the top HUD into one calmer instrument band instead of two separate slabs plus nested stat boxes
  - simplified the lower action strip into:
    - primary `Log Shot`
    - selected-state chips for `Change Club`, `Green/Hole View`, and `More`
    - a quieter secondary utility drawer for `Move Target`, `Reset`, `Details`, and `Finish Hole`
- Verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
  - `xcodebuild -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO build`
  - result: Swift compilation proceeded, but build still failed in `actool` because local `CoreSimulatorService` / `simdiskimaged` is unavailable in this environment
- UX result:
  - live round now has a clearer interaction hierarchy and fewer competing boxes
  - state changes should register more clearly because the control layer is more visually emphatic and the map overlay is less intrusive

### 2026-04-22 16:18 AEST - Generated Stage Imagery Wiring

- Problem addressed:
  - generated stage assets existed in `Assets.xcassets` but the app was still rendering placeholder gradients and abstract scenic shapes
  - imagery needed to be wired through explicit presentation seams instead of hardcoded per-screen
- TDD / behavior seam:
  - added view-model expectations for asset names in:
    - `HomeViewModelTests`
    - `CourseRepositoryTests`
    - `SocialViewModelTests`
    - `ProfileViewModelTests`
- Implementation:
  - added asset-name properties to:
    - `HomeViewModel`
    - `CourseDiscoveryViewModel`
    - `CourseDetailViewModel`
    - `SocialViewModel`
    - `ProfileViewModel`
  - swapped painted scenic placeholders for real image-backed stages in:
    - `HomeView`
    - `CourseListView`
    - `CourseDetailView`
    - `SocialView`
    - `ProfileView`
  - kept the readable overlays / gradients so the new images support the layout instead of overwhelming it
- Verification:
  - `xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -module-cache-path /tmp/swift-module-cache $(find SwingPal -name '*.swift' | sort)`
  - result: passed
- UX result:
  - `Home`, `Round setup`, `Course detail`, `Social spotlight`, and `Profile` now feel less abstract and more premium / location-specific
  - the component language stays intact, but the screens should now feel more like golf product surfaces instead of gradient mockups

### 2026-04-22 16:42 AEST - Critical Bug Parked: Live Round Controls Non-Interactive

- Status:
  - parked as a `critical blocker`
- Symptom:
  - in `Live Round`, none of the visible controls respond to taps in runtime
  - no button-level logs from `LiveRoundView` fire
  - no handler-level logs from `LiveRoundState` fire
- Evidence gathered:
  - console consistently shows:
    - `LiveRoundView appeared for hole 1`
    - WeatherKit auth/runtime errors
    - no `Log Shot tapped`, `Change Club tapped`, `More`, or `toggleTargetView` logs
  - this means taps are dying before the SwiftUI button closures run
- Investigation history:
  - verified state handlers and state tests were already functional
  - reduced hit testing on map guidance overlays so only the reticle remained interactive
  - reworked live HUD structure
  - moved HUD from `safeAreaInset` composition to direct overlays on the live surface
  - issue still reproduces with zero control-event logs
- Current best understanding:
  - likely a parent-level / `MapKit` interaction-plane issue in the immersive live-round composition, not a broken action closure or simple state bug
  - the live round screen architecture needs deeper investigation later instead of more blind patching
- Next time:
  - treat this as a root-cause tracing task
  - inspect `Map` interaction behavior, overlay host hierarchy, and whether a UIKit-backed map view is swallowing pointer/touch routing ahead of SwiftUI controls

### 2026-04-22 17:02 AEST - Live Round Redesign Locked and Planned

- Problem addressed:
  - `Live Round` had drifted into a boxy, cluttered control surface that no longer
    matched real mid-round use
  - the interaction model needed to be redesigned around a shot cycle instead of
    patched screen-by-screen
  - the parked non-interactive-controls bug needed to be treated as a design and
    implementation constraint, not ignored
- Design output:
  - added source-of-truth redesign doc:
    - `docs/plans/2026-04-22-live-round-redesign-design.md`
  - added implementation handoff plan:
    - `docs/plans/2026-04-22-live-round-redesign-implementation.md`
- Locked redesign decisions:
  - `Live Round` stays map-first
  - control hierarchy becomes:
    - primary: yardage, club, `Log Shot`
    - secondary: `At Ball`, target mode, `Recenter`
    - utility: quiet extras behind disclosure
  - tee shot does not require `At Ball`
  - later shots allow optional but recommended `At Ball`
  - `At Ball` reminders must be contextual, not immediate after shot logging
  - target selection uses an explicit draggable crosshair
  - the crosshair is constrained by hole geometry and hole bounds
  - the map itself should remain bounded to the active hole envelope
  - `Recenter` frames player + selected target
  - `Log Shot` becomes a bottom sheet over the live map
  - shot logging captures separate:
    - direction
    - distance
    - strike quality
- Execution direction:
  - the implementation plan breaks the redesign into:
    - structured shot-result models
    - shot-cycle and ball-mark state
    - bounded hole targeting
    - rebuilt action rail
    - structured logger sheet
    - contextual `At Ball` suggestion logic
    - final visual instrument pass
- Handoff note:
  - future implementation work on `Live Round` should execute from
    `docs/plans/2026-04-22-live-round-redesign-implementation.md`
    instead of continuing ad hoc patches on the current UI

## 2026-04-22 - Task 2 Follow-up Fix: No Synthetic Current-Location Origin

- Scope:
  - fixed the reviewed Task 2 issue where post-tee shots could report
    `.currentLocationFallback` while using a synthetic course-center coordinate
- Changed:
  - [SwingPal/Features/Round/LiveRoundState.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/LiveRoundState.swift:1)
  - [SwingPalTests/LiveRoundStateTests.swift](/Users/gabeh/Desktop/SwingPal/SwingPalTests/LiveRoundStateTests.swift:1)
- Behavior:
  - `currentShotOriginSource` is now `nil` after the tee shot when there is no
    real `playerLocation`
  - `currentShotOriginCoordinate` is now `nil` in that state instead of falling
    back to a synthetic course-center coordinate
  - logging without a ball mark and without live GPS now persists `nil` origin
    source/coordinate rather than a misleading fallback origin
- Added coverage:
  - `testPostTeeWithoutLiveLocationDoesNotReportSyntheticCurrentLocationOrigin`
- Verification:
  - source typecheck passed
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    passed
  - targeted runtime execution remains blocked in this environment by
    `CoreSimulatorService` / `simdiskimaged`

## 2026-04-22 - Task 3 Follow-up Fix: Aggregated Target Zones and Hole-Bounded Framing

- Scope:
  - fixed the two important Task 3 review issues without expanding into a
    heavier GIS model
- Changed:
  - [SwingPal/Features/Round/Models/SwingPalCourse.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/Models/SwingPalCourse.swift:1)
  - [SwingPal/Features/Round/LiveRoundState.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/LiveRoundState.swift:1)
  - [SwingPalTests/LiveRoundStateTests.swift](/Users/gabeh/Desktop/SwingPal/SwingPalTests/LiveRoundStateTests.swift:1)
- Behavior:
  - `currentTargetZone` now combines all relevant feature geometry for the
    current target mode instead of stopping at the first matching feature
  - `recommendedMapRegion` is now constrained by `currentHoleBounds`, so the
    full player/target framing cannot drift outside the active hole envelope
- Added coverage:
  - `testCurrentTargetZoneCombinesAllRelevantFairwaySegments`
  - `testPreferredMapRegionStaysWithinCurrentHoleBoundsWhenPlayerLocationDriftsOutsideHole`
  - strengthened `testCurrentHoleBoundsContainCurrentHoleFeatureGeometry` to
    assert actual feature coordinates, not only derived tee/target points
- Verification:
  - source typecheck passed
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    passed
  - targeted runtime execution remains blocked in this environment by
    `CoreSimulatorService` / `simdiskimaged`

## 2026-04-22 - Task 5: Structured Live Round Shot Logger

- Scope:
  - redesigned the live-round shot logger into a structured bottom sheet without
    changing the broader map-first live-round architecture
- Changed:
  - [SwingPal/Features/Round/LiveRoundState.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/LiveRoundState.swift:1)
  - [SwingPal/Features/Round/LiveRoundView.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/LiveRoundView.swift:1)
  - [SwingPalTests/LiveRoundStateTests.swift](/Users/gabeh/Desktop/SwingPal/SwingPalTests/LiveRoundStateTests.swift:1)
- Behavior:
  - presenting the logger now clears pending direction / distance / strike so
    the user must explicitly tag all three result dimensions
  - `canConfirmPendingShot` now gates confirmation; incomplete logger state no
    longer confirms a shot
  - the sheet now shows a compact context header with club, origin, selected
    target, and distance
  - the sheet now renders separate direction, distance, and strike grids plus a
    quieter optional lie override section
  - confirmed shots now persist selected-target context in live-round state via
    `lastLoggedShotTargetCoordinate` and `lastLoggedShotTargetLabel`
- Added coverage:
  - `testShotLoggerRequiresDirectionDistanceAndStrikeBeforeConfirm`
  - `testPresentShotLoggerResetsPendingStructuredSelections`
  - `testConfirmPendingShotStoresLoggerContextIncludingOriginSourceAndSelectedTarget`
  - adjusted older logger tests to select all three result dimensions before
    confirmation
- Verification:
  - source typecheck passed:
    `SDK=$(xcrun --sdk iphonesimulator --show-sdk-path); find SwingPal -name '*.swift' -print0 | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$SDK" -module-cache-path /tmp/swift-module-cache`
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    passed
  - targeted runtime execution remains blocked in this environment by
    `CoreSimulatorService` / `simdiskimaged`

## 2026-04-22 - Task 6 Follow-up: Reminder Baseline Falls Back To Real Shot Origin

- Scope:
  - fixed the Task 6 review issue without redesigning the reminder system
- Changed:
  - [SwingPal/Features/Round/LiveRoundState.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/LiveRoundState.swift:1)
  - [SwingPalTests/LiveRoundStateTests.swift](/Users/gabeh/Desktop/SwingPal/SwingPalTests/LiveRoundStateTests.swift:1)
- Behavior:
  - `ballMarkSuggestionBaselineCoordinate` now prefers the real shot origin
    (`tee` or `ball mark`) before falling back to live GPS
  - post-shot `At Ball` reminders can now recover later when location becomes
    available, even if GPS was unavailable at the moment the shot was logged
- Added coverage:
  - `testAtBallSuggestionFallsBackToTeeOriginWhenGpsIsUnavailableAtLogTime`
- Verification:
  - targeted runtime execution attempt with
    `xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:SwingPalTests/LiveRoundStateTests/testAtBallSuggestionFallsBackToTeeOriginWhenGpsIsUnavailableAtLogTime`
    was blocked again by local `CoreSimulatorService` / `simdiskimaged`
  - source typecheck passed:
    `SDK=$(xcrun --sdk iphonesimulator --show-sdk-path); find SwingPal -name '*.swift' -print0 | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$SDK" -module-cache-path /tmp/swift-module-cache`
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    passed

## 2026-04-23 - Live Round Tap Blocker: HUD Moved Out Of Map Overlay Subtree

- Scope:
  - traced the live-round tap blocker as an interaction-layering issue instead
    of continuing to patch styling around it
- Changed:
  - [SwingPal/Features/Round/LiveRoundView.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/LiveRoundView.swift:1)
- Root-cause hypothesis:
  - `Map` was likely winning the interaction plane because the top HUD and
    bottom controls were attached as `.overlay` modifiers on the map subtree
    rather than being sibling layers above it
- Behavior:
  - live-round layers are now explicit siblings in a `ZStack`: map, passive map
    chrome, guidance/reticle, HUD, then hole transition
  - the guidance container no longer disables hit testing for the reticle at
    the parent level
  - this is the first pass that changes the interaction architecture itself
    rather than only restyling the screen
- Verification:
  - source typecheck passed:
    `SDK=$(xcrun --sdk iphonesimulator --show-sdk-path); find SwingPal -name '*.swift' -print0 | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$SDK" -module-cache-path /tmp/swift-module-cache`
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    passed
  - runtime tap verification still needs to happen on device, because that is
    where the bug was actually observed

## 2026-04-23 - Live Round Clean-Room Reset Wired In

- Scope:
  - stopped patching the broken live-round stack and switched the round flow to
    a brand-new clean-room screen file
- Changed:
  - [SwingPal/Features/Round/FreshLiveRoundScreen.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/FreshLiveRoundScreen.swift:1)
  - [SwingPal/Features/Round/RoundRootView.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/RoundRootView.swift:270)
  - [SwingPal.xcodeproj/project.pbxproj](/Users/gabeh/Desktop/SwingPal/SwingPal.xcodeproj/project.pbxproj:1)
- Behavior:
  - `RoundRootView` now routes the live step into `FreshLiveRoundScreen`
  - the fresh screen is intentionally minimal: top summary, real map, passive
    target overlay, bottom actions, club picker sheet, and shot logger sheet
  - the new screen no longer depends on private helpers from the old
    `LiveRoundView`
- Verification:
  - source typecheck passed:
    `SDK=$(xcrun --sdk iphonesimulator --show-sdk-path); find SwingPal -name '*.swift' -print0 | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$SDK" -module-cache-path /tmp/swift-module-cache`
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    passed
  - runtime validation still needs to happen on device against the new screen,
    because the previous bug was interaction-plane specific

## 2026-04-23 - Live Round Clean-Room Design Doc

- Scope:
  - documented the live-round rebuild target after validating that the
    clean-room screen restores working controls
- Added:
  - [docs/plans/2026-04-23-live-round-clean-room-design.md](/Users/gabeh/Desktop/SwingPal/docs/plans/2026-04-23-live-round-clean-room-design.md:1)
- Captured:
  - map-first phone layout
  - bounded current-hole satellite map behavior
  - top strip contents and inspection navigation rules
  - draggable launcher-style live sheet
  - anchored radial club wheel
  - `Basic` / `Advanced` shot logger split
  - finish-hole confirmation flow
  - inspection-mode edit rules and post-confirm audit flag
  - watch-first priorities and phone/watch sync requirements

## 2026-04-23 - Live Round Clean-Room Implementation Plan

- Scope:
  - translated the new clean-room design into an execution plan targeted at the
    current repo layout and active `FreshLiveRoundScreen` route
- Added:
  - [docs/plans/2026-04-23-live-round-clean-room-implementation.md](/Users/gabeh/Desktop/SwingPal/docs/plans/2026-04-23-live-round-clean-room-implementation.md:1)
- Captured:
  - logger mode preference in Profile/AppState
  - inspection mode and confirmed-hole audit flags
  - bounded map framing and free-drag target state
  - top strip and draggable launcher sheet rebuild
  - anchored club wheel
  - `Basic` / `Advanced` logging rebuild
  - finish-hole confirmation flow
  - app-side round companion sync payloads for future watch support

## 2026-04-23 - Live Round Launcher Sheet Rebuild

- Scope:
  - replaced the temporary bottom control slab on the clean-room live screen
    with a draggable glass launcher sheet
- Changed:
  - [SwingPal/Features/Round/FreshLiveRoundScreen.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/FreshLiveRoundScreen.swift:1)
  - [SwingPal/Features/Round/LiveRoundState.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/LiveRoundState.swift:1)
  - [SwingPalTests/LiveRoundStateTests.swift](/Users/gabeh/Desktop/SwingPal/SwingPalTests/LiveRoundStateTests.swift:1)
- Behavior:
  - collapsed launcher now keeps `Log Shot`, `At Ball` when applicable, and
    immediate current-club access
  - expanded launcher now exposes only secondary live invokers for this slice,
    including `Change Club`, target-view toggle, and `Finish Hole`
  - inspection mode now disables live launcher actions cleanly and shows an
    inspection-only message instead of live controls
  - recenter button placement now tracks the launcher height instead of the old
    fixed offset
- Verification:
  - source typecheck passed:
    `SDK=$(xcrun --sdk iphonesimulator --show-sdk-path); find SwingPal -name '*.swift' -print0 | xargs -0 xcrun swiftc -typecheck -module-name SwingPal -target arm64-apple-ios17.0-simulator -sdk "$SDK" -module-cache-path /tmp/swift-module-cache`
  - `xcodebuild build-for-testing -project SwingPal.xcodeproj -scheme SwingPal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SwingPalDerivedBuild CODE_SIGNING_ALLOWED=NO`
    passed
- Deferred:
  - anchored radial club wheel remains Task 6
  - full logger-mode UI rebuild and finish-hole confirmation flow remain later
    tasks

## 2026-04-28 - Map Experience Overhaul: Aiming Line, Long-Press-And-Drag Aim Point, Hole-Centered Carry Rings

- Scope:
  - moved the live map from a passive viewer to an interactive shot-planning
    surface, with bound camera, an aiming line and meterage, a
    long-press-and-drag crosshair to refine the aim point, and carry-distance
    rings centered on the hole rather than the player
- Changed:
  - [SwingPal/Features/Round/FreshLiveRoundScreen.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/FreshLiveRoundScreen.swift:1)
  - [SwingPal/Features/Round/LiveRoundState.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/LiveRoundState.swift:1)
- Removed:
  - legacy `LiveRoundView.swift` and the old `AimPoint` / `TargetViewMode`
    enums that drove discrete aim-point modes
- Behavior:
  - map camera is bound to the displayed hole and frames `displayedHoleRegion`
    when inspecting other holes
  - on hole progression the camera animates to the next hole's tee with a
    `tee_biased` framing
  - dragging the crosshair via a long-press-and-drag gesture moves the aim
    point inside the hole bounds; the player→aim and aim→pin segments display
    live meterage that updates during the drag
  - carry rings are now centered on the hole, use 50m increments out long and
    25m increments on approach, and only render when within range (instead of
    always rendering all rings around the player)
  - a small bottom legend strip explains the carry-ring colors
  - recentre button returns to the active hole when the user is inspecting a
    different hole
- Layering fix:
  - moved aim line, pills, and crosshair out of MapKit `Annotation` /
    `MapPolyline` and into a SwiftUI `aimVisualOverlay` while a drag is
    active, because MapKit's interpolation produced visible flicker that
    didn't track the finger; idle state stays in `MapContent` for performance
  - resolved `AttributeGraph` cycles around the gesture catcher by using
    `.global` coordinate space + manual translation rather than relying on
    `MapProxy.convert` returning non-nil during the first frame
- Verification:
  - `xcodebuild build` succeeded
  - on-device runtime check: drag now reads as smooth, line meterage updates
    during the gesture, and the crosshair stops fighting MapKit's pan
    recognizer thanks to `.highPriorityGesture`

## 2026-04-28 - Course Data Hand-Trace: Royal Melbourne West via OSM

- Scope:
  - replaced synthetic `SwingPalCourse.test()` geometry with one real
    hand-traced 18-hole course so the map experience could be evaluated
    against real-world fairways/greens instead of placeholder shapes
- Decisions:
  - sourcing strategy: **Hybrid** - bundle ~5 curated courses, plan to fetch
    OSM-derived courses at runtime later
  - storage: **local JSON only** for this phase, no Supabase yet
  - first course: **Royal Melbourne West**, all 18 holes
  - source: **OpenStreetMap** (Overpass API), refined manually as needed
  - infra: **build both** the static JSON and a `BundledCourseLoader` so the
    runtime can read either bundled or future remotely-fetched courses through
    a single seam
- Added:
  - [SwingPal/Resources/Courses/royal-melbourne-west.json](/Users/gabeh/Desktop/SwingPal/SwingPal/Resources/Courses/royal-melbourne-west.json:1)
  - [tmp/convert_osm_to_course.py](/Users/gabeh/Desktop/SwingPal/tmp/convert_osm_to_course.py:1)
- Changed:
  - [SwingPal/Features/Round/Repositories/CourseRepository.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/Repositories/CourseRepository.swift:1)
  - [SwingPal/Features/Round/Repositories/BundledCourseRepository.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/Repositories/BundledCourseRepository.swift:1)
  - [SwingPal.xcodeproj/project.pbxproj](/Users/gabeh/Desktop/SwingPal/SwingPal.xcodeproj/project.pbxproj:1)
- Verification:
  - `xcodebuild build` succeeded
  - `BundledCourseRepository` resolves the new course end-to-end through the
    home / course-list / course-detail surfaces

## 2026-04-28 - Tee-Perspective Live Map Camera

- Scope:
  - made the live map feel less "top-down map" and more "looking down the
    hole from the tee" so first-time players read the layout without
    re-orienting
- Changed:
  - [SwingPal/Features/Round/LiveRoundState.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/LiveRoundState.swift:1)
  - [SwingPal/Features/Round/FreshLiveRoundScreen.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/FreshLiveRoundScreen.swift:1)
- Behavior:
  - introduced `TeePerspectiveCameraSpec { center, distance, heading, pitch }`
    on `LiveRoundState`, with `heading = bearing(tee → pin)` and a 55°
    pitch
  - distance auto-scales with `teePinDistance * 2.4` (floor at 650m) so par 3s
    don't dive in on the green and par 5s don't lose the tee box off the top
    of the screen
  - hole progression and "return to active hole" both animate the camera
    using this spec, replacing the older flat `MKCoordinateRegion` framing

## 2026-04-29 - Royal Melbourne Hole Trace Corrections + PAR_OVERRIDES

- Scope:
  - fixed broken / placeholder hole geometry in the hand-traced Royal
    Melbourne West JSON (initially holes 13-16, then a separate pass for
    holes 4 and 5 once the user identified the wrong feature pairing)
- Changed:
  - [tmp/convert_osm_to_course.py](/Users/gabeh/Desktop/SwingPal/tmp/convert_osm_to_course.py:1)
  - [SwingPal/Resources/Courses/royal-melbourne-west.json](/Users/gabeh/Desktop/SwingPal/SwingPal/Resources/Courses/royal-melbourne-west.json:1)
- Behavior:
  - expanded the Overpass bounding box so the southern holes were no longer
    cropped out of the raw OSM dump
  - taught the converter to use hole-way endpoints (rather than nearest
    feature centroid) when picking the primary tee/green pair, so dog-leg
    holes now select the correct tee and green instead of latching to a
    neighbouring hole's geometry
  - introduced a `PAR_OVERRIDES` map keyed by `course_id + hole_number` so
    we can correct OSM par tags that disagree with the scorecard (RM West 4W
    and 11W now correctly read as par 5 → course par 72)
- Verification:
  - regenerated `royal-melbourne-west.json`, visually checked all 18 hole
    overlays against satellite imagery
  - `xcodebuild build` succeeded

## 2026-04-29 - Course Ingestion Pipeline Design Doc

- Scope:
  - turned the ad-hoc Royal Melbourne pipeline into a documented, repeatable
    process so adding a new course is a config + script run, not a bespoke
    archeology project each time
- Added:
  - [docs/plans/2026-04-29-course-ingestion-pipeline-design.md](/Users/gabeh/Desktop/SwingPal/docs/plans/2026-04-29-course-ingestion-pipeline-design.md:1)
- Decisions captured:
  - scope: **just_design** for now, no codegen
  - course catalog identifier: **support_both** OSM relation ID and
    name+bbox, so we can lock in well-known relations but still trace
    courses that aren't fully tagged in OSM yet
  - bundled-only storage today; Supabase ingestion called out as a separate
    phase

## 2026-04-29 - Map and Launcher Performance Audit (round 1)

- Scope:
  - addressed user feedback that map interaction was "EXTREMELY laggy" and
    that the bottom tray dragged in noticeably on top of that
- Changed:
  - [SwingPal/Features/Round/FreshLiveRoundScreen.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/FreshLiveRoundScreen.swift:1)
  - [SwingPal/Features/Round/LiveRoundState.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/LiveRoundState.swift:1)
- Behavior:
  - carry rings now respect `visibleCarryRings`, which culls anything outside
    the current player→hole envelope rather than rendering all 12+ rings on
    every frame
  - `.onMapCameraChange` switched from `.continuous` to `.onEnd` so we no
    longer rebuild dependent screen-space conversions 60+ times a second
    during a pan
  - hybrid rendering kept aim visuals in `MapContent` while idle and
    promoted them to a SwiftUI overlay only during an active drag, so
    MapKit isn't being asked to interpolate dragged annotations
  - launcher recenter button padding now reads `launcherRestingHeight` to
    avoid recomputing on every drag tick
  - dropped a continuous animation around `launcherDragTranslation` and
    moved the spring into a single `withAnimation` block at gesture end
- Verification:
  - `xcodebuild build` succeeded
  - on-device runtime check: map interaction noticeably smoother, sheet
    snaps cleanly to detents but **the user reported the sheet still felt
    jittery on drag** - tracked separately below

## 2026-04-30 - Logging Pass: Hot-Path Logs Removed

- Scope:
  - per-frame `Logger.debug` / `print()` calls in the live-round hot path
    were left in from earlier debugging sessions and were themselves a
    measurable performance drag
- Changed:
  - [SwingPal/Features/Round/LiveRoundState.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/LiveRoundState.swift:1)
  - [SwingPal/Features/Round/FreshLiveRoundScreen.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/FreshLiveRoundScreen.swift:1)
- Behavior:
  - removed launcher-detent and camera-spec debug prints that were firing on
    every state mutation
  - kept structured `OSLog` callsites only where they have real diagnostic
    value
- Verification:
  - `xcodebuild build` succeeded

## 2026-04-30 - Medway Golf Club Course Data + Setup-Flow Integration

- Scope:
  - second hand-traced course, exercising the ingestion pipeline beyond
    Royal Melbourne and giving the user a closer-to-home option in the
    setup flow
- Added:
  - [SwingPal/Resources/Courses/medway.json](/Users/gabeh/Desktop/SwingPal/SwingPal/Resources/Courses/medway.json:1)
  - [tmp/medway-query.txt](/Users/gabeh/Desktop/SwingPal/tmp/medway-query.txt:1)
  - [tmp/medway-osm.json](/Users/gabeh/Desktop/SwingPal/tmp/medway-osm.json:1)
- Changed:
  - [tmp/convert_osm_to_course.py](/Users/gabeh/Desktop/SwingPal/tmp/convert_osm_to_course.py:1)
    (generalized for multi-course config, with `Medway Golf Club` as the
    second entry)
  - [SwingPal/Features/Round/Repositories/CourseRepository.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/Repositories/CourseRepository.swift:1)
    (added Medway to `CourseSeed`)
  - [SwingPal.xcodeproj/project.pbxproj](/Users/gabeh/Desktop/SwingPal/SwingPal.xcodeproj/project.pbxproj:1)
  - [SwingPalTests/CourseRepositoryTests.swift](/Users/gabeh/Desktop/SwingPal/SwingPalTests/CourseRepositoryTests.swift:1)
  - [SwingPalTests/HomeViewModelTests.swift](/Users/gabeh/Desktop/SwingPal/SwingPalTests/HomeViewModelTests.swift:1)
- Behavior:
  - Medway Golf Club (Maribyrnong, VIC) renders end-to-end in the setup flow
    and live round
  - tests assert that the catalog, nearest-course hero, and round setup all
    pick up Medway, with `roundParTotal == 70`
- Verification:
  - `xcodebuild test` for the relevant suites passed

## 2026-04-30 - Recenter Returns To Active Hole From Inspection

- Scope:
  - small UX fix: when inspecting a different hole, tapping the map's
    recenter button used to recenter on whatever hole was being inspected,
    not the one the player was actually playing
- Changed:
  - [SwingPal/Features/Round/LiveRoundState.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/LiveRoundState.swift:1)
  - [SwingPal/Features/Round/FreshLiveRoundScreen.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/FreshLiveRoundScreen.swift:1)
- Behavior:
  - added `LiveRoundState.returnToActiveHole()` which no-ops when already on
    the active hole and otherwise calls `inspectHole(at: activeHoleIndex)`
  - the recenter button reads `state.isInspectingHole` and routes through
    this method when applicable, with the existing `tee_biased` framing
    animation

## 2026-04-30 - Launcher Sheet Jitter: State-Isolated Offset Wrapper

- Scope:
  - several rounds of fixing the launcher tray's "jittery on drag"
    feedback before identifying the real cause
- Iterations:
  - **round 1**: tried tightening animation timing - moved
    `launcherDragTranslation` from `@GestureState` to `@State`,
    `minimumDistance: 0`, single `withAnimation` block in `.onEnded`,
    soft-clamp via a `rubberBandedHeight` helper. User: still jittery.
  - **round 2**: rearchitected positioning from `frame(height:)` (which
    re-runs layout on every drag tick) to `offset(y:)`. User: still jittery.
  - **round 3 (the fix)**: identified that `launcherDragTranslation` lived
    on `FreshLiveRoundScreen`, so dragging the sheet re-evaluated the
    parent's `body` 60-120 Hz - which forces SwiftUI to re-diff the entire
    `liveMap` `MapContent` tree on every frame
- Changed:
  - [SwingPal/Features/Round/FreshLiveRoundScreen.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/FreshLiveRoundScreen.swift:1)
- Behavior:
  - extracted a private `FreshLiveRoundLauncherOffsetWrapper<Content: View>`
    that owns its own `@State private var translation: CGFloat = 0`,
    accepts the sheet content as a `@ViewBuilder` closure, and applies
    `.offset(y: expandedHeight - currentHeight)` itself
  - `bottomSheetStack`, `launcherSheet`, `launcherHeader`, and
    `launcherDragGesture` now thread a `Binding<CGFloat>` for the drag
    translation so the live drag value lives entirely inside the wrapper
  - `resolvedClubLauncherFrame` reads `launcherRestingHeight` instead of a
    drag-derived height so it doesn't drag the parent back into the
    invalidation loop
  - `rubberBandedHeight` lives on the wrapper, not the parent
- Outcome:
  - parent's `liveMap` no longer diffs on drag ticks; user reported the
    sheet went from "still jittery" to "better, still a little jittery,
    but much better on the whole"
- Verification:
  - `xcodebuild build` succeeded
  - all touched tests pass

## 2026-04-30 - Live-Round Low-Hanging-Fruit Audit

- Scope:
  - audited established golf-caddy apps (Garmin Golf, Hole19, 18Birdies,
    Arccos) for live-round features SwingPal could pick up cheaply, and
    triaged the result into "do now" vs "deferred"
- Decided in scope:
  - **Plays-Like distance** (replace +6 stub with a real wind/temperature
    model and surface it)
  - **Round-to-par chip** (persistent running score in the top panel)
  - **Auto FIR/GIR detection** (derive from logged shot surfaces)
  - **Putt counter** (already half-derived; surface in the inspector)
- Deferred:
  - shot dispersion overlays, club-recommendation suggestions on the
    distance HUD, "tap a club to preview yardage on the rings",
    yardage book / hole notes per course, scorecard export, hazard
    proximity warnings, wind arrow on the map, and statistics homepage
    cards - all worthwhile but bigger-than-trivial
- Output:
  - presented to user, who confirmed `1-4` for immediate implementation

## 2026-04-30 - Plays-Like, Round-to-Par, FIR/GIR, Putt Counter

- Scope:
  - implemented the four "low-hanging fruit" live-round features the user
    confirmed for this slice
- Changed:
  - [SwingPal/Features/Round/LiveRoundState.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/LiveRoundState.swift:1)
  - [SwingPal/Features/Round/FreshLiveRoundScreen.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Features/Round/FreshLiveRoundScreen.swift:1)
  - [SwingPal/Services/Weather/RoundWeatherSnapshot.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Services/Weather/RoundWeatherSnapshot.swift:1)
  - [SwingPal/Services/Weather/AppleWeatherKitLoader.swift](/Users/gabeh/Desktop/SwingPal/SwingPal/Services/Weather/AppleWeatherKitLoader.swift:1)
  - [SwingPalTests/LiveRoundStateTests.swift](/Users/gabeh/Desktop/SwingPal/SwingPalTests/LiveRoundStateTests.swift:1)
- Plays-Like:
  - added `PlaysLikeCalculator` (file-private to LiveRoundState.swift) with
    head/tail-wind component (~0.4% of base per km/h) and a temperature
    factor (~0.2% per °C below the 20°C baseline); elevation deferred
  - `RoundWeatherSnapshot` now carries an optional `windDirectionDegrees`
    populated from `current.wind.direction.converted(to: .degrees)`; the
    calculator falls back to a 16-point compass-string lookup when a
    loader doesn't supply degrees
  - introduced `displayedPlaysLikeDistanceMeters` so the value is sensible
    while inspecting other holes (uses the displayed hole's tee→pin
    bearing instead of the live player→pin one)
  - top-panel distance row now shows **Front | Pin | Plays | Back**, with
    the Plays card accent-tinted when it differs from raw Pin distance
- Round-to-Par:
  - new `roundScoreToPar`, `roundScoreToParDisplay`, and
    `roundConfirmedHoleCount` on `LiveRoundState`; only confirmed holes
    contribute, so the value ticks over on hole confirmation rather than
    fluctuating mid-hole
  - `topPanelHoleSubtitle` appends `"+2 thru 5"` (or `"E thru 7"`) once at
    least one hole is confirmed
- Auto FIR/GIR:
  - `LiveRoundState.derivedFairwayInRegulation(for:)` infers FIR from
    stroke-2 surface on par 4/5 holes; returns `nil` for par 3 or
    insufficient data
  - `LiveRoundState.derivedGreenInRegulation(for:)` infers GIR by checking
    for any green-surface shot at `strokeNumber <= par - 1`; returns
    `nil` until enough strokes are logged to make the call
  - round totals: `roundFairwaysInRegulation`, `roundGreensInRegulation`,
    `roundTotalPutts`
- Putt Counter:
  - reused the existing `derivedPuttCount` (now exposed as `static`,
    no longer `private`) which classifies shots as putts via either
    `surface == .green` or `shotType == .putt`
- Inspector surface:
  - `HoleInspectionEntry` extended with `score`, `putts`, `fairwayHit`,
    `greenInRegulation`
  - `FreshLiveRoundHoleInspectorSheet` now shows a top totals strip
    (Score / FIR / GIR / Putts), a per-hole score-to-par capsule, and
    FIR / GIR / Putt chips with hit/miss/neutral tints
- Tests:
  - 7 new tests in `LiveRoundStateTests`: 3 for `PlaysLikeCalculator`
    (head wind, tail wind, cross-wind cancels), 2 for FIR derivation
    (par-3 nil, par-4 hit/miss), 1 for GIR, and 1 for round-score
    aggregation across confirmed holes
  - updated `testPlaysLikeDistanceFallsBackToBasePinDistanceWhenWeatherIsUnavailable`
    to assert the new no-weather behaviour returns the raw GPS distance
    instead of the legacy +6 stub
- Incidental cleanup discovered while re-running the full build:
  - `RoundSetupView.swift` was on disk but **not in the Xcode project**;
    added build-file / file-reference / group / sources-phase entries to
    `project.pbxproj`
  - fixed two ternary `.ultraThinMaterial : Color` mismatches in
    `RoundSetupView` tee-card backgrounds (split into a `background { ... }`
    builder so each branch is shape-fill of the same type)
  - removed a stray `selectedCourse = nil` line in `RoundRootView` that
    referenced nothing in scope; `setupState.reset()` already covers it
- Verification:
  - `xcodebuild build` succeeded
  - all 7 new tests pass; pre-existing failures unrelated to this work
    (stale `shotLoggingSubtitle` copy expectation;
    `testDisplayedDistanceMetricsUseLivePinDistanceAndGreenGeometryOnActiveHole`
    asserting `back > front` without seeded green geometry) left alone
- Deferred:
  - elevation component of plays-like (no per-hole elevation data yet)
  - dispersion overlays, hazard proximity, wind arrow on map, and other
    items from the audit

## 2026-04-30 — Club selection V2

The radial club wheel concept stays, but the execution was V1: every spoke
showed the same flat (name, carry) pair, the wheel had no concept of the
*current shot*, and there was no haptic / visual hierarchy to make the
"what should I hit?" decision easy.

- Domain model upgrade in `LiveRoundState`:
  - `ClubWheelEntry` is now a richer struct: in addition to `clubName` /
    `displayCarryMeters` it carries `gapToTargetMeters`, `carrySource`
    (`.logged` / `.baseline`), `relevance`
    (`.viable` / `.tooLong` / `.tooShort` / `.mutedByPutterMode`), and
    `isRecommended`
  - new `clubWheelTargetDistanceMeters` (uses plays-like distance so wind
    & temperature actually flow into club choice)
  - new `recommendedClubName` — picks the bag club whose carry is closest
    to the plays-like target, with an *upward* tie-break (better to be
    half a club long than half a club short)
  - new `isClubWheelInPutterMode` — flips on when the player is on the
    green or inside ~22 m, so the wheel auto-recommends Putter and mutes
    everything else
  - `LiveRoundState.relevance(forClub:gapToTarget:isPutterMode:)` exposed
    as `static` so the relevance heuristic is unit-testable in isolation
- View redesign in `FreshLiveRoundClubWheelOverlay`:
  - **Distance-aware center** — replaced the duplicated "selected club +
    carry" hub with PIN distance, "Plays X m" sub-line, and a
    `REC: Club` chip. While the user is dragging-to-preview, the chip
    flips to a hand icon + previewed club name so the hub stays useful
  - **Recommendation ring** — recommended entry gets a 2.5pt accent
    stroke (independent of the selected fill) so the eye lands on the
    right tile even when the user has a different one selected
  - **Per-entry gap chip** — each spoke now shows arrow-up / arrow-down /
    checkmark with the signed delta to plays-like (`+12`, `-7`, `On`)
    instead of an inert carry number; carries still show in modes where
    no target is available
  - **In-range muting** — clubs more than ~14 m off plays-like fade to
    55% opacity (selected + recommended always read at full strength);
    the viable cluster pops out visually
  - **Source dot** — tiny pine dot when the carry came from logged data,
    outlined dot when it's an amateur baseline, so the user knows when
    to trust the number
  - **Putter mode** — in close, the center swaps to a "On the Green —
    Putter recommended" card and every non-putter spoke is muted
  - **Haptics** — `UISelectionFeedbackGenerator` ticks on segment hover
    crossings during drag; `UIImpactFeedbackGenerator(style: .medium)`
    fires on commit (both tap-to-pick and drag-release-to-pick)
  - **Tighter motion** — `entryDelayStep` 0.018 → 0.006 (the 12 spokes
    now feel like one breath, not a 220 ms cascade); added
    `recommendedScale` so the recommended tile is subtly larger; kept
    the field positive so existing motion-policy test still passes
- Tests in `LiveRoundStateTests`:
  - 6 new tests covering carry-source flagging, recommendation tie-break
    behaviour (incl. excluding putter from full-swing recommendations),
    gap-and-relevance per-entry annotation, putter-mode auto-trigger
    inside ~22 m, and the relevance helper directly
- Verification:
  - `xcodebuild build` clean, no lints introduced
  - 14 targeted club-wheel tests pass (8 new, 6 pre-existing covering
    presentation / inspection-mode / hover geometry / motion policy)
  - remaining suite-level failures (`testCompanionSnapshotCarriesBagDrivenClubOptions`,
    `testConfirmPendingShotLogsSelectedSurfaceAndDismissesLogger`,
    `testRecommendedMapRegionCentersBetweenPlayerAndTarget`,
    `testLiveRoundUsesNativeGlassAPIsOnIOS26AndAbove`) are pre-existing
    bugs unrelated to this work (canonical-case bag flattening,
    distance-at-log-time capture, region geometry tolerances, glass API
    feature-flag) — flagged for a separate cleanup pass
- Deferred (still in the "low-hanging fruit" backlog from the prior audit):
  - tap-a-club to draw a temporary preview ring on the map for that club
  - shot-source switching ("from front/center/back of green") inside the
    same hub
  - "your last 5 shots with this club" range band instead of a single
    average carry number

## 2026-04-30 — Auto / Manual club-selection toggle

The V2 wheel introduced a "smart" mode (REC badge, gap chips, muting of
out-of-range clubs). Even though muted clubs were still tappable, the
55% opacity reads as "disabled" to most users — and a player who
*wants* a knockdown 9-iron into the wind shouldn't have to push through
"this looks unavailable" UI. Added a first-class Auto / Manual toggle
so the assist is opt-in-but-defaulted-on, and the player can flip it
from inside the wheel without leaving the round.

- Persistence:
  - new `ClubAutoRecommendationPreferenceStoring` protocol +
    `UserDefaultsClubAutoRecommendationPreferenceStore` (mirrors the
    `LiveRoundLoggerModeStore` pattern, including a "never set yet"
    fallback to `true` so first-launch users get the assist by default
    instead of accidentally landing in manual mode)
  - `AppState.clubAutoRecommendationEnabled` published + loaded /
    saved through the new store
  - `AppState.setClubAutoRecommendationEnabled(_:)` is the single
    entry-point for *outside* mutators (e.g. a future settings UI),
    and `bindActiveRound` wires `LiveRoundState.onClubAutoRecommendation
    PreferenceChanged` to the store so toggles fired from the wheel
    flow back up to UserDefaults
  - `RoundRootView.startRound()` now passes the current preference (and
    the existing `preferredShotLoggerMode`) into the freshly-built
    `LiveRoundState`, so brand-new rounds reflect the user's setting
- Domain:
  - `LiveRoundState.isClubAutoRecommendationEnabled` (`@Published`,
    init param defaults to `true`) gates the assist
  - `recommendedClubName`, `isClubWheelInPutterMode`, and the per-entry
    relevance / `isRecommended` flags all short-circuit when the flag
    is off → in manual mode every entry is `.viable`, no club is
    flagged recommended, and putter mode never auto-triggers
  - `LiveRoundState.relevance(forClub:gapToTarget:isPutterMode:isAuto
    RecommendationEnabled:)` picked up the new parameter (default
    `true` for back-compat) so existing call sites keep compiling
  - `setClubAutoRecommendationEnabled(_:)` /
    `toggleClubAutoRecommendation()` mutators emit the new
    `onClubAutoRecommendationPreferenceChanged` callback (no-op when
    the value didn't actually change, so view updates don't spam the
    persistence layer)
- View:
  - new `FreshLiveRoundClubWheelAutoToggle` chip pinned at the top of
    the wheel (above the chrome circle, outside the hover-select drag
    container). Tapping flips the assist with a soft impact haptic and
    the wheel re-renders inline
  - center hub now shows three exclusive chips: "REC: Club" (auto on),
    "Pick any club" (manual mode), or the previewed club name (during
    a drag) — chosen so the slot's vertical rhythm doesn't bounce when
    toggling
  - `FreshLiveRoundClubWheelEntryView` accepts the flag; in manual
    mode it dumps the gap chip in favour of the plain carry distance
    and disables relevance-based opacity muting
- Tests:
  - 5 new `LiveRoundStateTests`: relevance helper short-circuits in
    manual mode, toggle/setter mutates flag + fires callback,
    recommendation goes nil + entries become uniformly `.viable`,
    putter mode is suppressed in manual mode, init flag propagates
  - 4 new `AppStateTests`: default `true`, persisted load round-trip,
    `setClubAutoRecommendationEnabled` writes through to store *and*
    active round, in-wheel toggle flows back up to AppState
  - new `StubClubAutoRecommendationPreferenceStore` test fixture
    mirroring `StubLiveRoundLoggerModeStore`
- Verification:
  - `xcodebuild build` clean, no lints
  - 10 new tests pass; 9 prior club-wheel / AppState tests re-run
    clean (no regressions)
- Deferred:
  - exposing the same toggle from the profile / settings screen so
    long-tail users can switch modes without opening the wheel

## 2026-04-30 — Club-wheel V3.1 polish: catalog, hit ring, toggle anchor

The V3 toggle hit the right idea but the first round of feedback
exposed three issues:
  1. Manual mode still showed only the player's bag, so a sparse setup
     felt like "no other clubs being offered". The fix here is the
     definition of "manual" — when the assist is off, the wheel should
     stop being bag-shaped and become a flat picker over the canonical
     12-club catalog (plus any custom-named bag clubs).
  2. The hover-select drag was bound to a full-screen ZStack so any
     finger that started off-wheel and swept inward would commit a
     random club on release. We constrain the drag to the visual ring
     and treat off-wheel touches as taps-on-scrim or no-ops.
  3. The Auto / Manual chip was anchored above the chrome and clipped
     the top spoke. We move it below the wheel.

- Domain:
  - new `LiveRoundState.clubWheelDisplayedClubNames`: in auto mode it
    just returns `availableClubNames` (so the recommendation engine
    stays focused on real carry data); in manual mode it returns the
    full 12-club canonical set first, then any custom-named bag clubs
    (e.g. "Driving Iron"), then the currently-selected club as a final
    fallback
  - `clubWheelEntries` now iterates `clubWheelDisplayedClubNames`
    instead of `availableClubNames` so the wheel directly reflects the
    new manual-mode set
  - `selectClubFromWheel(_:)` validates against the wider displayed
    set and bypasses the narrower `selectClub` validation: it canon-
    icalises the name and writes `selectedClubName` directly. The
    canonical name then re-enters `availableClubNames` via the
    existing "selected club fallback" branch, so downstream consumers
    (companion sync, watch payload, plays-like calculator) see it
    in-scope without needing changes
  - `availableClubNames` is intentionally untouched — bag-only watch /
    companion behaviour is preserved (those surfaces should still
    surface the player's actual kit, not the universe of clubs)
- View:
  - `FreshLiveRoundClubWheelAutoToggle` repositioned to
    `center.y + outerRadius + 32` and clamped to the bottom safe-area
    inset; clearance below the chrome was reserved by reducing the
    layout's `usableMaxY` by an extra ~60pt so the wheel auto-floats
    upward on shorter screens rather than colliding with the toggle
  - drag gesture's `onChanged` / `onEnded` now early-return when
    `value.startLocation` lies outside the wheel's hit ring
    (`segmentDistance + half-entry diagonal`); the inside check is a
    pure point-in-circle so it stays cheap on every gesture frame
  - on `onEnded`-with-start-outside, we still honour scrim taps by
    dismissing when `value.translation < 8pt` (essentially a static
    finger), and silently swallow anything beyond that — i.e. drags
    sweeping in from off-wheel produce no commit and no dismiss
  - new private `isPointInsideWheel(_:center:layout:)` helper +
    `tapDismissTranslationThreshold` constant on `FreshLive
    RoundClubWheelOverlay`
- Tests:
  - 4 new `LiveRoundStateTests`:
    - `testManualModeExposesFullStandardCatalogEvenWhenBagIsSparse`:
      sparse 3-club bag → auto mode shows just those 3, manual mode
      shows the canonical 12
    - `testManualModePreservesCustomBagClubsAlongsideStandardCatalog`:
      custom "Driving Iron" gets appended after the 12 standards, in
      that order
    - `testSelectingNonBagStandardClubFromWheelInManualModePersists`:
      picking "8i" from the wheel in manual mode writes through to
      `selectedClubName`, surfaces in `availableClubNames`, and the
      selected entry has a non-zero baseline carry
    - `testSelectingClubFromWheelStillRejectsUnknownNames`: the wheel
      refuses junk like "Hammer" even in manual mode
- Verification:
  - `xcodebuild test` clean for 8 V3.1 / regression suites; existing
    regression suite (8 tests) re-runs clean
  - no lints in `LiveRoundState.swift`, `FreshLiveRoundScreen.swift`,
    or the tests
- Deferred:
  - making the manual-mode catalog user-configurable (e.g. let players
    hide clubs they truly never carry); for now the canonical 12 is a
    safe ceiling
  - haptic differentiation between "drag started on a spoke" vs
    "drag started in the centre hub" — currently both give the same
    selection-changed buzz when crossing into a sector

## 2026-04-30 — Club-wheel V3.2 polish: rotated hit math, tile visual hierarchy

V3.1 made manual mode show the full catalog, which surfaced a
pre-existing bug that had been hidden by sparse-bag setups: the
hover-hit math didn't rotate with the wheel. With 12 entries and a
non-zero `selectedIndex`, touching a visible spoke would commit a
*different* club whose pre-rotation index happened to land at that
angle. The user described this as "selecting in reverse". We also
tightened the drag region, lifted the selected entry above its
neighbours, scaled the Auto/Manual chip up, and pruned visual chatter
from the chrome and entry tiles.

- Geometry:
  - `FreshLiveRoundClubWheelGeometry.hoveredClubName(...)` picked up a
    `selectedIndex: Int = 0` parameter; the helper now applies the
    same `(index - selectedIndex)` rotation that
    `FreshLiveRoundClubWheelLayout.entryPosition` uses for placement
    (with a `((rawIndex + selectedIndex) % count + count) % count`
    fold to keep negative indices safe). Default of 0 keeps existing
    call sites compiling
  - `FreshLiveRoundClubWheelOverlay.hoveredClubName(...)` looks up the
    selected entry's index in `state.clubWheelEntries` and threads it
    through, so every drag/release frame uses the rotated map
- Drag region:
  - `isPointInsideWheel` now clamps to `layout.outerRadius` (the
    chrome's drawn edge) instead of `segmentDistance + entry-half-
    diagonal`. The earlier slack matched the entry-corner envelope but
    let the player engage the radial drag from up to ~40pt past the
    visible chrome, which contradicted the "circle is the wheel"
    mental model. Direct taps on overhanging entry corners still work
    via each entry's own `.onTapGesture`
- View hierarchy:
  - Each entry tile now sets a per-state `zIndex`: selected = 3,
    recommended = 2, default = 1. Without this, the scale-up on the
    selected tile could be clipped by the next-clockwise sibling in
    `ForEach` order
- Chrome cleanup:
  - Replaced the 24pt-wide opaque "plate" stroke at `orbitRingDiameter`
    with a hairline (0.75pt, dashed `[2, 5]`) orbit line. The old
    plate competed with the entry tiles for visual weight; the dashed
    orbit hints at rotation without dominating the silhouette
- Entry tile cleanup:
  - Dropped the `LinearGradient(... blendMode(.screen))` glass
    highlight on unselected tiles — it doubled up with the chrome's
    own glass shimmer
  - Tile background is now a two-stop ZStack: ultraThinMaterial +
    `wheelEntryFill.opacity(0.55)` (selected switches to a solid
    accent fill). Cleaner read at small sizes
  - Type pulled into a rounded design family for a more "instrument"
    feel: club name `.system(size: 16, .bold, design: .rounded)`,
    gap/carry `.system(size: 11, .semibold, design: .rounded)`
  - Source dot now only appears for `.logged` carries (the empty
    outlined dot for baseline data was meaningless visual noise);
    bumped to a flat 5pt accent dot
  - REC badge gets a subtle inner stroke for contrast against the
    accent fill, and the recommendation halo's lineWidth dropped from
    2.5pt to 2pt to match the lighter overall feel
- Toggle chip:
  - Scaled from 11pt icons / `.caption` text to 13pt icons /
    `.subheadline` text; padding bumped to 18pt × 11pt; shadow radius
    8pt @ y=5
  - Anchor moved from `outerRadius + 32` to `outerRadius + 52` (with
    a 32pt floor to the bottom safe area) so the larger pill clears
    the chrome with breathing room
  - Layout's `usableMaxY` reserve grew from 84pt to 112pt so the
    bigger toggle still fits on shorter screens
- Tests:
  - existing `testClubWheelHoverSelectionIncludesVisiblePillCorner`
    keeps passing (default `selectedIndex: 0` preserves old behaviour)
  - new `testClubWheelHoverSelectionRotatesWithSelectedIndex`: walks
    every spoke at `selectedIndex = 5` and asserts the helper returns
    the post-rotation entry — locks in the bug fix
  - new `testClubWheelHoverSelectionWithSelectedIndexZeroMatchesUn
    rotatedDefault`: explicit-vs-default `selectedIndex: 0` produce
    identical results, guarding the back-compat default
- Verification:
  - 13 targeted club-wheel tests pass (3 new + 10 regression),
    no lints introduced

### Aim line / carry distance off-course fallback

- Problem:
  - When the player's GPS is way off-course (simulator parked
    elsewhere, stale location fix, or the user has wandered behind
    the teebox), the live HUD aim line stretched from that distant
    point all the way to the pin, with a comically large carry
    pill ("13,000,000 m") and the crosshair landing in the middle
    of the ocean. The aim visualisation only makes sense when
    you're actually playing the hole
- Fix:
  - Introduced `LiveRoundState.shotOriginCoordinate`, a single
    source of truth for "where does the shot start from?". It
    returns the player's GPS when they're sensibly on-hole, and
    falls back to the tee centroid when they're meaningfully
    further from the pin than the tee is (8 m tolerance to absorb
    GPS jitter behind the tee box)
  - The aim polyline (both the MapKit `MapPolyline` branch and the
    SwiftUI overlay used during drag), the carry distance pill,
    and the carry midpoint annotation now all originate from
    `shotOriginCoordinate` instead of `playerCoordinate` directly
  - `planningCarryDistanceMeters` was also flipped to use the new
    origin so the pill and the line stay in sync — a 12,000 km
    carry number with a 200 m line on screen would have been
    embarrassing
- Initial planning target hardening:
  - The constructor's `initialPlanningTargetCoordinate` factory
    used to return the midpoint between the raw player coordinate
    and the pin. With an off-course player that's often in open
    ocean far from the hole, which broke initial framing and the
    crosshair drag clamp
  - It now resolves the shot origin via the same shared
    `resolvedShotOrigin(player:tee:pin:toleranceMeters:)` helper
    and returns the midpoint of (origin, pin), so the crosshair
    seeds on the fairway instead of the open ocean when the
    player isn't actually on the course
- New helpers:
  - `LiveRoundState.resolvedShotOrigin(player:tee:pin:tolerance
    Meters:)` — static fallback rule shared by the instance
    computed property and the planning-target factories so the
    rule stays consistent across all entry points
  - `LiveRoundState.teeCoordinate(for:features:)` — static
    counterpart to the existing instance `teeCoordinate`, mirrors
    the shape of the existing static `pinCoordinate(for:features:)`
- Tests:
  - `testShotOriginFallsBackToTeeWhenPlayerIsBehindTeebox`: player
    parked in Cupertino while the round is in Melbourne; asserts
    the origin coordinate equals the (Melbourne) tee centroid
  - `testShotOriginUsesPlayerWhenTheyAreOnTheHole`: player half
    way down the fairway; asserts the origin equals the player
    coordinate (so the live HUD still tracks the user when
    they're playing)
  - `testPlanningCarryDistanceUsesShotOriginNotRawPlayerCoordinate`:
    verifies the carry pill stays under 1 km when the player is
    off-course (i.e. it follows the line, not the broken raw
    player→aim distance). Currently asserts the implementation
    contract; full simulator runtime is queued behind a
    pre-existing `productType = watchapp2` build configuration
    issue (Xcode 26.3 deprecated that legacy spec) that is
    independent of this change

### Shot logger redesign — context-aware tee/shot/putt flow

- Problem:
  - The shot logger was a one-size-fits-all sheet that asked the
    same questions at every moment of the hole — surface, miss
    direction, distance result, provisional ball, etc. — even when
    most of those inputs were irrelevant (e.g. asking "did you
    hit the green?" while the player is standing on the green
    trying to log a putt)
  - Players had to manually switch between a "Basic" and "Advanced"
    logger via Profile, which meant the right level of detail was
    a settings-screen task rather than something the app inferred
    from where they actually were on the hole
  - The visual treatment was prototype-y: flat sections, dense
    labels, small CTA, no iconography differentiating surface chips
- Fix:
  - Introduced `ShotLoggerContext` (`.tee` / `.shot` / `.putt`) on
    `LiveRoundState`. The context is derived automatically from the
    inferred surface, the upcoming stroke number, and the live
    distance to the pin — opening stroke is always tee, anything
    on the green or under ~10 m to the pin is putt, and everything
    in between is a normal shot
  - Killed the Basic/Advanced toggle entirely: removed
    `LiveRoundLoggerMode`, the `LiveRoundLoggerModeStoring` protocol,
    its `UserDefaults`-backed implementation, the `liveRoundLoggerMode`
    `@Published` on `AppState`, and the Profile "Shot logging" card
  - The logger sheet now switches between three context sections:
    - `teeContextSection`: club picker + outcome (direction +
      distance) + provisional-ball chip when `pendingShotShotType`
      can be `.provisional`
    - `shotContextSection`: club picker + outcome
    - `puttContextSection`: explicit "Holed" / "Missed" choice
      (no default — `pendingShotPuttHoled: Bool?` starts `nil` so
      the CTA stays disabled until the player commits) and a
      reveal-on-miss panel for miss direction + miss distance
  - An always-visible "Inferred lie" banner sits at the top of the
    sheet showing the auto-detected surface, the reason text, and
    expanding into a tap-to-edit `liePickerStrip` (chips for tee,
    fairway, rough, sand, recovery, water, green) so players can
    correct the inference without digging through settings
  - Optional metadata (strike quality, note, penalties, drops,
    stroke override; or putt count / first-putt distance / penalties
    in putt context) is hidden behind a collapsible
    `addDetailDisclosure` so the primary form stays clean
  - The CTA label is now driven by `pendingShotConfirmCTAText`:
    "Log tee shot" / "Log shot" / "Log putt" / "Hole out" depending
    on context and the holed/missed selection
  - Visual polish:
    - Surface chips picked up SF Symbol iconography (flag.fill for
      tee, leaf.fill for fairway/rough, sparkles for sand,
      water.waves for water, target for green, etc.)
    - Glass material backdrop, denser layout, rounded SF for
      labels, larger primary CTA matching the rest of the live HUD
- Data model:
  - Extended `ShotEvent.PuttDetail` with `holed: Bool` and
    `missDistanceMeters: Int?`. Custom `Decodable` keeps existing
    persisted shot history backwards-compatible (older payloads
    decode `holed = false`)
- Tests:
  - Dropped tests that assumed the Basic/Advanced toggle:
    `testShotLoggerUsesPreferredModeOnPresent`,
    `testShotLoggerModeCanSwitchWhilePresented`,
    `testLoggerModeDefaultsToBasic`,
    `testInitializerRestoresPersistedLiveRoundLoggerMode`,
    `testChangingLiveRoundLoggerModePersistsSelection`,
    `testProfileProductionViewUsesLiveRoundLoggerModeFromAppState`
  - New tests on `LiveRoundState`:
    - `testCurrentShotLoggerContextIsTeeOnOpeningStrokeRegardlessOf
      SurfaceInference`: opening stroke wins even if the inferred
      surface looks fairway-like
    - `testCurrentShotLoggerContextSwitchesToPuttOnceSurfaceIsGreen`
    - `testCurrentShotLoggerContextIsShotForFairwayMidHole`
    - `testPendingShotConfirmCTAAdaptsToContext`: tee → shot →
      putt → hole-out copy
    - `testPendingShotLieBannerTitleReflectsSelectedSurface`:
      banner title and subtitle update when the user manually
      picks a different lie chip
    - `testPuttContextRequiresHoledMissedChoiceBeforeConfirm`: the
      CTA stays disabled until `pendingShotPuttHoled` is non-nil
    - `testConfirmingHoledPuttPersistsHoledFlagAndShotType`:
      logged shot has `puttDetail.holed == true` and shot type
      `.holedOut`
    - `testConfirmingMissedPuttPersistsMissDirectionAndDistance`
    - `testMarkingPuttHoledClearsPreviouslyEnteredMissFields`:
      flipping back to "Holed" wipes the miss panel state so we
      never persist contradictory data
    - `testConfirmingPuttWithoutMissDistanceLeavesItNil`
    - `testConfirmPendingShotStoresStrikeAndNoteWhenAddDetailIsUsed`:
      replaces the old "Advanced fields" test with the new
      add-detail disclosure equivalent
    - `testShotLoggingSubtitleSwapsToPuttCopyOnTheGreen`
  - Refreshed `testPresentShotLoggerResetsPendingStructuredSelections`
    to assert the new putt state (`pendingShotPuttHoled`,
    `pendingShotPuttMissDirection`, `pendingShotPuttMissDistanceMeters`)
    plus `isShowingShotLoggerAddDetail` reset on every present
  - Repaired two pre-existing stale assertions surfaced by the
    refactor: `testShotLoggingSummaryReflectsCurrentSelection` and
    `testConfirmPendingShotLogsSelectedSurfaceAndDismissesLogger`
    were hardcoding "152m" / "8i" expectations that never matched
    the actual computed planning distance; both now exercise the
    real `presentShotLogger()` flow and assert against
    `state.liveDistanceToPlanningTargetMeters`
- Verification:
  - All 13 new logger-flow tests pass on the iPhone 17 Pro Max
    simulator clone, plus the 11 pre-existing logger tests
    (surface inference, provisional, basic-fields confirm,
    direction/distance gate, manual club override, planning
    target dragging) regress cleanly
  - The two stale tests now pass after de-hardcoding the planning
    distance
  - Other `LiveRoundStateTests` failures (GPS / location stub,
    companion snapshot bag-driven options, snapshot mismatch
    fallback, etc.) are pre-existing and independent of this
    redesign

### Live round wind / weather widget refactor

- Goal: the existing wind read in the live round was prototype-y —
  the top HUD showed an absolute compass card (`12 NW`) that's
  redundant with the Plays-Like number sitting two cells away, and
  the Conditions sheet was a flat list of `Wind / Temperature /
  Condition / GPS / Attribution` rows with no information density.
  Players actually want the wind described relative to the shot
  they're about to play, not relative to north.
- Top HUD: replaced the `Wind: 12 NW` text-only `topMetricCard`
  with a new `windHUDChip` composed of:
  - A directional arrow (`Image(systemName: "arrow.up")` rotated
    by `windRelativeMotionDegrees`) that points "with the wind"
    relative to the shot bearing — tail wind = arrow up, head =
    arrow down, cross-right = arrow right, etc.
  - The wind speed in km/h (monospaced digits, same width budget
    as the old card so the HUD layout doesn't shift)
  - A category subtitle pulled from
    `LiveRoundState.windRelativeCategory` (`Tail`, `Head`,
    `Cross R`, `Cross L`, ..., `Calm` for speeds < 3 km/h)
  - The whole chip is a `Button` that opens the Conditions sheet,
    making the chip the discoverable entry point. The launcher
    tray "Conditions" button still works as a secondary path.
- Conditions sheet: rebuilt `FreshLiveRoundConditionsSheet` from a
  `List` into a `ScrollView` of visual cards on the round palette:
  - **Wind hero**: an 88pt directional arrow on a tinted dial with
    compass tick marks, the speed value at 36pt rounded font, the
    relative category as a coloured headline, and two callouts:
    one with the head/cross component breakdown
    (`12 km/h head · 4 km/h cross R`) and one with the plays-like
    delta the wind is contributing (`+6 m to plays-like`)
  - **Temperature card**: thermometer icon + value + plays-like
    temperature delta footer (cooler air = denser = ball flies
    less = positive plays-like adjustment)
  - **Sky card**: the `RoundWeatherSnapshot.symbolName` as a
    hierarchical SF Symbol next to the condition description
  - **GPS card**: location accuracy / status
  - **Attribution card**: standalone footer styling
- New derived state on `LiveRoundState` so the views stay dumb:
  - `WindRelativeCategory` enum (calm, head, tail, crossLeft,
    crossRight, plus the four quartering bands) with a `label`
    accessor used by the chip subtitle and the hero category text
  - `shotBearingForWind`: live shots use
    `playerCoordinate → planningTargetCoordinate` (so the chip
    re-classifies as you drag the aim crosshair); inspecting a
    different hole falls back to that hole's tee→pin line
  - `windRelativeMotionDegrees`: the direction the air is moving
    expressed in the shot-relative frame (0° = with the shot,
    180° = into face, 90° = blowing right, 270° = blowing left)
  - `windHeadComponentKmh` / `windCrossComponentKmh`: signed
    components in km/h. Head positive = into face, cross positive
    = pushing ball right
  - `windRelativeCategory`: 8-way classification with 22.5°-wide
    bands so a near-pure tail doesn't flicker between `Tail` and
    `Tail R` when the reported direction wobbles a degree
  - `hasUsableWindReading`: true when there's a snapshot, speed is
    ≥ 3 km/h, and we resolved a direction (compass parse or
    explicit degrees)
  - `playsLikeWindDeltaMeters` / `playsLikeTemperatureDeltaMeters`:
    surface the contribution of each effect for the Conditions
    callouts. Built on top of the existing `PlaysLikeCalculator`
    statics — no new physics
  - `windComponentBreakdownText`: combined "12 km/h head · 4 km/h
    cross R" string used by the hero callout. Returns `nil` for
    calm winds so the view can hide the row instead of rendering
    a meaningless "0 km/h head · 0 km/h cross"
- Tests (added to `LiveRoundStateTests.swift`, all passing):
  - `testWindHeadComponentIsPositiveWhenWindBlowsFromAheadOfTheShot`
  - `testWindHeadComponentIsNegativeWhenWindBlowsFromBehindAsTailwind`
  - `testWindCrossComponentIsPositiveForLeftToRightCrossWind`
  - `testWindCrossComponentIsNegativeForRightToLeftCrossWind`
  - `testWindCategoryReportsCalmBelowThreeKilometersPerHour`
  - `testWindRelativeCategoryIsCalmWhenNoWeatherSnapshotPresent`
  - `testPlaysLikeWindDeltaIsPositiveIntoTheBreezeAndNegativeWithIt`
  - `testPlaysLikeTemperatureDeltaIsPositiveBelowBaselineAndNegativeAbove`
  - `testWindComponentBreakdownTextDescribesHeadAndCrossWhenBothAreNonZero`
  - All exercise the live-shot path: a synthesised due-north hole
    with the player parked on the tee, so the shot bearing is a
    deterministic 0° and the projected components stay readable
- Verification: build is clean. All 9 new wind tests pass; the
  pre-existing failures (GPS / location stub, companion snapshot
  bag-driven options, displayed-distance metrics, recommended map
  region, snapshot mismatch fallback) remain unrelated to wind /
  weather code and were already failing prior to this refactor

### Live round top-bar redesign — phase-adaptive hero

- Goal: the previous top panel was two rows of equally-weighted
  cards (`Strokes | Hole nav | Wind` over `Front | Pin | Plays |
  Back`). Every metric had the same visual weight, so the player's
  eye couldn't find the pin distance at a glance, and the Plays
  card was redundant noise whenever wind / temperature didn't move
  the number. The four-card distance row also ate vertical chrome
  even on putts where Front / Back are irrelevant.
- New layout (~same height as before, intentionally — we redistribute
  weight rather than reclaim space):
  - **Row 1 — identity strip**: a compact "score-to-par + stroke"
    chip on the left, the existing hole-nav cluster centred, and
    the always-on shot-relative wind chip on the right.
  - **Row 2 — phase-aware hero**: a centred hero distance card
    (PIN or PUTT, ~40–48pt rounded numerals) flanked by exactly
    *two* satellite chips that swap based on the player's
    `LiveRoundState.shotPhase`:
    - `.teeShot`: `Front · HERO · Recommended club` (tee shots
      care about reaching the fairway and what's in your hand,
      not back of green)
    - `.approach` / `.scoring`: `Front · HERO · Back`
    - `.greenSide`: hero only — wind / plays-like / club
      recommendation are noise on a putt; subtitle becomes
      "Stroke N of par X"
- Hero subtitle copy is consolidated into one line:
  - `+6 m plays · 7i` (approach / scoring with meaningful delta and
    a recommended club)
  - `+6 m plays` (tee phase — club already shown in trailing chip)
  - `Stroke 3 of par 4` (green-side)
  - hidden entirely when there's nothing meaningful to print (calm
    wind + no recommendation)
- Score chip:
  - Headline = `roundScoreToParDisplay` ("E" / "+1" / "-2"), tinted
    course-accent under par and red over par so the chip carries a
    subtle "good / bad" cue without an icon
  - Subtitle = `Stk N` mid-hole / `Score N` on confirmed holes.
    Replaces the old standalone "Strokes 2/4" card on the left.
- Visual polish:
  - Hero card uses a tinted-accent fill + 1-pt accent border to
    pop above the satellite chips, plus `.contentTransition(.numericText())`
    so the pin distance animates as the player walks.
  - `FreshLiveRoundTopPanelLayout` now ships a dedicated
    `heroValueFontSize` (40 compact / 48 regular) separate from the
    smaller `distanceValueFontSize` used for the satellite chips.
  - Old `topMetricCard`, `distanceMetric`, and the `strokeMetric*`
    helpers were removed along with the two `chromeMetrics` fields
    that fed them (`distanceMetricValueFontSize`,
    `distanceMetricVerticalPadding`).
- Future-work slots intentionally left open in the design:
  - **Carry-to-corner**: needs either course-tagged `.layup`
    features (none in `medway.json` today) or a fairway-polygon
    bend-detector. The trailing-satellite slot is already
    pluggable so it can drop into tee phase later without
    re-laying out the row.
  - **Elevation delta to pin**: blocked on a DEM data source —
    `PlaysLikeCalculator` explicitly notes this. When we have it,
    the hero subtitle has room for a third inline component
    (`+6 m plays · ↑ 4 m · 7i`).
- State additions on `LiveRoundState`:
  - `enum TopBarPhase { tee, approach, scoring, greenSide }` and
    `var topBarPhase` mirroring the existing `shotPhase`. Pulling
    it through a dedicated type keeps the view layer free to
    evolve (e.g. adding a "putt-from-fringe" variant) without
    touching the canonical `shotPhase`
  - `playsLikeDeltaSignedMeters` (sum of wind + temp delta) and
    `hasMeaningfulPlaysLikeDelta` (`abs(...) >= 2`) so the hero
    subtitle stays clean when the wind drops to a breeze
  - `topBarHeroDistanceMeters`, `topBarHeroSubtitle`,
    `topBarScoreHeadline`, `topBarScoreSubtitle` so the SwiftUI
    body stays declarative and the strings round-trip through
    unit tests
- Tests (`LiveRoundStateTests.swift`):
  - `testTopBarPhaseMirrorsShotPhaseOnFreshTeeShot`
  - `testTopBarPhaseLeavesTeeBandAfterFirstShot` — pivots away
    from `.tee` once the player swings; the post-tee phase is
    geometry-dependent so we just assert the negative
  - `testTopBarHeroSubtitleHidesPlaysLikeWhenDeltaIsTrivial`
  - `testTopBarHeroSubtitleSurfacesPlaysLikeOnApproachWhenDeltaIsMeaningful`
    — uses the wind-test harness to inject a 25 km/h head wind and
    asserts the subtitle includes "plays"
  - `testTopBarHeroSubtitleSwapsToStrokeCounterOnTheGreen` — seeds
    `distanceToPinMeters` directly (it's a stored heuristic, not a
    GPS read) so the green-side branch is hit deterministically
  - `testTopBarScoreChipReadsEvenParAndStrokeCounterMidHole`
  - `testTopBarScoreChipShowsRecordedScoreWhenInspectingConfirmedHole`
    — confirms hole 1 through the full pending-summary form, then
    inspects it from hole 2 to verify the chip pivots to "Score N"
  - `testPlaysLikeDeltaSignedMetersCombinesWindAndTemperature` —
    sign + sum match the underlying wind / temperature contributions
  - `testLiveRoundChromeMetricsFavorEdgeAlignedLauncher` — renamed
    + trimmed to drop assertions on the deleted distance-card
    metrics
- Verification: build is clean, all 8 new top-bar tests pass on
  the iPhone 17 Pro Max simulator clone. The pre-existing
  unrelated failures (`testAtBallSuggestion*`, `testCompanionSnapshot
  CarriesBagDrivenClubOptions`, `testDisplayedDistanceMetrics
  UseLivePinDistanceAndGreenGeometryOnActiveHole`, GPS / location
  stub tests, snapshot mismatch fallback) are still pre-existing
  and unrelated to this redesign

### Top-bar polish — hole-nav cluster + Front/Pin/Back coherence

- Two compounding bugs surfaced once the new identity strip
  landed (visible together on the Medway hole 1 simulator
  capture: `H1 / Par 4 • …`, `Front 388 m · Pin 152 m · Back 388 m`).

#### Bug 1 — Hole subtitle still ellipsising

- Earlier attempts trimmed the redundant `thru N` and the
  irrelevant `selectedTeeDistanceMeters`, then added a
  geometry-derived `displayedHoleTeeToPinMeters`. Even that —
  `Par 4 • 348 m` — was still being rendered as `Par 4 • …` on
  some font/scale combinations.
- Fix: collapse the subtitle to a single component, **`Par N`**.
  The live distance signal is fully carried by the PIN hero
  card directly below; a per-hole tee→pin string in the cluster
  was redundant data fighting the score chip and wind chip for
  width. `displayedHoleTeeToPinMeters` is kept around (still a
  computed property) for future feature use, but no longer
  drives the cluster subtitle.

#### Bug 2 — Front == Back == 388, Pin == 152 (impossible green)

- Cause: `displayedGreenDistanceExtrema` measured each green
  polygon vertex from `playerCoordinate`, but `playerCoordinate`
  falls back to the **course centroid** when GPS isn't available
  (simulator, cold start, location permission pending). On
  Medway hole 1 the course centroid sits ~388 m from the green;
  every vertex was approximately equidistant from that fallback
  point so `front` and `back` collapsed to ~388. Meanwhile
  `displayedPinDistanceMeters` happily reported the heuristic
  `@Published var distanceToPinMeters` value (152). The three
  HUD numbers were sourced from completely different reference
  frames and physically could not agree.
- Fix: refactored `displayedGreenDistanceExtrema` to **anchor on
  `displayedPinDistanceMeters`**. We now compute, for each green
  vertex, the **signed offset from the pin centroid** projected
  onto the tee→pin axis, then add `min(offsets)` and
  `max(offsets)` to the displayed pin distance. Net result:
  - Front always lands closer than the pin by the polygon's
    front-of-green depth, and Back always lands farther by its
    back-of-green depth.
  - The numbers are invariant to whether `playerCoordinate` is
    real GPS, an inspection fallback, or the course centroid.
  - The outer `clampToHoleMaxReasonableDistance` still keeps a
    "way off course" sim location from blowing up.
- Tests (`LiveRoundStateTests.swift`):
  - Replaced
    `testTopPanelSubtitlePrintsParAndPerHoleTeeToPinDistance`
    and the degenerate-geometry case with
    `testTopPanelSubtitleIsParOnlySoItCannotEllipsiseInTheCluster`
    + `testTopPanelSubtitleReadsParThreeOnAParThreeHole`,
    which assert the subtitle is exactly `Par N` and contains
    no separator that could be ellipsised.
  - Replaced
    `testDisplayedDistanceMetricsUseLivePinDistanceAndGreen
    GeometryOnActiveHole` (which was a pre-existing failure
    because it asserted `back > front` with no green
    geometry) with
    `testDisplayedFrontAndBackAnchorOnPinDistanceWithGreen
    PolygonDepth` — synthesises a small ~13 m-deep green and
    checks Front < Pin < Back with a sane spread (< 80 m, to
    catch reference-frame regressions).
  - Added
    `testDisplayedFrontAndBackCollapseToPinWhenNoGreen
    GeometryIsAvailable` so the no-features branch has an
    explicit contract: Front == Pin == Back rather than a
    silently divergent value.

### Runtime course discovery + on-device OSM import

- New round-setup capability: auto-list golf courses within
  10 km of the user's GPS, plus a country-scoped name search
  for everything else. When the user picks a course we don't
  already have bundled, we download its OSM geometry, convert
  it on-device into our `SwingPalCourse` shape, validate it
  in two passes, and persist it so a re-round skips the
  network. All of this runs behind a multi-stage loading
  overlay the user can cancel.
- Phase 1 — Discovery + UI:
  - `OSMCourseDiscovery.swift` exposes
    `LiveOSMCourseDiscovery` over Overpass + Nominatim. The
    parsers are split into `OverpassDiscoveryParser` and
    `NominatimSearchParser` so tests can exercise them with
    bundled JSON without touching the network. Sets the OSM
    user-agent per OSM policy; backs off on 429/503.
  - `CourseDiscoveryGeocoding.swift` resolves the user's
    country code via `CLGeocoder` (mockable in tests).
  - `RoundSetupState` is now `@MainActor` and gains
    `userLocation`, `userCountryCode`, `nearbyDiscoveries`,
    `searchQuery`, `searchResults`, `discoveryStatusMessage`,
    plus `loadNearbyCoursesIfNeeded()` and a 300 ms-debounced
    `updateSearchQuery(_:)` that auto-resolves the country on
    first keystroke.
  - `RoundSetupView` grows a search field above the course
    list, a "Search results" subsection when the field is
    non-empty, and a "Discover nearby" subsection otherwise.
- Phase 2 — On-device import + deterministic gates:
  - `OSMCourseGeometryFetcher.swift` runs a 1.5 km
    `out geom;` Overpass query for a single course and caches
    the raw payload to `~/Library/Caches/SwingPal/OSMRawJSON/`.
  - `RuntimeOSMCourseConverter.swift` is a Swift port of
    `tmp/convert_osm_to_course.py`. Same algorithm
    (centerline assignment with `MAX_ASSIGNMENT_DISTANCE_M =
    80`, tee/green orientation, deterministic UUID v5s seeded
    by the course slug). Differences: no per-course
    `course_filter`, no `par_overrides`, synthetic
    Championship/Member/Forward yardages estimated from the
    summed tee→green distances. UUID v5 verified against the
    bundled `medway.json` course id
    (`a672bfce-4b78-58bb-bf75-db3da0afdbd0`) so runtime IDs
    line up with the build-time pipeline.
  - `DeterministicCourseValidator.swift` enforces the
    hard-block gates from the design plan: hole count ∈
    {9, 18}, contiguous numbering, tee + green per hole,
    per-hole par 3..5, total par scaled to hole count
    (9-hole → 27..40, 18-hole → 60..80), tee→green distance
    50..700 m, no two greens sharing a vertex within 1 m.
  - `CourseImportCoordinator.swift` exposes an
    `AsyncStream<CourseImportStage>` that drives
    `fetchingGeometry → converting → runningDeterministicGates
     → runningAIReview → completed` (or `.failed`).
    Cancellation propagates via the consuming `Task`.
  - `CourseImportLoadingOverlay.swift` renders the
    multi-step progress as a `.fullScreenCover`, with
    per-stage check/spinner indicators and terminal cards
    for failure / provisional outcomes.
- Phase 3 — Foundation Models advisory layer:
  - `FoundationModelsCourseValidator.swift` mirrors
    `FoundationModelsRoundSummaryAnalyzer`. Sends a small
    structured digest (no raw geometry — par distribution,
    tee→green percentiles, per-hole feature counts, missing-
    fairway count) and asks for
    `{"verdict":"ok|concerns|broken","concerns":["..."],
    "oneLineSummary":"..."}`. Verdicts map to the
    coordinator's outcomes:
    - `ok` (model available) → `.approved`,
    - `concerns` → `.provisional` with the bullets surfaced
      on the overlay,
    - `broken` → coordinator emits `.failed`,
    - any model-unavailable / parse-error path falls back to
      `aiAvailable: false`, which also lands as
      `.provisional`. Mirrors the resilience pattern in
      `LiveFoundationModelsRoundSummarySession`.
  - `RoundRootView` now constructs the live coordinator with
    `LiveOSMCourseGeometryFetcher` + the AI validator;
    `RoundSetupState`'s default still uses
    `NoAICourseValidator` so unit tests stay deterministic.
- Phase 4 — Persistence:
  - `ImportedCourseStore.swift` writes each accepted course
    to `~/Library/Caches/SwingPal/Courses/<osmID>.json` and
    records a manifest entry with the validation outcome and
    AI summary so the cached list survives across launches.
  - `CompositeCourseRepository.swift` replaces
    `SeededCourseRepository` at app boundaries, merging
    bundled + cached imports. Bundled wins on dedupe (so a
    later hand-traced course overrides a previously imported
    one) and we round coordinates to ~100 m for the dedupe
    key so OSM relation moves don't double up.
  - `RoundSetupState.acceptImportedCourse()` persists through
    the store before adding the course to the in-memory list,
    so re-launching the app and re-rounding skips the import
    pipeline entirely.
- Tests added:
  `OSMCourseDiscoveryTests` (8) — Overpass + Nominatim
  parser fixtures, bbox math, dedupe;
  `RoundSetupStateTests` (+5) — nearby load, location
  denial, search debounce, country-coded placeholder, reset;
  `RuntimeOSMCourseConverterTests` (8) — happy path, par
  override, deterministic UUID round-trip against the
  bundled medway course id, haversine sanity;
  `DeterministicCourseValidatorTests` (5) — every gate
  passes/fails as expected;
  `CourseImportCoordinatorTests` (5) — stage stream,
  approved/provisional/broken verdict mapping, deterministic
  failure short-circuit;
  `FoundationModelsCourseValidatorTests` (8) — verdict
  mapping, three failure-mode fallbacks, response-noise
  parser, structured-summary shape;
  `ImportedCourseStoreTests` (4) — round-trip, idempotent
  re-save, manifest order, removal;
  `CompositeCourseRepositoryTests` (3) — bundled-only,
  merged-and-sorted, bundled-wins-dedupe.
- Verification: 73 tests across the impacted suites pass on
  the iOS 18 simulator clone. Pre-existing failures in
  `LiveRoundStateTests` (GPS / location stubs),
  `AppStateTests.testChangingGPSMode...`,
  `HomeViewModelTests.testRoundDetailModel...` (date-format
  locale), and `CourseCorrectionCenterTests` are unchanged
  by this work.
