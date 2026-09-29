# Review evidence

21 September 2026

## Native baseline

- Build: repository commit `79ab657`, before audit repairs.
- Xcode project/scheme: `SwingPal`.
- OS/device: iPhone 17 Pro, iOS Simulator 26.3.1.
- Isolated UI device: `SwingPal Design Audit` (`42DF0A73-3481-4DAA-B8B6-9CFEECB34AB4`).
- Captured: light appearance, default text size, empty local round history, guest Home: [home-empty-light.png](current/home-empty-light.png).
- Inspected: Home and the location explanation sheet using native UI and accessibility-tree output. The sheet was not treated as permission to grant location access.
- Observed: large editorial masthead and translucent round card dominate the first viewport. Nearby values show 2.6/3.2 km without a granted location. This is baseline evidence, not evidence of the proposed design.

## Baseline tests

`xcodebuild test` on iPhone 17 Pro, iOS 26.3.1: 446 total, 438 passed, 8 failed. Result: `/private/tmp/SwingPal-audit-build/Logs/Test/Test-SwingPal-2026.09.21_16-44-58-+1000.xcresult`.

Six club wheel tests assumed the full catalog while automatic filtering now returns a smaller set. Three indexed past the fixture array and trapped. Two round setup tests exposed a missing unit label/stale placeholder. These were present before audit fixes.

## Proposed compositions

[Open the interactive study](course-in-hand/index.html). It is a single self-contained HTML file, with no network dependencies. It may be opened directly or served from this design directory. The current local review URL is `http://127.0.0.1:8769/review/course-in-hand/index.html` while the local server runs.

Screen selector: Home, course/tees, live round, review, bag, social and stats. State selector: populated, empty, incomplete and error. Controls also rehearse dark appearance, larger text and reduced motion. Some routes deliberately remain composition-only (e.g. adding a player); they are not represented as real product features.

Initial browser review: Home/populated/light/default text rendered in Chrome. The symbolic terrain and resume action lead the screen; no repeated card grid, decorative gradient, serif masthead or borrowed room art is present. Additional browser combinations inspected: live/populated/light; live/populated/dark; live/error/dark/large text/Reduce Motion; review/incomplete/light; bag/empty/light. These checks confirmed the distinct compositions and exposed a sample club suggestion still showing during unavailable yardage, corrected to Selected club with an unavailable-suggestion label. The final fixtures use fictional Merri Links and Coastal Pines identities.

## Limits

At the initial browser-study milestone, Course in hand had not yet been native-rendered. See the later native iteration below. Browser typography scaling is not iOS Dynamic Type. Neither a browser accessibility tree nor native screenshot proves VoiceOver usability. Physical haptics, sunlight legibility, GPS precision, Watch/NFC behavior, motion performance and customer usability remain untested. No preference acceptance is implied by internal review.


## Final native verification

- Full integrated suite: **462 tests passed, 0 failures**, `xcodebuild test`, iPhone 17 Pro / iOS 26.3.1, parallel testing disabled. Final result: `/private/tmp/SwingPal-audit-build/Logs/Test/Test-SwingPal-2026.09.21_18-45-26-+1000.xcresult`. Log: `/private/tmp/SwingPal-audit-final.log`.
- New regression runs reproduced failures before repairs: four bag suggestion tests; Home/Stats metric assertions; current/unknown/stale course distance assertions; incomplete-round/archive/score aggregation; penalty and cumulative putt defaults.
- Independent patch review found cumulative putts being summed more than once; this was corrected before the final suite. The existing consecutive-putt regression passes.
- Final native Home accessibility output shows recorded scorecard copy, Distance unavailable for both bundled courses, and Apple Watch availability.
- New unavailable premium sheet: [light/default text](current/premium-unavailable-light.png). Initial dark/AX5 review exposed a fixed light background and short sheet; corrected to system background/foreground and a large detent at accessibility text sizes. [Final dark/AX5 capture](current/premium-unavailable-dark-AX5.png) shows readable reflowing content with visible Done action and scrollable body. The remainder of the app is not thereby certified accessible.
- The isolated simulator was returned to light appearance and standard Large text after inspection.
- Audit canvas compiled with TypeScript against the installed `cursor/canvas` SDK declarations, no errors. `git diff --check` passes.
- The native build retains preexisting concurrency/deprecation warnings; passing tests do not establish Swift 6 migration readiness.
- No commits, pushes, cloud writes or production deployments were performed.

## Native redesign iteration — 21 September 2026

This is **not a finalised or owner-accepted design**. The owner rejected the first native pass as prototype-like, blocky and disconnected, particularly the decorative miniature. `native-course-in-hand/home-empty-light.png` records that superseded pass. The HTML is historical preimplementation material, not the current native baseline.

The current Home uses supplied course geometry, selectable course identity and a hole preview. The selected course carries into setup; live play retains the geographic map and separate shot/score actions. Native tab navigation replaces the oversized custom dock. Named appearance colours and semantic typography replace the editorial treatment. Review exposes every hole and a real earlier-hole correction form. Supporting Profile, bag, Stats and Social have implementation changes, but their visual review is not yet as thorough as the core flow.

Actual renders and interaction checks on iPhone 17 Pro, iOS Simulator 26.3.1:

- [Home/course plan, light/default](native-course-in-hand/home-course-plan-light.png): real bundled Medway polygons, hole selection changes the readout/highlight; Set up round opens Medway.
- [Selected course/tees, light/default](native-course-in-hand/setup-selected-light.png): selected course leads, named tees and companion limitations remain visible.
- [Setup, dark/AX5](native-course-in-hand/setup-dark-AX5.png): course/source text reflows; artwork removed and footer scrolls at accessibility sizes.
- [Resume, dark/AX5](native-course-in-hand/home-resume-dark-AX5.png): sample active hole/confirmed count; Resume wraps without overflow and is reachable by native accessibility action. Native AX trees were inspected, not spoken VoiceOver usability.
- [Live, light/default](native-course-in-hand/live-sample-light.png): sample location, real bundled geometry, explicit distance source, separate shot/score actions.
- [Manual club catalog](native-course-in-hand/club-manual-light.png): Automatic suggestions toggle exposes complete manual catalog. Selection uses existing state methods and does not log a shot.
- [Missing GPS, dark/default](native-course-in-hand/live-unavailable-dark.png): live yardages unavailable, map identifies tee planning; manual scoring stays reachable.
- [Score form, dark/AX5](native-course-in-hand/score-dark-AX5.png): reached from unavailable-GPS live screen; labeled native steppers appear in AX output and the form scrolls.
- [Incomplete review, light/default](native-course-in-hand/review-incomplete-light.png): three confirmed holes/13 strokes followed by missing holes; all 18 records exposed.
- [Invalid earlier-hole edit](native-course-in-hand/review-invalid-edit-light.png): total 1 with existing 2 putts and a blank putt field correctly disables Save; existing putts cannot silently exceed the reduced score.
- [Completed review, dark/default](native-course-in-hand/review-complete-dark.png): 18 confirmed holes; completed-save wording remains distinct from Save draft.

Explicit opt-in native sample fixtures live under `#if DEBUG` in SwingPalApp.swift, selected with `SIMCTL_CHILD_SWINGPAL_DESIGN_REVIEW=home|live|live-unavailable|review|complete|stats` when launching via simctl. They use preview location/weather, no-op save callbacks and disabled authentication configuration; sample rounds do not enter persistence or social feeds. Project Debug now explicitly defines DEBUG; Release excludes these fixtures. Earlier live captures show the temporary sample banner at the top; it was subsequently moved to the bottom to keep navigation titles unobscured.

Validation: 465 XCTest cases pass after native behavior changes, including existing audit fixes and new correction/target regressions. Final review found and addressed AX Home action overflow, missing manual club-picker controls, blank-putt inconsistency and final-hole tee-reference mislabelling. Native build succeeds and diff whitespace validation passes.

Limits: this evidence covers the named iPhone/OS combinations only. Small phones/iPad, older supported iOS versions, spoken VoiceOver, physical haptics, Reduce Motion/Transparency settings, motion performance, outdoor readability, Watch and GPS accuracy still require review. Reduce Motion/Transparency adaptations are code paths, not claimed device validation. No usability preference or final design acceptance is implied. The supplied geometry's accuracy and the existing audit's persistence/sharing/backend gaps remain separate open concerns.

## Restoration after owner review

The owner rejected the inset-map/list-led live composition and crude club sketches. The standard live presentation now restores the full-screen map, floating phase-aware HUD, draggable tray, radial club selector and shot-outcome dial. AX/VoiceOver alternatives remain supplemental. Placeholder club drawings were removed from Profile/My bag and their implementation deleted. The earlier inset-map captures above are historical rejected iterations, not a final design baseline.

Tests that implicitly used the simulator's saved round and bag now inject existing test stores. Restoration validation runs on a separate `SwingPal Isolated Validation` simulator rather than the review device, preserving the user's active review data. No stored round or club is deleted as part of this restoration.

## First native playing composition — 21 September 2026

The owner authorised implementation of the new visual study. See the [native playing gallery](native-playing/README.md) for the actual map, joined yardages, equipment dock and club fan, with precise simulator evidence and remaining review limits. 467 tests pass; the whole-app redesign remains in progress.
