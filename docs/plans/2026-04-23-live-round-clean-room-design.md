# 2026-04-23 Live Round Clean-Room Design

## Goal

Rebuild `Live Round` from a clean foundation around a `map-first`, mid-round
workflow that is trustworthy, calm, and fast to use during real play.

This design replaces the previous live-round direction where the interaction
stack became too brittle and visually too boxy. The new design assumes the
fresh working screen is the baseline and all richer UX is layered on top of
that clean interaction foundation.

## Product Thesis

`Live Round` should feel like a premium golf instrument:

- the current hole map is always the primary surface
- the golfer always faces `forward` down the hole
- the user can quickly make a decision, hit the shot, and log the result
- the UI should support real play, not perform like a dashboard or admin panel

The dominant loop is:

1. Read the hole
2. Adjust target on the map
3. Optionally mark the ball
4. Log the shot
5. Continue play
6. Confirm the hole before advancing

## Non-Negotiables

- `Satellite-first map`
  - the live view must use realistic satellite imagery by default so bunkers,
    tree lines, water, and other dangers are immediately legible
- `Forward-facing hole context`
  - the current hole should orient visually in the direction of play
- `Hole geofence`
  - pan and zoom are allowed, but the user cannot leave the confines of the
    current hole boundary
- `Free drag targeting`
  - the crosshair is dragged directly in the map plane and is only bounded by
    the current hole geofence
- `Live tactical distances`
  - while the crosshair moves, the app updates both:
    - distance to target
    - remaining distance to hole
- `Shared phone/watch state`
  - there must be no meaningful drift between phone and watch state

## Phone Layout

The phone screen has three permanent layers:

### 1. Top Strip

The top strip is always visible and uses a soft premium glass treatment.

It contains:

- left arrow
- current hole number and par
- right arrow
- current stroke
- wind summary
- front / pin / back distances, all visible at once

The hole arrows are for inspection. Users can inspect previous or future holes,
but they may only log live shots and live scoring on the active current hole.

### 2. Map Surface

The map is the core surface and should remain dominant at all times.

It contains:

- current player position
- current target crosshair
- striped route from origin to target to hole
- geofenced pan/zoom behavior
- a small floating `Recenter` button, styled like a conventional map arrow in a
  circle

The `Recenter` action frames `player + selected target`.

The crosshair is a direct map interaction, not a HUD button. It should disappear
entirely when the user inspects any hole other than the active current hole.

### 3. Bottom Live Sheet

The bottom surface is a draggable live sheet with soft premium glass styling.

It is a `launcher surface`, not a dense working surface.

States:

- `Collapsed`
  - `Log Shot`
  - `At My Ball`
  - immediate access to current club
- `Expanded`
  - invokers for richer flows such as:
    - `Finish Hole`
    - score inspection
    - round context
    - deeper utilities

No actions are completed inside this live sheet beyond simple launch behavior.
Tapping items should open their own dedicated overlay or bottom sheet.

## Action Hierarchy

### Primary Action

`Log Shot` is the dominant CTA.

Without logging, there is no trustworthy round state or analytics. The UI should
make this obvious.

### Secondary Action

`At My Ball` sits beside `Log Shot` as an explicit button. It should not be
hidden in a menu and should not require a gesture.

Rules:

- tee shots do not require ball marking
- later shots may use `At My Ball`
- it records the real shot origin for recap and analysis

### Club Access

The current club must be visible even in the collapsed live sheet.

Tapping it opens a radial selector anchored near the control, not centered on
screen.

## Club Wheel

The club selector should behave like a thumb-friendly radial wheel inspired by
game inventory wheels, but adapted for golf and iOS.

Rules:

- anchored near the club control
- map remains visible behind it
- release-to-select interaction
- only clubs from the user’s actual bag are shown

Wheel center content:

- club name
- user’s average carry
- fallback to a reasonable amateur baseline when personal data is insufficient

The logger must still allow manual override of `club used`. Live club selection
should prefill the logger, not lock it.

## Modal Flows

### Shot Logger

`Log Shot` opens a bottom sheet over the map.

After confirmation:

- the sheet dismisses immediately
- a small top toast appears: `Shot Logged`

The shot logger supports a persistent mode preference from Profile:

- `Basic`
- `Advanced`
- `Follow user preference` on entry, but allow switching mid-round

#### Basic Mode

Basic mode should capture the minimum useful live-round data:

- direction result
- distance result
- number of strokes at that point
- penalties / drops
- club used

#### Advanced Mode

Advanced mode adds richer analytic detail without requiring the user to manually
enter values the app already knows.

Useful advanced additions:

- lie / surface
- shot type
- strike quality / shape
- putt details
  - number of putts
  - first putt distance
  - second putt distance when relevant
- optional note

Derived values such as shot origin, target, carry context, and live club
selection should be suggested automatically but remain editable where needed.

### Hole Confirmation

`Finish Hole` lives in the expanded live sheet and opens a dedicated
confirmation bottom sheet.

That confirmation step is required before advancing.

It summarizes:

- score
- putts
- penalties / drops
- shot outcomes
- club corrections
- notes

Users can edit the hole-level summary there before moving on.

### Inspection Mode

When navigating to another hole via the top arrows, the user enters
`inspection mode`.

Characteristics:

- same map surface
- no live crosshair
- no live shot flow
- only review/edit actions

Allowed edits:

- score
- putts
- penalties / drops
- tee-shot / shot outcome summary
- club-used corrections
- notes

If a previously confirmed hole is edited, the round data must store a persistent
`edited after confirmation` flag for that hole.

## Visual Direction

The live-round visual tone should be `soft premium glass` over satellite
imagery, and it must respect the app-wide Profile appearance setting:

- `Light`
- `Dark`
- `Follow System`

This should not become heavy translucent cards stacked over the map. The desired
qualities are:

- blurred and refined, not opaque
- rounded and quiet
- strong readability outdoors
- consistent glass treatment across:
  - top strip
  - live sheet
  - shot logger
  - confirmation sheet
  - inspection flows

## Apple Watch Companion

The watch is a real tactical companion, not a delayed mirror.

Watch priorities:

- yardage first
- quick shot logging
- club selection

The watch should expose a slimmer version of the same round model and update the
phone immediately. Any of the following must stay in sync:

- current club
- shot logs
- ball marks
- hole advancement
- hole edits

If the devices disagree, the round loses trust.

## State and Data Rules

The phone and watch must operate on one shared round session.

Important rules:

- live shot actions only apply to the active current hole
- future holes may be inspected but not scored as if they were active
- post-confirm edits are auditable
- logger defaults should come from current live state but remain editable

This design intentionally favors:

- low-friction live play
- clear auditability
- strong recap/analytics value later

## Implementation Direction

Implementation should proceed in this order:

1. keep `FreshLiveRoundScreen` as the active live entry point
2. add the top strip and draggable live sheet structure
3. implement geofenced map movement and crosshair bounds
4. build the radial club wheel
5. build the `Basic` / `Advanced` shot logger
6. build inspection mode and confirmation flow
7. wire phone/watch synchronization against one shared round session
8. apply final premium glass polish and motion

## Outcome

If implemented correctly, `Live Round` becomes:

- tactically useful during play
- visually calmer and more premium
- easier to trust
- more valuable for recap, coaching, and analytics
- consistent across phone and watch without state drift
