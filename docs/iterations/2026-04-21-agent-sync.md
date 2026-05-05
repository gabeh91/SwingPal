# SwingPal Agent Sync

## Purpose

This file coordinates parallel agent work so multiple contributors can move without
overwriting each other or re-deriving product decisions.

## Source of Truth

- Product/design: `docs/plans/2026-04-21-product-flow-design.md`
- Main implementation plan: `docs/plans/2026-04-21-v1-app-shell-implementation.md`
- Rolling log: `docs/iterations/2026-04-21-iteration-log.md`

## Active Workstreams

### Agent 1: App Shell Implementation

**Scope**

- Execute `docs/plans/2026-04-21-v1-app-shell-implementation.md`
- Work only in app source, tests, and Xcode project files required by that plan

**Primary objectives**

1. Replace the placeholder app with the real shell
2. Implement `Home / Social / Round / Profile`
3. Build the round setup and live round scaffolds
4. Add auth and premium gate placeholders
5. Verify with the plan’s `xcodebuild` commands

**Do not do**

- No Supabase SDK integration
- No Apple Watch targets
- No backend implementation
- No redesign of information architecture

**Deliverables**

- Code changes only
- Iteration log updates in `docs/iterations/2026-04-21-iteration-log.md`

### Agent 2: Design System and Component Spec

**Scope**

- Docs-only work
- Create `docs/plans/2026-04-21-design-system-spec.md`

**Primary objectives**

1. Define visual tokens and naming
2. Define component anatomy for hero cards, utility cards, insight panels, player
   chips, HUD modules, sheets, and tab bar
3. Define motion and transition rules
4. Define outdoor readability and accessibility constraints
5. Define premium and auth gate presentation rules

**Do not do**

- No app source edits
- No product-scope changes
- No schema/backend work

**Deliverables**

- Design-system spec doc
- Iteration log update in `docs/iterations/2026-04-21-iteration-log.md`

### Agent 3: Supabase Auth and Data Model Planning

**Scope**

- Docs-only work
- Create `docs/plans/2026-04-21-supabase-auth-data-design.md`

**Primary objectives**

1. Define auth model for Apple, Google, email magic link, and guest conversion
2. Define mutual-friends social schema
3. Define v1 tables for profiles, rounds, bag, social, and attestation
4. Define RLS strategy and account-linking approach
5. Identify future-ready extension points for Apple Watch intelligence and later
   launch monitor integrations

**Do not do**

- No app source edits
- No Supabase SDK installation
- No schema migration implementation yet

**Deliverables**

- Supabase auth/data design doc
- Iteration log update in `docs/iterations/2026-04-21-iteration-log.md`

## Coordination Rules

- Append to the iteration log instead of rewriting past decisions
- Do not change another agent’s deliverable file unless explicitly coordinating
- Preserve the current IA:
  - `Home`
  - `Social`
  - `Round`
  - `Profile`
- Keep `Round` as the emphasized center tab
- Keep core round utility free
- Keep premium focused on intelligence and helpfulness

## Review Order

1. Agent 2 design-system spec
2. Agent 3 Supabase auth/data design
3. Agent 1 implementation diff review against both docs

## Re-Baseline

The workspace drifted after parallel updates. Use this section as the authoritative
sync point until a newer one is written.

### Authoritative Current State

- Product/design source of truth is still:
  - `docs/plans/2026-04-21-product-flow-design.md`
- Design-system source of truth is:
  - `docs/plans/2026-04-21-design-system-spec.md`
- Backend/auth source of truth is:
  - `docs/plans/2026-04-21-supabase-auth-data-design.md`

### Current App Code State

- The app shell files for `Home`, `Social`, `Round`, and `Profile` exist
- Round setup, live round, review/attestation, bag, and gate scaffolds exist in app
  code
- The app source tree passes a `swiftc -typecheck` verification pass in the current
  sandbox
- Full `xcodebuild` verification is not authoritative right now because iteration
  notes conflict and this environment has repeated CoreSimulator / actool failures

### Known Documentation Conflict

The iteration log currently contains conflicting verification claims:

- one entry says `xcodebuild test` and `xcodebuild build` are blocked by the sandbox
- a later entry says both succeeded

Until re-verified in a clean environment, treat the following as authoritative:

- `swiftc -typecheck` source verification: confirmed
- `xcodebuild` full verification: unconfirmed

### Immediate Next-Step Split

#### Agent 1

- Do not claim `xcodebuild` success unless rerun and captured in a clean environment
- Next useful work is refinement and alignment of app code to:
  - `docs/plans/2026-04-21-product-flow-design.md`
  - `docs/plans/2026-04-21-design-system-spec.md`
- Current local ownership split to avoid collisions:
  - **Codex local slice:** `SwingPal/App/AppShellView.swift`, `SwingPal/Features/Home/HomeView.swift`,
    `SwingPal/Features/Home/HomeHeroCard.swift`, `SwingPal/Features/Auth/AuthGateView.swift`,
    `SwingPal/Features/Profile/ProfileView.swift`
  - **Other agent slice:** `SwingPal/Features/Round/CourseListView.swift`,
    `SwingPal/Features/Round/CourseDetailView.swift`, `SwingPal/Features/Round/PlayerSelectionView.swift`,
    `SwingPal/Features/Round/LiveRoundView.swift`, `SwingPal/Features/Round/RoundReviewView.swift`
- Shared guidance:
  - visual/token alignment
  - stronger shell cohesion
  - remove placeholder mismatches
  - keep mocked data only

#### Agent 2

- Design-system doc is complete enough to treat as baseline
- Next useful work should be review-only unless explicitly asked to extend docs

#### Agent 3

- Supabase auth/data doc is complete enough to treat as baseline
- Next useful work should be review-only unless explicitly asked to create migration
  plans or schema tasks
