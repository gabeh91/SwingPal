# SwingPal Design System Spec

## Purpose

This spec defines the visual system and reusable component anatomy for SwingPal iOS
v1 so implementation can proceed without reinterpretation. It is aligned to the
current product thesis and IA: `Home / Social / Round / Profile`, with `Round`
as the emphasized center tab.

## Visual Principles

- Premium but calm: polished materials, clear hierarchy, no visual noise.
- Bright and natural: day-readable palette inspired by course conditions.
- Utility first: map-first round flow stays visually dominant during play.
- Intelligence second: insights are concise, explainable, and non-gimmicky.
- Consistency: one component language across free, premium, auth, and round states.

## Color System

All tokens below are semantic design tokens (use names, not raw hex in views).

### Brand Foundation

- `color.brand.pine.700` = `#1F4D3A` (primary action / anchors)
- `color.brand.pine.500` = `#2F6D52` (interactive emphasis)
- `color.brand.sand.100` = `#F3EBDD` (warm secondary surface)
- `color.brand.stone.200` = `#D9DDD8` (dividers / quiet fills)
- `color.brand.mist.050` = `#F7FAF9` (default app background)
- `color.brand.sun.400` = `#CFAF52` (restrained premium accent)

### Semantic Roles

- `color.bg.app` = `color.brand.mist.050`
- `color.bg.grouped` = `#EEF2F0`
- `color.surface.primary` = `#FFFFFF`
- `color.surface.secondary` = `color.brand.sand.100`
- `color.surface.elevated` = `#FFFFFF`
- `color.surface.hud` = `#FFFFFFE6` (90% alpha for map overlays)
- `color.surface.sheet` = `#FFFCF7`
- `color.surface.premium` = `#FFF7E3`
- `color.surface.gated` = `#FFFFFF`

- `color.text.primary` = `#10231A`
- `color.text.secondary` = `#40574B`
- `color.text.tertiary` = `#6A7D74`
- `color.text.inverse` = `#F8FBFA`
- `color.text.premium` = `#5A4618`

- `color.stroke.default` = `#D8E0DC`
- `color.stroke.strong` = `#B8C6BF`
- `color.stroke.focus` = `#2F6D52`
- `color.stroke.premium` = `#D5BE7B`

- `color.state.success` = `#2E7D5B`
- `color.state.warning` = `#B5812E`
- `color.state.error` = `#A54646`
- `color.state.info` = `#3E6F97`

### Map and HUD Contrast Rules

- On aerial map, floating modules must use `color.surface.hud` with
  `color.text.primary`.
- Never place pure white text directly on map imagery without a module container.
- Critical metric text (yardage, hole index, score delta) must keep minimum
  contrast of 7:1 against module background.

## Typography System

Use two families only:

- Display: `New York` (or system serif fallback) for score moments and hero headings.
- Functional: `SF Pro` for all body, controls, and dense data.

### Type Roles

- `type.display.hero` = 34 / semibold / -0.5 tracking
- `type.display.score` = 42 / bold / -1.0 tracking
- `type.title.l` = 28 / semibold
- `type.title.m` = 22 / semibold
- `type.title.s` = 18 / semibold
- `type.body.l` = 17 / regular
- `type.body.m` = 15 / regular
- `type.body.s` = 13 / regular
- `type.label.m` = 14 / medium
- `type.label.s` = 12 / medium
- `type.mono.metric` = 16 / semibold (tabular numbers enabled)

### Typography Rules

- Cap line length in cards/sheets to ~65 characters.
- Insight cards: max 1 title line + 2 body lines before truncation.
- Use tabular figures for all yardage, score, wind, and pace metrics.
- Avoid all-caps body copy; all-caps only for tiny metadata labels.

## Spacing, Radius, Shadow, and Surface Tokens

### Spacing

- `space.4`, `space.8`, `space.12`, `space.16`, `space.20`, `space.24`, `space.32`
- Default card padding: `space.16`
- Hero card padding: `space.20`
- Sheet content padding: `space.20`
- HUD module internal padding: `space.12`

### Radius

- `radius.xs` = 8
- `radius.sm` = 12
- `radius.md` = 16
- `radius.lg` = 20
- `radius.pill` = 999
- Default card radius: `radius.md`
- Hero / premium modules: `radius.lg`

### Shadow

- `shadow.none`
- `shadow.soft` = y:2 blur:8 alpha:0.08
- `shadow.mid` = y:6 blur:18 alpha:0.12
- `shadow.float` = y:10 blur:28 alpha:0.16

Use one shadow layer max per surface. Prefer stroke + tonal separation over heavy
drop shadows.

### Surface Depth

- `surface.level.0` app background
- `surface.level.1` default cards and lists
- `surface.level.2` elevated cards, floating HUD modules
- `surface.level.3` sheets and blocking overlays

## Component Families

Each family uses fixed anatomy to preserve recognizability across screens.

### Hero Cards

Use for: resume/start round, top insight, post-round summary.

Anatomy:

1. Eyebrow (optional metadata)
2. Primary headline (1-2 lines)
3. Supporting text (max 2 lines)
4. Primary CTA (required)
5. Optional secondary action (text button only)

Rules:

- Exactly one dominant action.
- May include subtle background gradient pine -> mist at <10% strength.
- Never stack more than 2 hero cards consecutively on one screen.

### Utility Cards

Use for: nearby course row group, recent rounds, profile modules.

Anatomy:

1. Leading icon or thumbnail
2. Title + one-line metadata
3. Optional right-side status/chip
4. Tap target is full card

Rules:

- Quiet visual weight; no strong gradients.
- Metadata is secondary text role only.

### Insight Panels

Use for default insights and coaching insights.

Anatomy:

1. Insight category label (`Trend`, `Club`, `Pace`, etc.)
2. One high-confidence claim sentence
3. Explainability line beginning with `Reason:`
4. Optional `Try next` action

Rules:

- Must be factual in free mode; no speculative coaching language.
- Do not render as conversation bubbles.
- Always include either evidence metric or short reason text.

### Player Chips

Use in player selection, in-round scoring, and attestation.

Anatomy:

1. Color dot / ring
2. Player name
3. Optional avatar
4. Status affordance (guest, confirmed, edited)

Rules:

- Registered and guest chips share same structure and density.
- Guest state uses subtle badge, never warning/error styling.
- Minimum tap target 44x44.

### HUD Modules

Use around live round map.

Module types:

- `hud.distance` (front/middle/back + plays-like)
- `hud.club` (selected club + confidence/avg)
- `hud.conditions` (wind + elevation)
- `hud.hole` (hole number, par, index)
- `hud.score` (player score state)

Rules:

- One metric focus per module.
- Modules may collapse to compact mode but preserve primary metric.
- Keep map center unobstructed; reserve middle 45% width x 40% height.

### Sheets / Overlays

Use for score entry, club selection, auth gates, premium prompts, guest add.

Presentation:

- Bottom sheet first; full-screen cover only for multi-step flows.
- Use consistent grabber, header, and action area.
- Primary action pinned to bottom safe area region.

Rules:

- Max two actions in footer (`Primary`, `Secondary`).
- For destructive actions, require explicit confirmation row.

### Tab Bar + Center Round CTA

Structure:

- Four destinations: `Home`, `Social`, center `Round`, `Profile`.
- Center Round control is a circular raised CTA docked into tab bar.

Tokens:

- `tab.height` = 74
- `tab.icon.default` = `color.text.tertiary`
- `tab.icon.active` = `color.brand.pine.700`
- `tab.round.size` = 62
- `tab.round.bg` = `color.brand.pine.700`
- `tab.round.fg` = `color.text.inverse`
- `tab.round.shadow` = `shadow.mid`

Rules:

- Round CTA is always visible in shell contexts.
- Keep iconography simple and stroke-consistent.

## Motion and Transitions

Motion should communicate precision and confidence, not entertainment.

- `motion.duration.fast` = 0.16s (tap feedback, micro state)
- `motion.duration.base` = 0.24s (card/sheet transitions)
- `motion.duration.slow` = 0.36s (shared-element hero transitions)
- `motion.ease.standard` = easeInOut
- `motion.ease.exit` = easeIn
- `motion.spring.hud` = response 0.32 / damping 0.82

Patterns:

- Shared-element transition from course utility card -> course detail hero.
- HUD metric changes crossfade + numeric roll, never abrupt swap.
- Shot logging confirmation uses subtle scale/fade and optional haptic.

## Free vs Premium Surface States

### Free

- Uses standard surfaces and neutral/pine accents.
- Insight panels show factual summaries and explicit reason lines.
- No locked iconography on core round utility.

### Premium

- Uses `color.surface.premium` and `color.stroke.premium`.
- Premium badge style: restrained (`sun` tint, no glitter effects).
- Premium upsell cards must clearly state incremental benefit, not remove core utility.

### Locked Premium Surface

- Content preview allowed where useful, but action is gated.
- Keep lock messaging concise:
  - headline: what this does
  - subline: why it helps play smarter
  - CTA: `Unlock Premium`
  - secondary: `Not now`

## Auth Gate Presentation Style

- Tone: supportive and non-blocking until user commits a stateful action.
- Preferred presentation: medium-height bottom sheet over current context.
- Copy formula:
  1. What user is trying to do
  2. Why sign-in is needed (save/sync/post/restore)
  3. Choice of auth methods + guest-safe return path

Required actions:

- `Continue with Apple`
- `Continue with Google`
- `Email Magic Link`
- `Not now` (when gate is soft)

Visual:

- Keep same color/typography as rest of app; avoid modal "error" feel.
- Use lightweight iconography and clear spacing to preserve trust.

## AI Insight Card Presentation Rules

- Title states observation, not personality.
- Body must include at least one metric anchor (distance delta, FIR, GIR, etc.).
- Include `Reason:` line in free mode always.
- Coaching mode can add `Try next:` action line, but still cite evidence.
- Keep each card to one actionable point; split multi-topic insights.
- Avoid anthropomorphic language and avoid certainty where confidence is low.

## Live Round HUD Visual Rules

- Map remains primary visual layer at all times.
- Max four expanded HUD modules visible simultaneously.
- Use edge docking (top, left, right, bottom) with consistent spacing grid.
- Active input states (club pick, score entry) dim non-relevant modules to 60%.
- Critical distance and selected club must remain visible in all compact states.
- Transient toasts should never cover target landing area center.

## Accessibility and Outdoor Readability

- Respect Dynamic Type for all text styles; no clipped text at accessibility sizes.
- Minimum contrast:
  - body text >= 4.5:1
  - key metrics and controls >= 7:1 when over imagery
- Minimum touch target: 44x44 points.
- Do not rely on color only for score states or player identity; pair with text/symbol.
- Provide high-legibility mode fallback for direct sunlight:
  - disable translucency for HUD
  - increase stroke contrast
  - promote text role to stronger color
- Keep motion reductions compliant with `Reduce Motion` settings.

## Suggested SwiftUI Token Structure (iOS 17)

Recommended file organization for implementation agents:

- `SwingPal/DesignSystem/DesignTokens/ColorTokens.swift`
- `SwingPal/DesignSystem/DesignTokens/TypographyTokens.swift`
- `SwingPal/DesignSystem/DesignTokens/SpacingTokens.swift`
- `SwingPal/DesignSystem/DesignTokens/RadiusTokens.swift`
- `SwingPal/DesignSystem/DesignTokens/ShadowTokens.swift`
- `SwingPal/DesignSystem/Components/Cards/HeroCard.swift`
- `SwingPal/DesignSystem/Components/Cards/UtilityCard.swift`
- `SwingPal/DesignSystem/Components/Insights/InsightPanel.swift`
- `SwingPal/DesignSystem/Components/Round/HUDModule.swift`
- `SwingPal/DesignSystem/Components/Round/PlayerChip.swift`
- `SwingPal/DesignSystem/Components/Navigation/RoundTabBar.swift`
- `SwingPal/DesignSystem/Components/Overlays/SwingSheet.swift`
- `SwingPal/DesignSystem/Modifiers/SurfaceStyleModifier.swift`
- `SwingPal/DesignSystem/Modifiers/HUDReadableModifier.swift`

Token API guidance:

- Expose semantic tokens as static namespaces (`ColorToken.surface.primary`).
- Keep raw values private to token files.
- Components consume semantic roles only (never raw hex / numeric literals).
- Add preview fixtures for free, premium, and high-legibility variants.

## Non-Goals for This Spec

- No changes to product navigation or feature scope.
- No introduction of new feature areas beyond defined IA.
- No implementation code; this is a design-system contract for upcoming agents.
