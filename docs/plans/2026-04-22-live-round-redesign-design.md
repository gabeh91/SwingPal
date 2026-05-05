# 2026-04-22 Live Round Redesign

## Goal

Rebuild `Live Round` around a calm, map-first shot cycle that supports real
mid-round use instead of a stacked control panel.

The redesign should reduce control clutter, make the hole map the permanent core
surface, and produce better structured shot data for later recap, coaching, and
social summaries.

## Product Thesis

`Live Round` should feel like a caddie instrument, not a GIS tool and not a
dashboard.

The golfer's loop should be:

1. See the hole
2. Choose or adjust the target
3. Mark the ball when useful
4. Log the shot quickly
5. Return immediately to the hole

Anything that does not support that loop should be visually recessive or hidden.

## Core UX Principles

- `Map-first`: the hole map is always the dominant surface
- `One primary action`: `Log Shot` is the main action during play
- `Bounded interaction`: map and targeting stay within real hole context
- `Context preserved`: shot logging lives in a bottom sheet, not a full-screen flow
- `Structured data, low friction`: shot quality is captured with fast tags, not a
  form
- `Intelligent prompting`: `At Ball` is suggested only when it makes sense

## Interaction Model

The screen should have three layers only:

- `Primary layer`
  - hole map
  - current target
  - player position
  - yardage
  - selected club
- `Action layer`
  - `Log Shot`
  - `At Ball` after the tee shot
  - target mode and `Recenter`
- `Utility layer`
  - quiet secondary controls such as extra details and hole completion

The current pattern of many equal-weight buttons should be removed.

## Map Model

The map is a `bounded tactical canvas`.

Each hole should expose a bounded playable envelope derived from:

- tee
- fairway corridor
- hazards
- green
- a small outer safety buffer

The user can pan and inspect, but only within that hole envelope. The map should
not drift into unrelated terrain.

## Targeting Model

The crosshair remains an explicit draggable control, but it must be constrained by
hole geometry.

Rules:

- the user drags the crosshair directly
- the crosshair cannot leave valid tactical zones
- in `Hole View`, the target moves within a fairway or landing corridor
- in `Green View`, the target moves within the green surface and close approach
  zone
- the target should feel tactically guided, not freely floating

This keeps targeting tactile while still grounded in the hole.

## Recenter

`Recenter` should always frame:

- the player
- the selected target

It is a quiet recovery control, not a primary action.

## Yardage and Context

The always-visible context should stay minimal:

- strong yardage number
- selected club
- weather strip
- hole number / par / stroke
- selected target label

All secondary context belongs behind disclosure or in a lighter utility layer.

## Shot Cycle

### Tee Shot

- no `At Ball` button required
- tee origin is assumed from hole context
- golfer chooses target and club
- golfer logs shot

### Later Shots

- `At Ball` becomes available
- it is optional but recommended
- if tapped, it records:
  - current location
  - heading
  - hole number
  - selected club
  - selected target
  - timestamp
- the UI should confirm the mark quietly and keep the golfer on the map

### Contextual Reminder Rule

The app should not prompt for `At Ball` immediately after a shot is logged.

Instead:

- the feature stays available
- it becomes visually suggested only when the golfer has plausibly moved to the
  next-shot position
- the reminder should depend on location change and hole context

## Shot Logger

`Log Shot` should open a bottom sheet over the live map.

The map stays visible behind the sheet so the golfer never feels like they left
the hole.

The logger should capture three distinct dimensions:

### Direction

- `Hit`
- `Left`
- `Far Left`
- `Right`
- `Far Right`

### Distance

- `On Number`
- `Long`
- `Short`

### Strike

- `Pure`
- `Thin`
- `Chunk`
- `Top`
- `Slice`
- `Hook`

This must not be flattened into one mixed list. Golfers think in separate
dimensions: line, distance, then strike quality.

## Shot Logger Context

The top of the sheet should show only:

- selected club
- origin status: `Tee`, `Ball Marked`, or `Current Location`
- distance to selected target
- current target label

Optional overrides such as lie correction or notes should be secondary and
collapsed by default.

## Data Captured Per Shot

Every shot should eventually support:

- club used
- origin coordinate
- origin source
  - `tee`
  - `ball_mark`
  - `current_location_fallback`
- selected target coordinate
- hole number
- direction result
- distance result
- strike result
- lie / surface
- timestamp

This is the minimum useful structure for recap and intelligence later.

## Visual Direction

The screen should stop reading as multiple boxed slabs.

Desired direction:

- one authored instrument language across top HUD, map annotations, and bottom
  action rail
- fewer containers
- less equal-weight chrome
- stronger visual priority on yardage and map state
- softer secondary surfaces
- no small-button toolbar feel

`Live Round` should feel like a single navigation instrument wrapped around the
map, not a set of unrelated cards laid over it.

## Known Critical Blocker

The current `Live Round` implementation has a parked critical bug:

- none of the visible controls respond to taps on device
- the view-level tap logs do not fire
- interaction appears to die before SwiftUI button closures run
- this should be treated as an interaction-plane / map-overlay architecture bug,
  not a styling issue

The redesign should not be layered on top of the current broken control stack
without first rebuilding the interaction architecture.

## Implementation Direction

The safest implementation strategy is:

1. stabilize interaction architecture
2. rebuild HUD hierarchy around the shot cycle
3. introduce bounded hole-map behavior
4. redesign shot logging as a structured bottom sheet
5. then re-polish the visual language

## Outcome

If implemented correctly, `Live Round` becomes:

- cleaner to glance at
- faster to use during real play
- more believable as a golf product
- far more valuable as a shot-data collection surface
