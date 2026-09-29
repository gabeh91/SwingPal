# Native Course in hand Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement SwingPal's bespoke Course in hand direction in native SwiftUI, prioritising the complete golfing flow.

**Architecture:** Keep existing domain/state services and audit fixes. Build screen-specific SwiftUI compositions using an original repository-native terrain drawing, semantic named colour assets and native controls. Share only the artwork, palette and action styles justified by those screens; real maps remain geographic data.

**Tech Stack:** SwiftUI, Canvas/Path artwork, MapKit, existing XCTest suite, iOS Simulator.

Work remains in the current shared checkout to preserve the explicitly authorised uncommitted audit fixes. Do not commit unrelated work. Pure visual changes are verified through native renders; behavior changes receive focused regressions before implementation.

## Tasks and ownership

- [x] 1. Parent: shared artwork/colour foundation and Home.
- [x] 2. Native setup agent: course selection/setup and complete review composition.
- [x] 3. Parent: native navigation shell and launch identity.
- [x] 4. Native live agent: live hole distance/map/action composition, accessible alternatives.
- [ ] 5. Supporting screens: integrate bag/profile, Stats and Social with the authored language without losing existing actions.
- [ ] 6. Review: integrated build/tests, actual native populated/empty/incomplete/error fixtures, default/AX text and appearance captures; record remaining device-only limits.

## 1. Artwork and Home

Files: `SwingPal/DesignSystem/DesignTokens/ShellTokens.swift`, `SwingPal/Assets.xcassets/`, `SwingPal/Features/Home/HomeView.swift`, `SwingPal/Features/Home/HomeViewModel.swift`, `SwingPal/App/AppShellView.swift`.

Create named adaptive colours and an original `CourseTerrainArtwork` SwiftUI view. Shared interface: `CourseStyle.ground/surface/ink/muted/action/onAction/line/wash/warning`; `CourseTerrainArtwork()`; `CoursePrimaryButtonStyle()`. Use native text styles and no display serif, glow, gradient or repeated hero cards. Home has course identity, a compact terrain object, one start/resume action and truthful history/course rows. Keep analysis/history and Watch routes reachable. If active-round hole progress is added to the model, regression-test its real state mapping.

## 2. Setup and review

Files: `SwingPal/Features/Round/RoundSetupView.swift`, `RoundRootView.swift`, `RoundReviewView.swift` and narrowly required state presentation APIs/tests.

Search and saved courses first; selection then reveals compact course identity, native named tee choices and player rows. Retain imports, source status, corrections, permissions and failures. Use native back navigation and preserve selections. Review consumes actual hole entries, shows missing/confirmed states, offers edit routes and retains draft/completion semantics from the audit. No fabricated synced/private claims. Components are extracted from these concrete needs.

## 3. Navigation and launch

Files: `SwingPal/App/AppShellView.swift`, `SwingPal/SwingPalApp.swift`.

Use native tab behavior with Home/Social/Round/Stats/Profile and proper safe areas. Preserve resume/discard confirmation. Hide tabs in live play only where useful. Remove delayed slogan splash and decorative gradient identity; launch immediately into useful content. Reduce Motion guards custom transitions.

## 4. Live play

Files: `SwingPal/Features/Round/FreshLiveRoundScreen.swift`, HUD views and narrowly scoped presentation models.

Real map, clear hole/target identity, front/centre/back distance instrument, one club context and separate shot/score actions. Preserve map tools, logging, undo, score correction, inspection, weather and exit routes. Provide an ordinary club list for accessible sizes/VoiceOver; no gesture-only essential action. Reflow at AX sizes; remove motion when requested. Never label an inferred centre as a surveyed pin.

## 5. Secondary destinations

Files: Profile/Bag, Stats and Social SwiftUI views. Replace editorial mastheads and repeated cards with task-led compositions while preserving auth, profile editing, bag editing, analysis/history and discovery routes. Original club artwork belongs on bag overview, not every form. Native form controls retain expected behavior.

## 6. Validation

Run `xcodebuild -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,id=42DF0A73-3481-4DAA-B8B6-9CFEECB34AB4' -derivedDataPath /private/tmp/SwingPal-redesign-build -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO` and require all regressions to pass. Baseline after audit: 462 tests passing.

Use explicitly isolated DEBUG design fixtures if necessary to reach populated, empty, incomplete and error states without cloud writes. Fixtures must not affect production or default user data. Capture native iPhone default/light and dark/AX, plus compact width where feasible. Review visual hierarchy, clipped controls, reachable actions and provenance, not merely build success. Update `docs/design/UI_DIRECTION.md` and `docs/design/review/README.md` with actual implementation/rationale and exact evidence.

## Iteration checkpoint

Native core implementation and its automated regressions are complete for this pass. The first symbolic/boxy native design was rejected by the owner. Home was revised to a useful supplied-geometry course plan with native selection, and setup/live share that course context. This is not a finalised design. Supporting screens are implemented but need more visual review; broader device/accessibility review remains open. Exact native evidence and limitations are recorded in `docs/design/review/README.md`. No release, commit or push is implied.
