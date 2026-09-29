# Floating playing controls

22 September 2026 · Historical, rejected by the owner as boxy, primitive and unintuitive

The owner selected the [shot planner emphasis](../native-planner/README.md) after this revision. The evidence below records the rejected implementation.

[Compact resting](compact-resting.png) · [Compact open selector](compact-clubs.png) · [Compact after marking a ball](compact-marked.png) · [Compact GPS unavailable, dark](compact-unavailable-dark.png) · [Larger phone](large-resting.png) · [Largest accessibility text](unavailable-dark-AX5.png)

## Design decisions

The course remains the continuous surface. A compact yardage instrument and one equipment/action bar replace the full-width opaque header and lower slab. Score and recenter are separate floating actions. Ball marking appears when available. The club fan is bounded to 280 points rather than growing to the screen width; the selected sector has a fine outline and restrained tint. A warm neutral action button replaces the fluorescent block. Carry source and stroke appear once in the resting bar. The open selector replaces that information with Cancel and Use; preview does not log a shot.

Native material lets the surroundings affect the controls while maintaining dark, readable surfaces. Reduce Transparency uses an opaque equivalent, including beneath the status bar. Controls retain 44-point targets. The missing-GPS caption is informational; the yardage instrument opens conditions. No GPS state claims an unsupported tee origin.

The map uses flat aerial imagery and a wider tee-to-green frame, with additional room when the missing-GPS status is present. The whole hole clears the controls in the reviewed populated compact layout, including the open fan. The earlier tilted framing was unsuitable for the flat view. This is presentation framing; it does not alter the course geometry, recorded shots or distance calculations.

## Exact evidence

- iPhone SE (3rd generation), 375 × 667 points, iOS 26.3.1, Large text, light appearance: resting, five-sector selector, and one sample shot followed by Ball Marked. All primary controls fit without scrolling. Green, aiming point and tee remain visible in the open selector capture.
- Same compact device, dark appearance, Large text: unavailable GPS has absent live yardages, a reference-map label and manual shot entry.
- iPhone 17 Pro, iOS 26.3.1, Large text, light appearance: resting layout with actual MapKit imagery and fixture course geometry.
- iPhone 17 Pro, dark appearance, accessibility-extra-extra-extra-large: first viewport of the scrolling reading layout. This is only evidence of initial text reflow, not verification of every offscreen control.
- 467 XCTest tests passed with zero failures after the functional and fixture changes. A subsequent presentation-only adjustment adds camera clearance for the unavailable-GPS caption; its build and native render were checked separately.
- Source review caught inaccurate GPS provenance and an undersized informational action; both were corrected. The Ball Marked row was checked natively on the compact phone. Fan preview, cancellation and explicit selection retain the existing state methods and geometry tests.

All sample captures use DEBUG fixtures with fake location and no-op persistence callbacks. The fixture shell now uses an empty active-round store so it cannot resume a real saved round and start location behind a sample screen. The fixture footer is review-only.

## Limits

Computer-use automation failed to connect during this revision. Screens were launched in explicit fixture states; no new touch, radial-drag, VoiceOver focus/speech or physical haptic verification is claimed. Reduce Motion and Reduce Transparency received source inspection, not new physical-device review. No 320-point-width, landscape, XXL standard text or iPad render was captured. Map framing across other course geometries and device sizes still needs review.

The revised build is installed on SwingPal Design Audit without clearing its stores. The saved Medway round remains on Home. Resume was not activated during this handoff, and no score or shot was recorded there.

This is a concrete correction to the rejected playing screen, not acceptance of a finished app design. Home, bag, shot-entry presentation and other supporting destinations still require design development.
