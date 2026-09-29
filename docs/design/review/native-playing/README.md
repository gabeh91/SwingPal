# Native playing composition

21 September 2026 · Historical, rejected by the owner on 22 September

The oversized opaque instruments covered the map and did not work on compact phones. See the [replacement revision](../native-floating/README.md). The descriptions below record the earlier implementation, not current acceptance.

[Resting live round](live-light.png) · [Club preview](club-preview-light.png) · [Compact selection](compact-selected-light.png) · [Unavailable GPS, dark](gps-unavailable-dark.png) · [Unavailable GPS, largest accessibility text](gps-unavailable-dark-AX5.png)

## What changed

The native playing screen now uses a joined yardage display and equipment/action dock over the live MapKit course. A half-circle fan grows from the dock, with a shared material, fine sector boundaries, scale marks and an explicit selected sector. Club labels come from real entries; familiar wedge abbreviations replace truncated names. Full names and carry provenance remain available in the central readout and accessibility labels.

Taps and radial drags preview equipment. Use club commits through the existing validated state method; Cancel restores the original selection. Neither records a shot. The existing outcome dial remains in shot entry. Hole scoring, round review, inspection, undo, penalties, ball marking, conditions and GPS remain accessible from labelled controls. Map planning labels now respect the selected distance unit.

This implements the study's composition with actual course geometry and state. No generated aerial photograph or sample figure from the study is bundled. The map controls deliberately use opaque dark surfaces in both appearances for stable contrast; reduced transparency needs no material substitution. The fan uses restrained entrance motion, removed under Reduce Motion. Short viewports and XXL standard text use a scrolling version of the custom controls; accessibility sizes and VoiceOver retain readable native alternatives.

## Native checks

- iPhone 17 Pro simulator, iOS 26.3.1, default Large text: populated live state in light appearance; fan preview; Cancel restores Driver after previewing 7 Iron; stroke count remains 1.
- iPhone SE (3rd generation) simulator, iOS 26.3.1, default Large text: compact scrolling composition; preview and Use 7i; selected carry becomes 140m; stroke count remains 1. Log shot opens the existing outcome dial with 7 Iron. Selecting Hit and confirming records one sample shot, advances the display to Stroke 2 and exposes At Ball. Hole score opens correctly. All records are isolated DEBUG fixture data.
- iPhone 17 Pro simulator, iOS 26.3.1, dark appearance: location denied shows unavailable yardages, manual scoring and explicit tee-based map planning.
- Same phone, dark appearance, accessibility-extra-extra-extra-large: readings reflow vertically; Hole score remains reachable through the accessibility tree and opens the native score form.
- 467 XCTest tests passed with zero failures. Two new tests cover fan windows at both catalog edges and radial hit testing, including centre/outside rejection. They failed against the unimplemented helpers before implementation.
- Independent source review found and prompted correction of wrong-hole editor routing, an inferred distance labelled as a putt, inconsistent fan dimensions, feedback omitted from the short layout and dismissal handlers attached to a disappearing subtree.

The compact screenshot shows a scrolled position. A final viewport clipping adjustment is included in the handoff build; the earlier compact capture predates that adjustment. Native drag/scroll automation did not reliably reproduce touch scrolling, so this is not a physical-gesture validation. Source checks and native rendering, rather than screenshot assertions, validate visual changes.

## Limits and remaining review

Screenshots and accessibility-tree actions do not establish full VoiceOver speech/focus behavior, physical haptic feel, outdoor legibility or device performance. Reduce Motion and Reduce Transparency paths received source review; no claim of a complete device matrix is made. iPad and landscape have bounded geometry/scrolling accommodations but were not rendered in this milestone.

One background Simulator launch omitted MapKit annotation views until a foreground relaunch; foreground captures contain them. First-frame annotation rendering should be included in physical-device review. The existing tee-biased camera can still place the green close to or beneath the new header on some saved rounds; framing against the occupied control area needs further tuning. The app's existing location/planning engine and full shot-entry visual design were not rebuilt in this pass.

Current scope is the playing composition. Supporting screens remain unfinished design work; passing tests does not establish design acceptance.

The final build was installed on SwingPal Design Audit without clearing its stores. Home retained the saved Medway round, and Resume opened the new playing composition. No shot or score was recorded on that device during handoff.
