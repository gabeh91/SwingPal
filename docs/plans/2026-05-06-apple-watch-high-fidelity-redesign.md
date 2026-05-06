# 2026-05-06 Apple Watch High-Fidelity Redesign

## Goal

Rebuild the Apple Watch live-round companion as a premium, watch-native extension
of the iPhone Live Round screen. The Watch should preserve the exact Live Round
action model and shot-logging taxonomy, while presenting it with a polished
two-page watch UI.

The current Watch implementation has the right feature intent, but it reads as a
prototype: boxy layout, generic material cards, cramped spacing, and simplified
actions that do not fully match the main Live Round flow. The redesign should
feel like a compact SwingPal golf instrument rather than a small dashboard.

## Product Direction

The Watch app remains a tactical companion, not a full replacement for the
iPhone. It should help the golfer glance, decide, and log without breaking the
round rhythm.

The interaction model has two pages:

1. Yardage preview instrument
2. Live Round launcher controls

Page one is for confidence at a glance. Page two is for action. Swiping between
them should feel like moving from read mode to control mode, not like navigating
a generic menu.

## Page One: Yardage Preview Instrument

The first page should combine a great course preview with clear yardage. The
preview is not a rounded card pasted onto the layout. It is the visual canvas:
full-bleed or near full-bleed, shaped by the watch face, color-treated for
readability, and integrated with the yardage typography.

The hierarchy is:

1. Course preview as the environmental foundation
2. Pin yardage as the hero metric
3. Front and back yardages as secondary markers
4. Selected club as a compact instrument label
5. Hole, par, score, and sync as quiet perimeter metadata

The yardage should sit directly over the preview, with strong contrast and
tabular numbers. Avoid putting the hero metric inside a card. Use subtle veils,
edge fades, and authored alignment instead of stacking panels. The result should
feel spacious, asymmetric, and premium on both 41mm and 45mm watches.

## Page Two: Watch Live Round Launcher

The second page must mirror the iPhone Live Round launcher capabilities and
taxonomy. It should not invent a separate simplified Watch action set.

Immediate launcher controls:

- Club
- Log Shot
- At Ball, when available

First-tier live actions:

- Undo last shot
- Quick penalty
- View green
- Quick finish hole

Expanded launcher actions:

- Inspect Holes
- Re-tee
- Shot History
- Conditions
- Edit Current Hole
- End Round

`Log Shot` is the dominant control. Other actions should be arranged with
watch-native ergonomics and differentiated scale, not as a uniform grid of equal
rounded rectangles. Use spacing, icon weight, typography, and subtle dividers to
group controls before adding visible containers.

## Shot Logger Parity

The Watch shot logger should preserve the iPhone logger model and adapt only the
presentation.

Supported contexts:

- Tee
- Shot
- Putt

Tee and shot logging should include:

- Club selection
- Inferred lie/surface
- Landing outcome dial
- Miss intensity: Normal / Far
- Provisional ball on tee context
- Detail path for penalties, drops, stroke number, strike quality, and note
  where feasible

The landing outcome dial mirrors the iPhone model:

- Center Hit
- Long
- Long right
- Right
- Short right
- Short
- Short left
- Left
- Long left

Putt logging should include:

- Holed / Missed
- Miss-location dial for missed putts
- Optional miss distance
- Detail path for putt count override, first putt distance, penalties, and note
  where feasible

Confirm actions should use the same verbs as iPhone:

- Log tee shot
- Log shot
- Hole out
- Log missed putt

## Visual Language

The Watch UI should follow SwingPal's live-round design principles:

- Premium but calm
- Preview and yardage first
- Fewer containers
- Strong hierarchy
- Natural pine, sand, mist, and restrained sun accents
- No generic dark sports-tech dashboard styling

The current thin-material card stack should be replaced by a purpose-built
instrument language. Use full-bleed imagery, soft readability overlays, precise
tabular metric typography, and tactile controls with clear scale differences.

Avoid:

- Uniform button grids
- Nested cards
- Boxy stacked panels
- Equal-weight controls
- Long explanatory text
- Rounded image cards on the primary glance screen

Prefer:

- Integrated preview canvas
- Large hero yardage
- Perimeter metadata
- Sculpted edge fades
- Compact chips only where they clarify state
- Haptics for action confirmation and sync stress

## Architecture And Data

Keep the iPhone as the source of truth. The Watch sends structured intents and
renders snapshots. It should not independently reimplement round rules.

The shared snapshot should expand beyond yardage and club to include the action
affordances the Watch needs:

- Can log shot
- Can mark ball
- Can inspect green
- Can undo
- Can quick finish
- Live hole vs inspection state
- Current shot logger context
- Pending surface
- Score, putts, penalties, and drops
- Launcher action availability
- Sync state and queued action count

The Watch action protocol should evolve from shortcuts into structured intents.
A Watch shot-log intent should carry the same data the iPhone logger captures:

- Club
- Surface
- Direction result
- Distance result
- Strike result
- Shot type
- Penalty count
- Drop count
- Putt detail
- Optional note where supported

Launcher intents should cover:

- Mark ball
- View green
- Quick penalty with specific type
- Re-tee
- Finish hole
- Undo
- Inspect holes
- Shot history
- Conditions
- Edit current hole
- End round

Some expanded launcher actions may open or request iPhone flows in v1, but the
Watch taxonomy should still match the iPhone.

## Trust States

Sync state should be quiet when healthy and explicit when degraded.

Connected:

- Tiny live indicator
- No banner
- Haptic confirmation after phone-confirmed critical actions

Syncing:

- Compact queued-action state on the control page
- Clear feedback when an action is queued

Disconnected:

- Show last known preview and yardage as stale
- Disable or queue critical actions with explicit feedback
- Never imply a shot was saved unless the phone confirms it or the action is
  visibly queued

## Testing And Verification

Unit tests should verify:

- iPhone publishes Watch launcher affordances from `LiveRoundState`
- Watch intents map to the same behavior as iPhone launcher actions
- Shot-log intents preserve direction, distance, strike, surface, shot type,
  penalties, drops, and putt detail
- Quick penalty options match the iPhone taxonomy
- Putt and non-putt logger contexts produce the correct model

View-model tests should verify:

- Page-one hierarchy and fallback copy
- Degraded sync copy
- Action availability
- Shot logger context
- Quick penalty labels
- Putt vs tee/shot presentation state

Manual verification should cover:

- 41mm and 45mm watch layouts
- Connected, syncing, and disconnected states
- No active round
- Live hole vs inspected hole
- Tee, fairway/rough/bunker, and green contexts
- Long club names
- No preview image fallback

## Implementation Strategy

1. Expand the shared snapshot and action protocol for Live Round parity.
2. Add tests for Watch affordances and structured intents.
3. Rebuild page one as the preview-yardage instrument.
4. Rebuild page two as the Watch Live Round launcher.
5. Replace the quick-shot screen with a context-aware Watch shot logger.
6. Add quick penalty, re-tee, finish, undo, and sync-state flows.
7. Verify 41mm and 45mm polish before considering the redesign complete.

