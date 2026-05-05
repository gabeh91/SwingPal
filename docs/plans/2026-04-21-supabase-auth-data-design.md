# SwingPal Supabase Auth and Data Design

## Goal

Define a v1-ready Supabase auth and data model for SwingPal that supports guest-first
usage, mutual-friends social features, saved rounds, bag data, attestation, and
future premium intelligence without forcing premature backend complexity.

## Design Principles

- Guests should be able to explore before cloud identity is required
- Authentication should become mandatory only for stateful or social actions
- The social graph should feel intimate and trusted, not public or follower-driven
- Core round data should be normalized enough for analytics and coaching later
- Premium should be enforced through entitlements, not hardcoded UI logic
- Future watch and motion features should extend the model, not replace it

## Auth Model

Supabase Auth is the preferred v1 identity provider.

### Supported Methods

- Sign in with Apple
- Continue with Google
- Email magic link
- Guest mode

### Guest Strategy

Guest mode should remain local-only at first. The guest can:

- browse nearby courses
- explore the app shell
- begin the round funnel

The app should require sign-in only when the user attempts a stateful cloud action:

- save a round to the cloud
- sync bag or profile data
- post socially
- restore data on another device
- add or manage friends

### Biometrics

Face ID and Touch ID are local convenience features only. They should unlock locally
stored app sessions after sign-in and must not be treated as the cloud identity
system.

### Account Linking

The backend should assume one durable user identity and support later identity
linking. Example path:

1. User starts with email magic link
2. User later signs in with Apple
3. The app links both methods to the same SwingPal account

The data model should avoid user duplication by anchoring all first-party data to one
profile row per authenticated user.

## Social Graph Model

v1 should use `mutual friends`, not followers.

### Why

- Fits the trusted golf-circle product direction
- Keeps the `Social` tab intimate and high-signal
- Avoids early pressure to build public-feed moderation and discovery systems

### Tables

#### `profiles`

Extends `auth.users` with app-level identity and settings.

Suggested columns:

- `id uuid primary key references auth.users(id)`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`
- `display_name text not null`
- `username text unique`
- `avatar_url text`
- `bio text`
- `home_club text`
- `handicap_index numeric(4,1)`
- `premium_tier text not null default 'free'`
- `premium_expires_at timestamptz`
- `ai_coaching_enabled boolean not null default false`
- `default_distance_unit text not null default 'meters'`

#### `friend_requests`

Tracks pending relationship changes.

Suggested columns:

- `id uuid primary key default gen_random_uuid()`
- `requester_id uuid not null references profiles(id)`
- `recipient_id uuid not null references profiles(id)`
- `status text not null`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

Recommended status values:

- `pending`
- `accepted`
- `declined`
- `canceled`

Recommended constraint:

- requester and recipient must differ

#### `friendships`

Stores accepted mutual relationships once per pair.

Suggested columns:

- `id uuid primary key default gen_random_uuid()`
- `user_low_id uuid not null references profiles(id)`
- `user_high_id uuid not null references profiles(id)`
- `created_at timestamptz not null default now()`

Recommended constraints:

- canonical ordering: `user_low_id < user_high_id`
- unique pair on `(user_low_id, user_high_id)`

This simplifies queries and prevents duplicate reciprocal rows.

## Golf Data Model

The app should keep the v1 golf model normalized around `rounds`.

### `bags`

User-owned bag container.

Suggested columns:

- `id uuid primary key default gen_random_uuid()`
- `user_id uuid not null references profiles(id)`
- `name text not null default 'My Bag'`
- `is_default boolean not null default true`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

### `clubs`

Bag club configuration and baseline distance source.

Suggested columns:

- `id uuid primary key default gen_random_uuid()`
- `bag_id uuid not null references bags(id)`
- `name text not null`
- `club_type text not null`
- `loft numeric(4,1)`
- `typical_distance_m integer`
- `display_order integer not null default 0`
- `is_active boolean not null default true`
- `notes text`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

### `courses`

Canonical course record used by setup and history.

Suggested columns:

- `id uuid primary key default gen_random_uuid()`
- `name text not null`
- `country_code text`
- `region text`
- `locality text`
- `latitude double precision`
- `longitude double precision`
- `hole_count integer`
- `par integer`
- `metadata jsonb not null default '{}'::jsonb`

### `course_tees`

Course-specific tee data.

Suggested columns:

- `id uuid primary key default gen_random_uuid()`
- `course_id uuid not null references courses(id)`
- `name text not null`
- `tee_color text`
- `gender_category text`
- `total_yardage integer`
- `total_meterage integer`
- `course_rating numeric(4,1)`
- `slope_rating integer`
- `display_order integer not null default 0`

### `rounds`

Parent record for in-progress or completed rounds.

Suggested columns:

- `id uuid primary key default gen_random_uuid()`
- `owner_user_id uuid references profiles(id)`
- `course_id uuid not null references courses(id)`
- `course_tee_id uuid references course_tees(id)`
- `status text not null`
- `started_at timestamptz not null default now()`
- `completed_at timestamptz`
- `current_hole_number integer`
- `is_social_posted boolean not null default false`
- `weather_summary jsonb not null default '{}'::jsonb`
- `round_notes text`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

Recommended status values:

- `draft`
- `active`
- `completed`
- `attested`
- `archived`

### `round_players`

Supports both real accounts and lightweight guests.

Suggested columns:

- `id uuid primary key default gen_random_uuid()`
- `round_id uuid not null references rounds(id)`
- `profile_id uuid references profiles(id)`
- `guest_name text`
- `guest_avatar_seed text`
- `display_order integer not null default 0`
- `role text not null default 'player'`
- `is_scorekeeper boolean not null default false`
- `created_at timestamptz not null default now()`

Recommended rule:

- exactly one of `profile_id` or `guest_name` should be present

### `holes`

Per-hole state for each round.

Suggested columns:

- `id uuid primary key default gen_random_uuid()`
- `round_id uuid not null references rounds(id)`
- `hole_number integer not null`
- `par integer`
- `yardage integer`
- `tee_shot_latitude double precision`
- `tee_shot_longitude double precision`
- `pin_latitude double precision`
- `pin_longitude double precision`
- `started_at timestamptz`
- `completed_at timestamptz`
- `created_at timestamptz not null default now()`

Recommended constraint:

- unique `(round_id, hole_number)`

### `shots`

Normalized shot events for analytics and later intelligence.

Suggested columns:

- `id uuid primary key default gen_random_uuid()`
- `round_id uuid not null references rounds(id)`
- `hole_id uuid not null references holes(id)`
- `round_player_id uuid not null references round_players(id)`
- `shot_number integer not null`
- `club_id uuid references clubs(id)`
- `club_name_snapshot text`
- `lie_type text`
- `distance_to_target_m integer`
- `plays_like_distance_m integer`
- `start_latitude double precision`
- `start_longitude double precision`
- `end_latitude double precision`
- `end_longitude double precision`
- `target_latitude double precision`
- `target_longitude double precision`
- `wind_summary jsonb not null default '{}'::jsonb`
- `sensor_source text not null default 'manual'`
- `metadata jsonb not null default '{}'::jsonb`
- `created_at timestamptz not null default now()`

Recommended `sensor_source` values:

- `manual`
- `iphone`
- `watch`
- `launch_monitor`

### `player_hole_scores`

Separates score state from shot logging and keeps attestation simpler.

Suggested columns:

- `id uuid primary key default gen_random_uuid()`
- `round_id uuid not null references rounds(id)`
- `hole_id uuid not null references holes(id)`
- `round_player_id uuid not null references round_players(id)`
- `strokes integer`
- `putts integer`
- `penalties integer`
- `fairway_hit boolean`
- `green_in_regulation boolean`
- `sand_save_opportunity boolean`
- `up_and_down boolean`
- `score_status text not null default 'pending'`
- `updated_at timestamptz not null default now()`

### `attestations`

Tracks round confirmation.

Suggested columns:

- `id uuid primary key default gen_random_uuid()`
- `round_id uuid not null references rounds(id)`
- `round_player_id uuid not null references round_players(id)`
- `attested_by_profile_id uuid references profiles(id)`
- `status text not null`
- `attested_at timestamptz`
- `notes text`

Recommended `status` values:

- `pending`
- `confirmed`
- `confirmed_by_scorekeeper`
- `edited_after_confirmation`

## Social Output Model

Completed rounds should create structured feed content without requiring the user to
 author a post from scratch.

### `social_posts`

Suggested columns:

- `id uuid primary key default gen_random_uuid()`
- `author_profile_id uuid not null references profiles(id)`
- `round_id uuid references rounds(id)`
- `post_type text not null`
- `title text not null`
- `subtitle text`
- `score_summary text`
- `summary_payload jsonb not null default '{}'::jsonb`
- `visibility text not null default 'friends'`
- `created_at timestamptz not null default now()`

Recommended `post_type` values:

- `round_summary`
- `milestone`
- `achievement`

Keep this structured in v1. Freeform social composition can come later.

## RLS Strategy

Row Level Security should be enabled from the start.

### Private User Data

Tables such as `profiles`, `bags`, `clubs`, and private preferences should be
readable and writable only by the owning authenticated user.

### Round Ownership

The round owner should be able to:

- create rounds
- update active rounds they own
- read their own rounds
- read the guest-player rows attached to their rounds

### Friend Visibility

Social feed records should be readable only when:

- the viewer is the author, or
- the viewer and author are confirmed friends

### Public Course Data

`courses` and `course_tees` can be readable by all authenticated users and can later
be mirrored locally for guest browsing if needed.

## Guest Conversion Flow

The backend should be ready for a clean conversion path:

1. Guest uses the app locally
2. Guest attempts a cloud-backed action
3. App prompts for Apple, Google, or email auth
4. Local round or bag data is migrated into the newly authenticated profile

For v1, this migration can happen client-side after authentication rather than
requiring a complex anonymous-auth backend flow.

## Premium and Entitlements

Premium state should remain explicit and queryable.

### Minimal v1 approach

Keep entitlement fields in `profiles` first:

- `premium_tier`
- `premium_expires_at`

This is enough for:

- gating Apple Watch live round support
- gating advanced motion intelligence
- gating projected landing/search assist
- gating advanced AI coaching outputs

### Future extension

If billing complexity grows, add:

- `subscriptions`
- `entitlements`
- `purchase_events`

Do not over-model this in v1.

## Future-Ready Extension Points

The schema should leave room for later premium and hardware work without forcing it
into the first implementation.

### Suggested later tables

- `analysis_snapshots`
- `swing_events`
- `practice_sessions`
- `launch_monitor_sessions`

These should remain deferred until the product flow for them is real.

## Recommended Implementation Sequence

1. Supabase Auth configuration for Apple, Google, and email magic link
2. `profiles`, `friend_requests`, `friendships`
3. `bags`, `clubs`
4. `courses`, `course_tees`
5. `rounds`, `round_players`, `holes`, `shots`, `player_hole_scores`, `attestations`
6. `social_posts`
7. RLS policies

This sequence gets identity and core golf data stable before social complexity.
