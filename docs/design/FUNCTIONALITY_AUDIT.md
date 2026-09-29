# SwingPal functionality audit

21 September 2026 · Baseline commit `79ab657` · Audit and repair working tree

## What this review establishes

SwingPal has a substantial native core: bundled and imported courses, live map/GPS state, shot logging, hole confirmation, bag/profile data, local round resumption, optional on-device analysis, Supabase services and WatchConnectivity. It is not a finished end-to-end golf record system. Several working screens previously used invented numbers or promised state transitions that were not backed by the data model.

Evidence includes source tracing, the existing unit suite, new regressions and a native simulator inspection. Cloud sign-in, real GPS accuracy, physical Watch pairing/NFC, StoreKit and real-device VoiceOver/haptics were not exercised. No customer data was posted and no cloud schema was deployed. Browser proposal fixtures are not audit evidence for native functionality.

The baseline suite ran on iPhone 17 Pro / iOS 26.3.1: **446 tests, 438 passed, 8 failed**. Six failures concerned club-wheel tests that assumed an unfiltered catalog, including three test index traps. Two setup failures concerned missing/stale distance copy. After repairs, the complete suite passes **462 tests, zero failures**. See [review evidence](review/README.md) for verification details and captures.

## Confirmed findings and repairs

### F01 — Invented personal performance numbers · High · Repaired in this pass

`HomeViewModel.swift` populated FIR `57%`, GIR `44%` and putts `31.2` regardless of round history, while `HomeView.swift` described rolling averages. A new player could therefore see apparently personal performance that never happened.

Replace these with recorded score, putts, penalties and hole progress from a genuinely completed record. Empty history remains unavailable. Tests exercise empty history and real values; no invented substitute is introduced. FIR/GIR need their underlying recorded denominators before they can return.

### F02 — Partial rounds and unrelated facts presented as skill trends · High · Repaired in this pass

`StatsViewModel.swift` previously compared the latest records including unfinished checkpoints. It called aggregate penalties “Driving”, all strokes “Approach”, and progress/completion “Short Game”. Matching penalties/putts could also produce “scoring holding steady” despite changed stroke totals.

Comparisons now use a declared sample of completed records with matching hole counts. Labels describe the actual aggregates: scoring, penalties, putting and round history. Checkpoints remain visible in history. Missing putt detail remains a model limitation: integer totals cannot prove whether every putt was recorded, so copy says recorded putts and avoids asserting measured skill.

### F03 — Seeded and stale course proximity · High · Repaired in this pass

`SeededCourseRepository` assigned Medway `2.6 km` and Royal Melbourne `3.2 km`; imports converted absent distance into zero; composite repositories could retain distances measured from somebody else's earlier location. These were displayed and sorted as nearby courses.

Distance is now optional; cached/bundled proximity is discarded. Round setup calculates distance only against an available current device location. Unknown distances do not render as zero. Nearby wording distinguishes saved courses when no measurement exists. The setup summary again carries explicit yard units rather than a bare number. Regression tests cover unknown, stale and current-location paths.

### F04 — Review completion discarded incomplete work · High · Repaired in this pass

`RoundReviewView` labelled the same callback Save Review or Close Round; `RoundRootView` always called `completeActiveRound()`. `AppState` marked every hole complete whenever status was finished and cleared the active snapshot. `reviewPlayers` held the latest hole score, not a round total; history summed shot records instead of preferring the manually entered score.

Completion now requires confirmed positive scores for every tracked hole; incomplete rounds remain resumable drafts. Review totals follow entered scores and subsequent corrections. Derived scores include penalties and count cumulative putts once; quick confirmation preserves a manually entered score. Guest rows are explicitly untracked, and final-hole quick confirmation opens review. The integrated suite passes 462 tests.

### F05 — Premium upgrade was a local switch · High · Repaired in this pass

`AppShellView.swift`'s premium callback set `entitlements = .premium`. There was no StoreKit product loading, transaction verification, restoration or durable purchase entitlement. The old copy sold broader intelligence without a backed offer.

Remove the fake upgrade callback and show a truthful unavailable-purchase sheet with dismissal. This is a safe unavailable state, not a completed purchase integration. StoreKit configuration and lifecycle remain separate release work. Native review also corrected the new sheet to use system colours and a large detent at accessibility text sizes; Home/Profile entry copy now describes availability.

### F06 — Club recommendation overstated provenance · Medium · Repaired in this pass

`BagClubRecommendation` called a stored typical distance “your average”; an empty bag fabricated an Unknown club at zero carry, and invalid carry/target values could produce a suggestion. Profile used a fixed `160 m` target without identifying it as an example.

Use “Your bag lists …”, exclude nonpositive carry values, and return a clear no-recommendation state for an empty/invalid bag or unavailable target. Profile explicitly labels its fixed target as an example. Its signed-in status no longer claims Saved to Cloud or cross-device readiness without a sync result. Four club regressions reproduced the failures before the fix.

### F07 — Existing club-wheel tests crashed on filtered data · Medium · Test fixture repaired

The current automatic wheel deliberately displays a filtered set. Older geometry and baseline-distance tests assumed the full twelve-club catalog and indexed element 3/5 when only three entries existed. Explicitly put those full-catalog tests into manual mode. This preserves actual automatic filtering and the tests' geometric assertions rather than changing production behavior to satisfy stale fixture assumptions.

## Remaining release blockers

### R01 — Account boundaries do not isolate local records · High

Evidence: `AppState.swift` uses fixed UserDefaults keys for bag, active round and history; sign-out clears social/profile presentation but retains those stores. `UserDataSyncService.syncFromCloud` merges local and remote round histories, then upserts the merged local collection under the current user ID. Bag/handicap push timestamps are also global.

Risk: switching accounts can expose or try to synchronize a previous account's cached data. Actual server outcomes depend on row ownership/RLS and were not reproduced against a live backend. This is a source-confirmed unsafe ownership model, not a claim of demonstrated cloud disclosure.

Required fix: introduce user-scoped local stores and explicit guest ownership/claiming, cancel in-flight work when session changes, and migrate existing data without deleting or silently reassigning it. Verify guest → A → sign-out → B → A, interrupted sync and offline edits. This needs an ownership migration, not just clearing the UI.

### R02 — Saving implicitly shares a round · High

Evidence: `UserDataSyncService.upsertRound` supplies `is_shared: true`; `SocialFeedService` loads finished rounds available through RLS and describes the user's finished round as synced for their circle. A save is not an explicit share decision.

Required fix: persist an explicit sharing preference, default new rounds to private, retain existing choices on ordinary sync and add a deliberate share/unshare control. Do not repair this by blindly writing false for every sync: that would overwrite users' previous choices. No existing cloud records were changed in this pass.

### R03 — Finished history loses the complete record · High

Evidence: `completeActiveRound` archives a `RoundHistorySummary` then clears the active snapshot. That summary has totals but no hole sessions, shot sequence, player score record or tee/rating metadata; the cloud upsert supplies `payload: nil`.

Required fix: persist a versioned completed-round snapshot before clearing the active one, and support loading that record into history/review. Preserve local data during cloud retry. Test finish → terminate → relaunch → open every hole → correct score → refresh analysis. Old summary-only records need an honest limited-detail state; their missing shots cannot be reconstructed.

### R04 — Multi-player setup exceeds scoring support · High

Guests can be added, but the live/review score updates target the first non-guest player. No corresponding guest per-hole score input and attestation persistence was found. Guest identity is implemented; full guest scoring is not.

The bounded fix labels this limitation honestly and avoids locking completion forever on untrackable guest confirmations. Shipping multiplayer scorekeeping needs a per-player, per-hole model, edit routes and confirmation states. A count of names must not be presented as multiple completed scorecards.

### R05 — Course metadata includes estimates without adequate provenance · High

`RuntimeOSMCourseConverter` substitutes par 4 when absent and synthesizes Championship/Member/Forward tees and distances from available geometry. These can flow into ordinary setup controls. `SwingPalCourse.QualitySnapshot` reduces source state to provisional/reviewed/verified; seeded courses assign reviewed/verified flags without an in-app provenance record.

Required fix: source/estimate flags per field, explicit unavailable or estimated tee/rating/par states, and restrictions on calculations requiring authoritative inputs. Keep score entry usable, but never let generated tee names imply official course tee data. Validate representative 9/18-hole imports, missing greens, duplicate geometry and partial import cancellation.

### R06 — Sync has logs, not a recoverable user-visible state · High

`UserDataSyncService` catches and logs failures. Local saves are useful, but views do not get an operation result or durable pending/retry state. Deletes have no demonstrated tombstone/queued retry: a failed remote delete can be merged back later.

Required fix: explicit local/pending/synced/failed state, durable outbox and deletion tombstones, with idempotent retry and account-bound cancellation. Keep the local record throughout. Do not call a local write “synced”.

## Carry-name follow-up found during planner review

`LiveRoundState.lookupClubValue` matches exact/case-insensitive names but does not map long names to abbreviations. The review fixture supplies `Pitching Wedge: 95`; manually selecting the separate `PW` catalog entry yields its 96 m estimated baseline instead. The UI identifies that value as estimated, but the same physical club can be represented twice. Reconcile catalog IDs/aliases with bag entries and migrated rounds before claiming all bag carries map reliably to every manual selector entry. This was observed in the fixture and source; production bag migration impact still requires targeted review. No carry values or normalization rules were changed by the visual revision.

## Other implementation gaps

- **Accessibility:** semantic fonts and some labels exist, but the audit search found no explicit `accessibilityReduceMotion`, `accessibilityReduceTransparency`, `dynamicTypeSize`, `ScaledMetric` or adjustable-action handling in the reviewed app/Watch sources at baseline. Custom fixed-size fonts, geometry, drag controls and animated chrome need native adaptation and testing. Absence of those APIs alone does not prove every control inaccessible; full VoiceOver is untested.
- **Visual hierarchy:** native Home devotes much of its first viewport to slogans, repeated headings and a large translucent round card, while functional content falls below. The custom tab bar overlaps visual content in the initial capture. Independent per-screen palettes, serif display headings and gradients conflict with the requested direction. The new composition study is a proposal, not a completed native replacement.
- **Starter bag:** first use loads branded catalog clubs and typical distances from `Bag.starter`. Treat these as optional sample equipment or start with an empty bag; a migration must preserve genuine user edits. Current carry-source labels also conflate stored bag data with logged/measured carry.
- **Handicap:** the estimator subtracts assumed 36/72 par and selects best values; it has no rating/slope and is not official handicap computation. Ensure every surface labels this as an estimate, keep manual official input distinct, and avoid implying certification.
- **Course correction:** correction submission persists a local draft/status through `CourseCorrectionCenter`; a complete remote moderation/application loop was not established. Use Pending sync, not Received/reviewed, without server acknowledgement.
- **Analysis:** Foundation Models with deterministic fallback and local caching exists. Inputs are aggregate summaries; they do not support claims about swing technique, shot-by-shot causes or coaching outcomes. Home/Stats select analysis by round ID; current-key validation after edits needs review. Provider state, stale results, failure and no-data copy need explicit handling.
- **Authentication:** Supabase auth and a missing-configuration service exist. README's old mock fallback description was stale; missing production configuration does not silently sign users in. Real provider/callback/logout and account deletion need an authenticated test environment.
- **Weather/location:** WeatherKit/device location implementations exist, but service entitlements, permission denial, stale location, real course distance and offline transitions were not physically exercised. Permission explanation should precede an intentional action; search must remain possible when denied.
- **Watch:** snapshot sync, quick shot, club selection, hole finish, reachability and queued feedback code exist. No physical paired-device/offline replay validation was performed. Do not describe motion/swing analysis as delivered merely because a Watch app exists.
- **Social/NFC:** feed/follow/search/deep-link and nearby/NFC services exist; real multi-account visibility, permissions and hardware handoff are unverified. No social messages or follows were sent during this audit.

## Implementation order

1. Land the bounded truthfulness/scoring fixes with the full unit suite green.
2. Resolve account ownership, full-round archival, explicit sharing and durable sync before expanding claims about saving or multi-device continuity.
3. Add field-level course provenance and complete the scoring/counting contracts; decide whether multiplayer is in the release or explicitly deferred.
4. Implement the reviewed Home/setup/live/review native compositions, recording populated/empty/incomplete/error evidence at each step.
5. Finish secondary screens, accessibility/device review, real services and StoreKit only when their lifecycle states can be demonstrated.

This audit is a bounded product/code review, not a security certification or a claim that every possible runtime defect has been found. Remaining items are intentionally visible so subsequent work is concrete and testable.
