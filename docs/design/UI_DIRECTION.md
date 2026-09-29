# SwingPal — Course in hand

> **Superseded 28 September 2026** by [The yardage book](YARDAGE_BOOK.md) as the whole-app identity. The notes below are kept as history; the truthfulness, accessibility and data-honesty requirements still apply.

21 September 2026 · Native iteration in progress — not finalised or accepted

## Scope and provenance

This is SwingPal's own direction. The owner's supplied renovation-app excerpt is a reference for authored objects, purposeful depth, continuity and accessibility, not a source of literal colours, room metaphors, layouts or product behavior. No renovation gallery or competitor screens have been copied. The April editorial specifications remain historical context; they are not the baseline for this proposal.

[Interactive compositions](review/course-in-hand/index.html) · [Functionality audit](FUNCTIONALITY_AUDIT.md) · [Review evidence](review/README.md)

The HTML is historical preimplementation evidence. Native SwiftUI work is now present in the working tree. The owner found the first native pass prototype-like, blocky and disconnected; the symbolic course tile added no practical value. That pass is not an accepted baseline and must not be described as a final design.

The revision joins selection, actual course geometry and the next action into one course-led composition. Home previews supplied course polygons, highlights the inspected hole and opens setup for that selected course. Setup repeats the course identity at a smaller scale; live play uses the actual geographic map. This is still an iteration requiring owner review. Passing builds or internal visual checks do not establish design acceptance.

## Owner correction: develop the playing experience

The owner also rejected the second pass: the three club silhouettes looked crude, and replacing the full-screen live map, draggable instruments and radial club interaction with inset map panels and lists weakened the product. The club artwork has been removed from Profile and My bag. It is not an asset baseline.

The owner subsequently clarified that these are design ideas, not a hard layout contract. Substantial changes are welcome when they improve the result. The goal is bespoke composition, visual distinction and integrated interaction, not preservation of every old arrangement. Restoring the map and radial controls repairs regressions; it does not complete the redesign.

The [playing composition study](review/playing-study/README.md) explores a joined yardage display and lower equipment/action dock over an uninterrupted course map. Club selection opens from the dock into a shared radial surface. Its geometry and material are candidates, not accepted requirements. The images use illustrative course imagery and values; they are not native screenshots. The earlier HTML and native passes remain historical evidence.

Accessibility list/stepper alternatives supplement custom interactions at accessibility text sizes and with VoiceOver; they do not define the standard visual presentation. Retain the audit fixes, real review/correction routes and honest distance-source states. Stop extending the rejected flat treatment to other screens. Further visual work must improve the whole composition rather than merely style individual primitive controls.

## Shot planner — selected emphasis, 22 September

The owner rejected both the oversized opaque playing composition and its smaller floating-panel revision. The latter remained boxy, primitive and unintuitive. The [opaque gallery](review/native-playing/README.md) and [floating gallery](review/native-floating/README.md) are rejected historical evidence.

The owner selected a **precise shot planner**: the course and aiming interaction lead, with controls connected to the shot. This is agreement on emphasis, not approval of the finished screen.

The new native composition attaches centre/front/back readings to the actual green, names the two planning segments To aim and To green, and draws a dashed selected-club carry reference around the existing shot origin. It is not a landing prediction or a measured dispersion model. Choosing a club previews the circle; Use commits equipment and Cancel restores the previous choice. Log shot is a distinct action using the existing outcome logger.

The full-width panel stack and pie-sector fan are removed from this composition. Hole navigation occupies an unboxed top edge. A continuous lower surface holds the club identity, carry source, change-club affordance and shot action; its horizontal club sequence remains readable while the map shows the preview. Soft edge fades protect text where the map meets controls; they are functional legibility treatments. Reduce Transparency substitutes opaque edges and annotation backing. Larger standard text moves yardages into a scalable reading instrument, and accessibility sizes/VoiceOver retain the existing accessible flow.

Rationale: the interface should explain the shot through geographic relationships, not require the golfer to mentally connect independent dashboard panels. Information changes where its meaning changes. The green distance is distinct from the distance to the movable landing point; carry source remains explicit.

[Native planner renders and exact verification limits](review/native-planner/README.md) · [Implementation record](../plans/2026-09-22-shot-planner.md)

## Decision

Make the course context useful across the flow. A decorative miniature proved insufficient: Home currently presents a course plan derived from supplied geometry, a course selector and explicit hole inspection. This remains an unaccepted iteration. Live play needs an actual hole map, clear distance readout and reachable scoring actions. The review becomes a chronological account of holes played. Bag composition needs further design; the rejected club sketches are not its visual baseline.

The original compositions precede components. Home is an object with an action; setup is a selection workflow; live play is a map with an instrument; review is an editable score record; the bag is a distance-ordered inventory. They must not become the same rounded card repeated under different headings.

Three approaches considered:

- **Initial symbolic Course in hand — superseded.** The owner found the separate terrain object decorative and the native composition disconnected. Useful course context now replaces it.
- **Instrument-first throughout.** Distances, compact lists and native forms throughout the app. Excellent utility and low implementation risk, but less distinctive off the course. Its clarity informs the live-round screen.
- **Course photography as the identity.** Real photos make places recognisable, but depend on coverage and permissions and provide weak continuity into scoring. Use actual course photography as supporting evidence when available, not as a universal hero template.

## Composition by task

### Home

Compact SwingPal identity, then the selected or active course. Without an active round, a native course menu chooses among available courses and retains the route to full discovery. Previous/next controls inspect actual hole geometry within the full course plan; inspection never changes a score or the starting hole. Set up round opens the selected course. With an active round, the current hole and confirmed count come directly from LiveRoundState and Resume wins. If geometry is unavailable, say so rather than substituting an unrelated illustration.

A last-completed-round row contains date, holes completed and score, with persistence status where needed. No edition labels, slogan introduction, decorative performance gauges, or generic AI panel. Optional analysis is subordinate to the original record.

Rationale: golfers generally open the app to do something on a course; resume must win over self-promotion. The sample places the action within one phone viewport at standard text sizes. Accessibility text sizes allow vertical scrolling instead of shrinking the course name.

### Course discovery and setup

Start with search and saved-course rows. Ask for location only through an intentional nearby action. Distinguish saved courses from courses measured near the player. Unknown distance is text, never zero or a seeded number. Preserve search text, selected course and tee choice through retry and navigation back.

After selection, collapse course discovery behind Change course and show the same supplied course plan in a compact identity area. Tee controls use names and total distances in the selected unit; colour is secondary. Player rows state whether scoring is actually supported. Missing geometry, provisional import status and sources remain visible before Start round. Do not call AI-reviewed data verified.

Rationale: the course object carries identity, but the form gets the space. No compulsory large illustration above every field. The current prototype's player dialog is a composition-only sketch; multiplayer behavior is not claimed as implemented.

### Live round

The current implementation follows the shot planner above. Course, hole and par establish context at the top edge. Green centre/front/back readings attach to the green, with a fine geographic leader. Keep Green centre until an actual pin location is supplied. Moving the target changes the two explicitly named shot segments. The selected club’s range is a dashed reference circle, qualified by bag/estimated carry. Missing GPS removes live yardages and the circle while preserving reference planning and manual scoring.

The lower surface presents equipment and shot recording as separate actions. Change club opens the horizontal sequence; tapping previews, Use commits and Cancel restores. The legacy fan is not the active visual baseline. Native club settings retain Auto/Manual and the full catalog. A club choice never records a stroke. Score, ball marking, recenter, conditions, inspection, review, corrections and the existing outcome dial remain available. Inspection cannot record on another hole.

Larger standard text places scalable yardages before the scrollable map. Accessibility text sizes and VoiceOver retain the readable controls. Map annotation placement after arbitrary pans, all course geometries, physical dragging, outdoor contrast and performance still need device validation.

### Hole score and round review

Hole score uses labelled native steppers/number fields for strokes, putts and penalties, with clear counting semantics. Corrections update the recorded round and its derived totals. Review shows all holes, missing entries and actual confirmation state. The prototype displays only the final three illustrative rows; native implementation must expose the complete record.

Save draft retains incomplete work and a resumable snapshot. Save round requires genuinely completed entries. Unknown is an em dash or Missing, never zero. A local save, cloud sync and sharing are three distinct outcomes. Confirmation follows persistence, not a tap or animation. Guest names alone do not mean guest scores have been tracked or attested.

Rationale: the saved round is the product's record of truth. A beautiful summary cannot compensate for discarded detail or silently fabricated completion.

### Bag and profile

Develop the bag as a useful equipment composition. Do not repeat the rejected decorative club silhouettes or assume a plain list completes the design. Distances have units and sources. Editing a carry retains accessible inputs; clubs without carry remain available for manual logging. Do not silently assign branded starter clubs as the user's equipment. Profile contains identity, settings, appearance, units, account and the route to the bag.

Rationale: distinguish recognition of the equipment from the editable record. Artwork does not need to be repeated inside club forms. The study's Profile tab opens Bag as a shortcut; the native navigation must retain a real profile destination.

### Stats and social

Stats leads with one observation grounded in a stated sample: comparable completed rounds, recorded putts, scores or penalties. Show sample size and hole count. Partial-round totals do not form a full-round trend. Aggregate penalty totals are not off-tee or driving analysis. Preserve recorded facts when optional AI is unavailable, and identify provider/source.

Social uses people and actual shared rounds, not empty activity counters or a lifestyle masthead. Separate a failed feed from a genuinely empty circle. Saving is private by default in the proposed behavior; explicit sharing requires its own persistence and UI work because current code automatically sets `is_shared`.

### Watch and premium

Watch stays a focused glance-and-action surface: hole, distance, club, quick shot and hole completion. Show disconnected, stale and queued states, then acknowledge confirmed changes. Physical pairing, offline replay and duplicate handling need device validation.

Premium describes only available capabilities. Until StoreKit products, purchase verification, restore and entitlement loss are implemented, show an honest unavailable state. Never grant premium through a presentation callback or fabricate an offer. The study does not include an invented paywall.

## Authored material

The design study contains an original inline SVG terrain cutaway: projected slab, fairway, green, bunkers, tree silhouettes and flag. It also contains code-drawn club silhouettes. No raster assets, downloaded art, external fonts, gradients or model dependencies are required.

Native `CourseHolePlan` in `ShellTokens.swift` projects supplied course polygons, scales longitude by latitude and fits the full course to available space. The inspected hole remains strong while surrounding holes provide context. The plan may rotate to fit; a north reference is drawn. It invents no new fairways, pins or distances. Empty geometry has an explicit unavailable state. The rejected `CourseClubArtwork` sketches have been removed. The symbolic terrain implementation was removed after the first native review.

Hide decorative artwork from accessibility. Adjacent course identity and labelled actions carry its useful meaning. All artwork must survive removal without loss of function.

## Colour and type

These are SwingPal-specific candidate values, not copied renovation-app tokens. Validate final native contrast and material combinations before acceptance.

- Ground: cool mist `#EEF3F2` in light; deep blue-green `#101F22` in dark. No paper texture.
- Surface: `#FFFFFF` / `#1C3033`. Opaque working controls and readable map readouts.
- Primary text: `#142E30` / `#EDF5F2`. Supporting text: `#50696A` / `#B1C7C4`.
- Action: `#14665B` / `#A0DBC8`; paired action text `#FFFFFF` / `#10332D`.
- Unresolved/error: `#9B3924` / `#FFB39B`, always paired with an explicit label or symbol.
- Terrain uses grass, soil and sand colours only within the illustration; the pale flag colour is not a general purpose UI highlight.

Use system sans-serif text styles. Rounded/tabular figures can distinguish distances and scores without serif display headings. No fixed-size microcopy in native working controls; use semantic text styles and scaling. Preserve course/player/source names as entered. Do not uppercase normal content automatically.

## Motion and accessibility contract

- Retain familiar native tab navigation and navigation stacks. The current app has Home, Social, Round, Stats and Profile; do not hide destinations inside an unconventional spatial menu.
- A native source/destination transition may connect the course object and its detail. Ordinary navigation under Reduce Motion. Artwork settles once when entering, never spins or pulses forever.
- If a compact course identity follows scroll, use actual scroll geometry, bounded movement and no timer. Remove displacement, tilt and scale under Reduce Motion. Do not pin decorative context at accessibility sizes.
- Reflow front/centre/back readings, tee options and paired metrics into a vertical structure at large text sizes. Do not shrink critical numbers to preserve a composition.
- Provide named buttons, selected traits, input labels and errors. Minimum 44-point interaction targets. A screen-reader user must complete start, score, correction and save without interpreting the map or dragging a custom wheel.
- Use text and shape as well as colour for selected tees, pending scores, source quality and connection states. Preserve focus after recording a shot and announce a save result once.
- Use opaque semantic surfaces under Reduce Transparency. Material is appropriate for floating map controls only after native contrast review.
- Haptics follow meaningful selection and successful persistence; motion never blocks saving. Review haptic feel and outdoor readability on a physical device.

Apple references consulted: [Dynamic Type](https://developer.apple.com/videos/play/wwdc2024/10074/), [motion](https://developer.apple.com/design/human-interface-guidelines/motion), [zoom navigation](https://developer.apple.com/documentation/swiftui/zoomnavigationtransition). These inform platform behavior, not the authored composition.

## Components to extract after screen review

Start with the Home → setup → live → score → review compositions. Then extract only repeated needs: `CourseIdentity`, `CourseHolePlan`, `DistanceInstrument`, `DataSourceLabel`, `RoundPersistenceStatus`, `HoleScoreRow`, `ClubDistanceRow` and native action/form styles. Avoid an all-purpose hero-card system. Keep domain calculations and persistence outside view components.

## Review gates

For each milestone review populated, empty, incomplete and failed states with actual native data fixtures. At minimum render a compact iPhone and a current large iPhone; default and accessibility text sizes; light/dark; Reduce Motion; Reduce Transparency. Review the same round across restart, location denial, interrupted import, score correction and sync failure. Record device, OS, fixture, appearance and text size for every capture.

1. Home/setup: truthful first-use data; no location dependence for search; selection retained.
2. Live/score: accurate target labels; stable readable controls; offline manual scoring; correct undo/counting.
3. Review/history: complete hole record; draft retention; confirmation after persistence; explicit sharing.
4. Secondary flows: profile/account isolation, real stats provenance, connection/error states and purchase truth.

The browser text toggle is a layout rehearsal, not Dynamic Type certification. Native screenshots and builds do not establish full VoiceOver support, usability validation or physical performance. Record the evidence honestly in [the review log](review/README.md).
