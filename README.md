# SwingPal

SwiftUI iOS app for playing and tracking golf rounds: course discovery and import (including OpenStreetMap-backed ingestion), live scoring with a club HUD, weather snapshots, bag and handicap profile, stats, and a social layer (feed, follows, discovery, NFC follow). A **watchOS** companion app syncs round state for quick actions on the wrist.

Authentication, profiles, rounds, and shared course data are backed by **[Supabase](https://supabase.com)** via the official [supabase-swift](https://github.com/supabase/supabase-swift) package (2.5.0+).

## Requirements

- **Xcode** (recent release recommended)
- **iOS 18.0+** (iPhone)
- **watchOS 11.0+** (Apple Watch companion)

## Open the project

Open `SwingPal.xcodeproj` in Xcode. Resolve Swift Package dependencies when prompted (Supabase).

## Configure Supabase (optional for local UI)

If `SUPABASE_URL` and `SUPABASE_ANON_KEY` are not set, the app remains usable as a guest. Sign-in reports missing configuration; it does not grant a mock authenticated session. `MockAuthService` is available for tests and previews.

For a real project, add those keys to the SwingPal target’s **Info** (or use an `.xcconfig` as described in the Supabase guide), register the **`swingpal`** URL scheme for `swingpal://auth-callback`, and follow the full checklist:

**[supabase/README.md](supabase/README.md)**

That document covers migrations, auth providers (email/magic link, Apple, Google), storage bucket conventions for community courses, and linking the CLI.

## Project layout (high level)

| Path | Purpose |
|------|---------|
| `SwingPal/` | iOS app: `App/`, `Features/` (Home, Round, Profile, Social, Stats, Auth, …), `Services/`, `DesignSystem/` |
| `SwingPalWatch Watch App/` | watchOS round companion and quick-shot flows |
| `SwingPalTests/` | Unit tests |
| `supabase/` | SQL migrations and Supabase helper scripts |
| `Tools/` | Small Swift utilities for rendering splash / branding assets |
| `docs/` | Design notes and iteration logs |

## Tests

Run tests from Xcode with the **SwingPal** scheme (`⌘U`). From the terminal:

```bash
xcodebuild -project SwingPal.xcodeproj -scheme SwingPal -showdestinations
xcodebuild test -project SwingPal.xcodeproj -scheme SwingPal -destination 'platform=iOS Simulator,name=YOUR_SIMULATOR'
```

Use a simulator name from the first command’s output.

## Club catalog

Add Club downloads a manufacturer-sourced catalog from Supabase with a local cache and bundled offline fallback. A daily Supabase job publishes validated updates from supported manufacturer feeds. See [catalog coverage, deployment and maintenance](docs/data/club-catalog.md).
