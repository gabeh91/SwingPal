# Shot planner — native revision

22 September 2026 · The owner selected the shot-planning emphasis; these renders are not claimed as design acceptance.

[Compact resting](compact-resting.png) · [Club preview](compact-clubs.png) · [Post-shot / marked ball](compact-marked.png) · [Larger phone](large-resting.png) · [GPS unavailable in dark appearance](unavailable-dark.png) · [XXL text, dark](large-XXL-dark.png)

## Composition and rationale

The map owns the shot information. A green-centre readout with front/back distances is attached to the actual green by a short leader. The two map segments read To aim and To green. A dashed circle shows the selected club’s carry around the existing shot origin; this is a distance reference, not a predicted landing area or measured dispersion.

The oversized fan and enclosing header/action cards are removed from the active composition. Hole navigation sits at the top edge. Equipment, carry provenance and the explicit Log shot action share a continuous lower surface. Change club opens a horizontally browsable sequence. Taps preview the carry circle; Use commits through the existing state method, and Cancel restores the previous choice. Previewing does not record a stroke. The existing outcome dial, scoring, review, corrections, ball marking and conditions remain reachable.

The map-edge fades protect legibility without outlining another panel. They are removed under Reduce Transparency, which also supplies opaque annotation backing. The club sequence has readable enabled-state contrast, rather than treating unselected choices as disabled. Large standard text moves yardages into the existing scalable reading instrument. Accessibility sizes and VoiceOver retain their readable alternative flow. Reduce Motion disables target scaling and animated presentation.

## Native evidence

- iPhone SE (3rd generation), 375 × 667 points, iOS 26.3.1, light appearance, Large text: resting, selected PW preview and one sample shot followed by Ball Marked. The green, aim and tee remain visible. Main controls fit without scrolling.
- iPhone 17 Pro, iOS 26.3.1, light appearance, Large text: populated map and attached yardage.
- Same larger phone, dark appearance, Large text: unavailable GPS removes live yardages and the selected-carry circle. Reference planning and manual scoring remain.
- Same larger phone, dark appearance, XXL standard text: scalable front/centre/back values precede the scrollable map. Capture shows the initial viewport; lower controls require scrolling. Map annotations become a simple green flag so fixed marker text is not the only distance readout.
- 467 XCTest tests passed with zero failures on the final build. An initial architectural typography test caught direct rounded-font use; numeral treatment was moved into the existing shared typography system, and the complete suite passed afterward.
- Source review checked preview/commit/cancel boundaries, scoring and inspected-hole routes. It prompted corrections to secondary text contrast, long club labels, Dynamic Type, Reduce Transparency and the obsolete colored range-ring legend.

Final compact resting, club preview and larger resting captures use the final build. Post-shot, unavailable and XXL captures precede the final secondary-caption contrast increase and Reduce Motion scale removal; their layout and state paths are otherwise unchanged.

All captures use opt-in DEBUG fixtures with sample data, no-op persistence callbacks and a fake location provider. The review footer is not part of the ordinary app. PW in this fixture demonstrates estimated carry, because the manual catalog abbreviation does not match its long-form bag name; that separate normalization issue is recorded in the functionality audit.

## Limits and handoff

Computer-use automation could not connect (native pipe startup failure). These are native fixture-state renders, not a new end-to-end touch test. No claim is made of physical dragging, outdoor contrast, VoiceOver speech/focus, haptic feel, all course geometries, landscape or iPad validation. Reduce Transparency and Reduce Motion received source review; they were not natively exercised in this pass. Largest accessibility text was reviewed in the prior revision, not re-rendered here. Geographic labels may move outside the viewport during arbitrary map pans; recenter restores the course view.

The final app is installed on SwingPal Design Audit without clearing data. Home still shows the saved Medway round and Resume round. No shot, score or course edit was made in that saved round during handoff. Open Resume round to review the new composition.

Home, bag and supporting destinations are still separate unfinished design work. The selected emphasis is a design decision; neither internal renders nor passing tests establish owner acceptance or user validation.
