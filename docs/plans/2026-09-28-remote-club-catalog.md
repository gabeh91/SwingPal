# Remote Club Catalog Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Publish validated manufacturer model updates automatically to Supabase JSON and load them in Add clubs with a durable offline fallback.

**Architecture:** A public Storage object serves schema-versioned JSON. A daily authenticated Edge Function merges the reviewed seed with supported manufacturer feeds, validates the whole catalog, archives a revision, then replaces the live object. The iOS app loads its last good cache immediately and refreshes daily; an active selection keeps a stable catalog snapshot.

**Tech Stack:** Swift/URLSession, Supabase Storage, Deno Edge Functions, Postgres pg_cron/pg_net/Vault.

---

1. Add failing iOS tests in `SwingPalTests/ProfileViewModelTests.swift` for schema validation, offline fallback, persistent cache, invalid responses, request coalescing and refresh timing. Implement `SwingPal/Services/Storage/ClubCatalogStore.swift`, register it in the Xcode project, and connect `AddClubSheet.swift` and app startup.
2. Add failing Deno tests for whole-document validation, manufacturer parsing, merge behavior and publication failure. Implement `supabase/functions/refresh-club-catalog/` with a bounded, deterministic L.A.B. stock-putter adapter. Preserve unsupported and retired models; never infer golf-club variants from marketing names. Unsupported feeds require additional adapters.
3. Add `supabase/migrations/0005_club_catalog.sql`: public read/admin write Storage buckets, a service-only publication lease and run log, and daily cron calling the function with a Vault secret. Add a reproducible deployment/bootstrap command without embedding secrets.
4. Run `deno test`, importer tests and Xcode tests. Review the change, document coverage and operational behavior in `docs/data/club-catalog.md`, and deploy/verify the public object and scheduled job if the linked project can be restored.

User explicitly selected automatic publication after validation. No review queue is required. Existing uncommitted redesign work is preserved; commits are left to the user.
