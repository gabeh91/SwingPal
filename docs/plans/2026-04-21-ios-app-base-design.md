# SwingPal iOS App Base Design

## Goal

Create a clean SwiftUI-first iOS application base for `SwingPal`, a golf side-kick
targeting iOS 17. The scaffold should open in Xcode without extra generators, build
with `xcodebuild`, and leave obvious extension points for nearby course discovery,
shot tracking, and GPS-based distance features.

## Architecture

The app uses the SwiftUI app lifecycle with a single application target and a single
unit test target:

- `SwingPalApp.swift` owns app startup.
- `ContentView.swift` provides the initial root screen with golf-specific placeholder
  content.
- `AppIdentity.swift` holds a small shared constant so the test target can verify a
  real app module surface instead of a placeholder-only test.

## Project Shape

- Native Xcode project in `SwingPal.xcodeproj`
- App sources under `SwingPal/`
- Unit tests under `SwingPalTests/`
- Asset catalog with a default accent color
- Generated `Info.plist` via build settings to keep the scaffold small

## Verification

The scaffold is considered valid when:

1. The app target builds for the iOS simulator with `xcodebuild`
2. The test target builds against the app module
3. No external generators or package managers are required
