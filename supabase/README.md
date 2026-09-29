# Supabase setup

For the public club catalog, automatic manufacturer refresh and deployment command, see [Club catalog](../docs/data/club-catalog.md#hosting-and-automatic-maintenance). Migration `0005_club_catalog.sql` adds its Storage buckets and service-only job infrastructure.

The iOS app expects a Supabase project with the schema in
`supabase/migrations/0001_init.sql` plus a few dashboard-only steps that
can't be expressed as SQL.

## 1. Create the project

1. https://app.supabase.com → **New project**.
2. Note the **Project URL** and **anon public key** (Project Settings → API).

## 2. Run the schema

### Option A — Supabase CLI (tracks migration history)

Requires [Supabase CLI](https://supabase.com/docs/guides/cli): `brew install supabase/tap/supabase`.

From the **repository root**:

```bash
supabase login
./supabase/push_migrations.sh
```

`login` opens the browser once. If `link` prompts for your **database password**, use the value from **Project Settings → Database** (or run `./supabase/push_migrations.sh -p 'YOUR_DB_PASSWORD'`).

That runs `supabase link --project-ref zhmvngzfhzyyvyseeaxi` then `supabase db push`, applying everything under `supabase/migrations/`.

### Option B — Dashboard SQL Editor (no CLI)

Open **SQL Editor → New query**, paste the contents of
`supabase/migrations/0001_init.sql`, and run it once. You should now have:

- Tables `profiles`, `bags`, `handicaps`, `follows`, `rounds` with RLS on.
- A trigger that auto-creates a `profiles` row whenever a new
  `auth.users` row is inserted.
- A storage bucket called `courses` (community-readable + writable, but
  not publicly accessible to anonymous web visitors).

## 3. Enable auth providers

**Authentication → Providers**:

- **Email** — enable. Toggle “Confirm email” if you want strict signup.
- **Magic Link** — same Email provider, no extra config (the iOS client
  calls `signInWithOTP(email:)`).
- **Apple**:
  - In your Apple Developer account create a **Services ID** (e.g.
    `com.example.SwingPal.signin`) and a **Sign in with Apple key**.
  - Download the `.p8` and capture the **Key ID** and **Team ID**.
  - Paste them into Supabase Apple provider config + add a redirect URL
    of `https://<project>.supabase.co/auth/v1/callback`.
  - In Xcode, add the **Sign in with Apple** capability to the SwingPal
    target.
- **Google**:
  - In Google Cloud Console create an **OAuth 2.0 Client (Web app)** and
    add `https://<project>.supabase.co/auth/v1/callback` as an
    authorized redirect URI.
  - Paste Client ID + Client Secret into Supabase Google provider.
  - The iOS app uses Supabase's hosted OAuth flow (`ASWebAuthenticationSession`),
    so no native Google SDK or iOS client ID is required.

**Authentication → URL Configuration**:

- Set the **Site URL** to your production redirect, e.g.
  `swingpal://auth-callback` (deep link the app already handles).
- Add `swingpal://auth-callback` to **Additional Redirect URLs**.

## 4. Hand the URL + anon key to the iOS app

Two options. Pick one:

### Option A — `Info.plist` build settings (recommended for now)

Add these two keys to the **SwingPal** target’s Info (Build Settings →
Info or `Info.plist`):

| Key                   | Type   | Value                       |
| --------------------- | ------ | --------------------------- |
| `SUPABASE_URL`        | String | `https://xxxx.supabase.co`  |
| `SUPABASE_ANON_KEY`   | String | `eyJhbGciOi...` (anon key)  |

The Swift code reads them via `Bundle.main.object(forInfoDictionaryKey:)`.
If the keys are missing, the app shows a clear error on launch instead
of silently using nil.

### Option B — `.xcconfig` (better for repos / CI)

Create `Config/Supabase.xcconfig` with:

```
SUPABASE_URL = https://xxxx.supabase.co
SUPABASE_ANON_KEY = eyJhbGciOi...
```

Wire it into the SwingPal Debug + Release configurations and reference
the values from `Info.plist`:

```
SUPABASE_URL = $(SUPABASE_URL)
SUPABASE_ANON_KEY = $(SUPABASE_ANON_KEY)
```

Add `Config/Supabase.xcconfig` to `.gitignore` (or commit a
`Supabase.example.xcconfig` template).

## 5. Deep link

Add `swingpal` as a custom URL scheme in the SwingPal target:

- **Info → URL Types → +**, set URL Schemes to `swingpal`.

The auth callback URL used by the OAuth/magic-link flows is
`swingpal://auth-callback`.

## 6. Storage bucket conventions

- **Path**: `courses/<course-id>.json` (object key is `<uuid>.json` inside the
  `courses` bucket; `course-id` is `SwingPalCourse.id`).
- **MIME type**: `application/json`.
- **Cache-Control**: uploads use `86400` seconds via the Swift client’s
  `FileOptions` (aligned with CDN caching).
- Anonymous web visitors get `403`; signed-in app users get `200`.

The iOS app loads all `*.json` objects from this bucket after sign-in (see
`CommunityCourseStorageService`) and merges them into the course picker via
`CompositeCourseRepository`. Successful imports can be uploaded with
`CommunityCourseStorageService.uploadCourse`.
