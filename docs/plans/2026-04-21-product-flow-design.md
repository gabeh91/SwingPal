# SwingPal Product Flow Design

## Product Thesis

SwingPal is a premium-feeling golf companion that makes each round calmer, smarter,
and more enjoyable. The experience should be beautiful first and intelligent second:
smart features should appear at the moment they help, without overwhelming the user.

## Experience Principles

- The UI should feel deliberate, polished, and spacious rather than data-dense.
- Core round utility must remain free so new users can form a habit before paying.
- Intelligence should be transparent and explainable in free mode.
- Premium should unlock deeper assistance, not basic usefulness.
- Guests should be able to browse and explore before authentication.

## App Shell

The primary navigation model is:

- `Home`
- `Social`
- `Round`
- `Profile`

`Round` is the emphasized center tab and the product heartbeat.

### Home

`Home` is the personal command center. It should answer:

- How am I playing?
- What should I do next?
- What changed since my last round?

Priority order on the screen:

1. Resume or start round
2. AI insights
3. Recent rounds
4. Nearby courses

`Home` should not become a generic feature dump. Everything here must be about the
user's own golf, not general discovery.

### Social

`Social` is a focused v1 surface for friends and round updates:

- Friend round posts
- Score summaries
- Milestones
- Lightweight reactions and comparison hooks later

It is intentionally not a broad public community feed in v1.

### Round

`Round` owns the operational golf flow:

1. Nearby course selection
2. Course detail and tee selection
3. Player selection
4. Live round play
5. Review and attestation

### Profile

`Profile` owns:

- Account
- Settings
- Bag
- Personal stats
- Premium state

`Bag` lives under `Profile`, not as a top-level tab.

## Access Model

Guests can browse and enter the round funnel without signing in.

Authentication is required when the user crosses into stateful or social behavior:

- Saving persistent profile data
- Posting or interacting socially
- Syncing bag/profile data
- Multi-device continuity

This keeps first-use friction low while still protecting the parts of the product
that depend on identity.

## Free vs Premium

### Free Core

Free users should be able to:

- Browse nearby courses
- Start and complete rounds
- View the live hole map and HUD
- Use basic GPS yardages
- Manage a bag
- Add guest players
- Track scores and attest rounds
- Save and revisit round history

### Free Intelligence

Free users should still feel meaningful smartness:

- `Plays-like` yardage
- Bag-based club recommendation
- Basic round insights such as FIR/GIR trends, strokes dropped vs prior rounds,
  strongest and weakest holes, and simple club usage summaries

Free intelligence should explain itself. Example:

`Suggested club: 7i`
`Reason: your 7i average is 158m and this shot plays like 160m`

### Premium Intelligence

Premium should unlock deeper assistance:

- Apple Watch live round companion
- Motion and swing analysis
- Projected landing or search corridor
- Richer club intelligence and caddie-style guidance
- Advanced post-round analytics
- Shot playback with coaching overlays

Monetization line:

- Free = play and record your round
- Premium = play smarter and analyze deeper

## Round Setup Flow

The round setup flow should be:

1. `Nearby courses`
2. `Course detail`
3. `Player selection`
4. `Start round`

### Nearby Courses

- Sorted by distance ascending
- Closest course pinned to the top of the list
- Strong location context
- List-first layout with map toggle rather than always-on map

### Course Detail

- Course overview
- Tee sets
- Yardages
- Par and hole count
- Primary CTA to continue to player selection

### Player Selection

- Signed-in user shown first
- Add lightweight guest players
- Guest players need round identity and scoring state
- Guests support end-of-round attestation, even without full accounts

## Live Round Design

The live round should be map-first.

### Default Screen

- Center: aerial view of the current hole
- Edge HUD: yardage, selected club, wind/elevation context, hole info
- Primary actions: log shot, change club, move target, switch target view,
  score hole, finish hole

This should feel calm and high-confidence, not cluttered.

### Watch Role

Apple Watch should act as a slim companion to the live round rather than a full
replacement UI:

- Next-shot yardage
- Current hole context
- Quick shot logging
- Fast access to selected club and target info

## AI Surfaces

There are two intelligence modes:

### Default Insights

Always-on and factual:

- Round trends
- Distance deltas vs prior rounds
- FIR/GIR patterns
- Club usage summaries

### Coaching Mode

Optional and more opinionated:

- Shot playback analysis
- Club usage advice
- Swing pattern commentary
- Suggested areas to improve next

Users should explicitly opt in to coaching mode.

## Visual System

SwingPal should avoid the typical sports-tech look of dark backgrounds, neon accents,
and overly dense dashboards. The visual language should feel like a premium outdoor
product crossed with an editorial tool.

### Palette Direction

Use a bright, natural palette built around:

- deep pine
- sand
- stone
- mist
- restrained sunlit gold for accents

The app should feel bright and natural by default rather than aggressive or
futuristic.

### Typography

- Use an expressive display face for key headings and major score moments
- Pair it with a highly legible sans-serif for functional UI
- Maintain strong hierarchy with short, confident copy

### Card and Surface Language

- Soft rounding
- Layered surfaces
- Generous padding
- Occasional restrained translucency where it improves depth

Intelligence surfaces should look like polished insight panels, not chat bubbles or
novelty AI widgets.

### Motion

Motion should communicate calm precision:

- shared-element transitions from course cards into detail screens
- smooth map and HUD state changes
- subtle confirmation transitions after shot logging

The aim is premium confidence, not spectacle.

## Auth Model

The preferred cloud auth provider for v1 is Supabase Auth.

### Supported Sign-In Methods

- Sign in with Apple
- Continue with Google
- Email magic link
- Guest mode

These methods should coexist so users are not forced into one identity model.

### Biometric Authentication

Biometrics are for local convenience, not cloud identity.

After successful authentication, the app should offer:

- Face ID
- Touch ID where available

This should be used to unlock the locally stored session, not replace the underlying
cloud auth account.

### Gating Strategy

- Guest use is valid and first-class
- Auth prompts should be soft and dismissible at first
- Hard gating should happen only when the user confirms a stateful action

Examples of hard-gated actions:

- saving rounds to the cloud
- syncing profile or bag data
- posting socially
- restoring on another device

## Onboarding and First-Run

The first-run experience should be polished and low-friction.

### Opening Experience

- A lightweight intro sequence with two or three strong value panels is acceptable
- It must remain skippable
- The first meaningful choice should be `Continue as Guest` or `Sign In`

Guest must be presented as a legitimate path, not a hidden fallback.

### Permission Timing

Permissions should be requested only in context:

- location when entering course discovery or round setup
- notifications only when there is a clear benefit such as reminders or updates

### AI Opt-In

Basic factual insights can be present by default, but deeper coaching should require
explicit user opt-in.

### Auth Conversion

The first strong auth gate should appear only when the user attempts to:

- save
- sync
- post
- personalize persistent data

The auth surface should clearly explain what the user gains by continuing.

## Data Model and App Architecture

The system should be organized around a shared golf activity model with
`RoundSession` at the center.

### Core Domain Objects

#### User

A `User` owns:

- profile data
- bag configuration
- preferences
- saved rounds
- premium and entitlement state

#### Bag and Club

`Bag` contains `Club` entries with user-defined baseline data such as:

- club name
- club type
- loft where useful
- typical distance
- optional confidence notes

This supports explainable club recommendations without pretending to infer more than
the system knows.

#### RoundSession

`RoundSession` is the primary play object and should link:

- selected `Course`
- selected `TeeSet`
- `RoundPlayer` participants
- a sequence of `HoleSession`s

#### RoundPlayer

`RoundPlayer` must support both:

- authenticated users
- lightweight guest players

The model should stay unified so score entry, attestation, display, and social
summary logic do not split into separate implementations.

#### HoleSession

Each `HoleSession` should contain:

- current target state
- strokes
- score state
- shot sequence
- hole summary state

#### ShotEvent

`ShotEvent` should be flexible enough to support:

- manual logging
- iPhone-derived context
- Apple Watch sensor context
- later external launch monitor data

The product should not need a new model every time a new data source is added.

### App State Domains

State should be separated into a few durable product domains:

- `Auth`
- `Home`
- `Round`
- `Social`
- `Profile`
- `Entitlements`

### Shared Round Core

`Round` needs the strongest internal design because it must support both iPhone and
Apple Watch surfaces. The best approach is a shared round-state core with thin
device-specific presentation layers built on top.

### Entitlements and Intelligence

Premium gating should live in a dedicated entitlement layer rather than being
scattered through individual screens.

Intelligence features should read from normalized round, player, and shot data rather
than being embedded into view-specific logic.

## Round Scoring, Attestation, and Social Output

Scoring should remain lightweight during play and trustworthy at round completion.

### In-Round Scoring

- score entry stays secondary to the map-first live round experience
- hole score should be confirmable through a compact sheet or end-of-hole card
- each player needs an easy-to-scan per-hole scoring state
- the golfer should never feel like they are filling in a spreadsheet mid-round

### Attestation

Attestation should be a dedicated `Review & Attest` step after the round.

The screen should:

- show one unified scorecard
- make discrepancies easy to scan
- mark players as confirmed, pending, or edited

In v1, guest players can be attested locally by the scorekeeper. The model should
still preserve attestation as a first-class part of round closure.

### Social Output

Completed rounds should naturally produce structured social content.

The post-round summary should support:

- final score
- highlights
- notable holes
- optional AI-generated commentary

Users should not need to compose a post from scratch just to share a round.

## Component Patterns

The component system should stay small, reusable, and visually consistent across the
product.

### Core Families

The primary reusable component families should be:

- `hero cards`
- `utility cards`
- `insight panels`
- `player chips`
- `HUD modules`
- `action sheets`

### Hero Cards

Use hero cards for high-priority states such as:

- resume round
- primary AI insight
- completed round summary

They should have the strongest hierarchy and one dominant action.

### Utility Cards

Use utility cards for quieter modules such as:

- nearby courses
- recent rounds
- profile modules

### Insight Panels

Insight panels should feel refined and concise:

- one strong title
- one explanatory sentence
- one clear next step

They should not resemble chat bubbles or gimmicky AI widgets.

### Round HUD Modules

`HUD modules` should act like composable instrument clusters with one clear job each:

- target distance
- selected club
- wind and elevation context
- hole metadata
- score state

They should be swappable or collapsible so the live round interface can breathe.

### Player Chips

`Player chips` should carry identity consistently across setup, scoring, and
attestation using:

- name
- color
- optional avatar

Guests and registered users should look nearly identical in the UI, with only subtle
status differences.

### Sheets and Overlays

Sheets should handle focused tasks such as:

- club selection
- score entry
- auth gates
- guest-player creation
- premium prompts

The user should learn one coherent presentation language that applies across the app.

## Later Feature: Practice and Launch Monitor Integration

This is scoped as a later feature, but the core architecture should leave room for it.

### Product Intent

Support at-home practice sessions and external launch monitors so users can train at
home and carry those insights into on-course rounds.

### Early Technical Feasibility Notes

- Garmin is the strongest early partner candidate because Garmin publicly offers a
  Golf API with scorecard, launch monitor, and GPS shot data access.
- Launch monitor vendors already monetize practice analytics heavily, so integrations
  may require commercial partnerships rather than open APIs.
- The app should not assume broad direct vendor access in v1.

### Scaffold Implications

Even if no launch monitor UI ships yet, the app model should reserve room for:

- `PracticeSession` alongside `RoundSession`
- Generic data ingestion from `manual`, `watch`, and `external_launch_monitor`
- Shared shot and swing event models
- Feature entitlement checks for premium intelligence

This keeps the future practice product technically plausible without expanding v1
scope.
