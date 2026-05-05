# 2026-04-22 Course Data App Infrastructure

## Goal

Create the app-side course domain before backend ingestion so SwingPal has a stable runtime model for:

- nearby course discovery
- round setup and live round context
- future OpenGolfAPI and OSM/Overpass imports
- community corrections and moderation

This keeps the iOS app, import pipeline, and later Supabase schema aligned around one normalized course shape.

## Sequencing Decision

App infrastructure comes before Supabase for this phase.

Reasoning:

- the app still needs a stable course model before backend tables are locked in
- provider payloads from OpenGolfAPI and OSM should not leak directly into UI code
- round setup and live round need one course source of truth now, even while data remains seeded
- the eventual Supabase schema should mirror the app domain, not define it prematurely

## Current App-Side Ownership Model

SwingPal should treat external sources as ingestion inputs only.

- `OpenGolfAPI`: course identity, tee metadata, scorecard structure
- `OSM / Overpass`: geometry candidates such as greens, bunkers, fairways, tees, water
- `SwingPalCourse`: the normalized runtime model used by the app

The app should read `SwingPalCourse`, not raw provider payloads.

## Initial Normalized Schema

The first app-side course model introduced in this phase is:

- `SwingPalCourse`
  - `id`
  - `name`
  - `distanceKilometers`
  - `holeCount`
  - `par`
  - `tees`
  - `holes`
- `SwingPalCourse.Tee`
  - `id`
  - `name`
  - `yards`
- `SwingPalCourse.Hole`
  - `id`
  - `number`
  - `par`
  - `features`
- `SwingPalCourse.Hole.Feature`
  - `id`
  - `kind`
  - `label`

This is intentionally lighter than the final import model, but it establishes the contract the UI can build against.

## Repository Boundary

The app now uses a repository boundary instead of ad hoc view-level course mocks:

- `CourseRepository`
  - `nearbyCourses() -> [SwingPalCourse]`
- `SeededCourseRepository`
  - current seeded implementation for app development

This means the round flow can continue to feel polished while the backing source remains local and deterministic.

## UI Integration Rule

Infrastructure work must not degrade the current premium round experience.

That means:

- `CourseListView` still drives a refined setup flow
- `CourseDetailView` still feels like a commitment screen, not a raw data viewer
- `RoundRootView` still owns transitions and live round handoff
- repository/data changes remain behind the UI layer

## Next App Infrastructure Slices

The next course-data slices should stay app-side before Supabase work:

1. Expand `SwingPalCourse`
   - add source metadata
   - add map coordinates
   - add confidence/state fields
2. Introduce correction-domain models
   - `CourseCorrectionDraft`
   - `CourseCorrectionKind`
   - `CourseCorrectionEvidence`
   - `CourseCorrectionStatus`
3. Introduce provider adapter protocols
   - `OpenGolfCourseLoading`
   - `OSMGeometryLoading`
   - keep seeded implementations locally first
4. Add a lightweight internal correction workflow surface
   - likely report/edit entry points from course detail or live round
   - keep it local first, then back it with Supabase

## Non-Goals For This Slice

- no Supabase SDK integration
- no real network import jobs
- no runtime dependency on OpenGolfAPI
- no runtime dependency on OSM/Overpass
- no admin dashboard yet

## Outcome

This phase gives SwingPal a clean app-owned course contract that can absorb open-source imports later without rewriting the round flow.
