import XCTest
@testable import SwingPal

@MainActor
final class AppStateTests: XCTestCase {
    func testInitialStateDefaultsToHomeGuestAndNoActiveRound() {
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: .starter), gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())

        XCTAssertEqual(state.selectedTab, .home)
        XCTAssertEqual(state.authState, .guest)
        XCTAssertEqual(state.gpsMode, .live)
        XCTAssertNil(state.activeRoundID)
    }

    func testActiveRoundStateCanBeStoredForResume() {
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: .starter), gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())
        let liveRound = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.activeRoundID = UUID()
        state.activeRoundState = liveRound

        XCTAssertNotNil(state.activeRoundState)
        XCTAssertEqual(state.activeRoundState?.hole.number, 1)
    }

    func testImmersiveRoundRequiresRoundTabLiveChromeAndActiveState() {
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: .starter), gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())
        let liveRound = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        XCTAssertFalse(state.isImmersiveRoundActive)

        state.activeRoundState = liveRound
        state.roundChromeMode = .live
        XCTAssertFalse(state.isImmersiveRoundActive)

        state.selectedTab = .round
        XCTAssertTrue(state.isImmersiveRoundActive)
    }

    func testInitializerRestoresPersistedActiveRoundFromStore() {
        let id = UUID()
        let snapshot = ActiveRoundSnapshot(
            id: id,
            chromeMode: .live,
            liveRound: LiveRoundState(
                hole: HoleSession(number: 3, par: 5),
                players: [.init(name: "You", kind: .selfPlayer)]
            ).snapshot
        )
        let store = StubActiveRoundStore(snapshot: snapshot)

        let state = AppState(store: store)

        XCTAssertEqual(state.activeRoundID, id)
        XCTAssertEqual(state.roundChromeMode, .live)
        XCTAssertEqual(state.activeRoundState?.hole.number, 3)
    }

    func testInitializerUsesInjectedLocationProviderFactoryWhenRestoringRound() {
        let id = UUID()
        let snapshot = ActiveRoundSnapshot(
            id: id,
            chromeMode: .live,
            liveRound: LiveRoundState(
                hole: HoleSession(number: 3, par: 5),
                players: [.init(name: "You", kind: .selfPlayer)]
            ).snapshot
        )
        let store = StubActiveRoundStore(snapshot: snapshot)

        let state = AppState(
            store: store,
            weatherLoaderFactory: { PreviewRoundWeatherLoader() },
            locationProviderFactory: { StubLocationProvider(status: .permissionDenied) }
        )

        XCTAssertEqual(state.activeRoundState?.playerLocationStatusText, "Location blocked • enable in Settings")
    }

    func testInitializerRestoresPersistedGPSMode() {
        let state = AppState(
            store: StubActiveRoundStore(),
            gpsModeStore: StubGPSModeStore(mode: .testPreview),
            appearanceModeStore: StubAppearanceModeStore()
        )

        XCTAssertEqual(state.gpsMode, .testPreview)
    }

    func testInitializerRestoresPersistedAppearanceMode() {
        let state = AppState(
            store: StubActiveRoundStore(),
            gpsModeStore: StubGPSModeStore(),
            appearanceModeStore: StubAppearanceModeStore(mode: .dark)
        )

        XCTAssertEqual(state.appearanceMode, .dark)
    }

    func testInitializerRestoresPersistedBag() {
        let restoredBag = Bag(clubs: [
            Club(name: "Driver", typicalDistanceMeters: 238, brand: "PING", family: "G440", source: .catalog),
            Club(name: "7I", typicalDistanceMeters: 152, brand: "PING", family: "Blueprint", source: .catalog)
        ])

        let state = AppState(
            store: StubActiveRoundStore(),
            bagStore: StubBagStore(bag: restoredBag),
            gpsModeStore: StubGPSModeStore(),
            appearanceModeStore: StubAppearanceModeStore()
        )

        XCTAssertEqual(state.bag, restoredBag)
    }

    func testLiveRoundKeepsDistinctSameNumberModelsAndRecognizesCustomPutters() {
        let clubs = [
            Club(name: "7I", typicalDistanceMeters: 145, brand: "PING", family: "i230", category: .iron),
            Club(name: "7i", typicalDistanceMeters: 155, brand: "Mizuno", family: "JPX", category: .iron),
            Club(name: "Scotty", typicalDistanceMeters: 10, category: .putter)
        ]
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: Bag(clubs: clubs)),
            gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())
        let carries = state.liveRoundClubCarryMetersByClubName
        XCTAssertEqual(carries["7I · PING • i230"], 145)
        XCTAssertEqual(carries["7i · Mizuno • JPX"], 155)
        XCTAssertEqual(carries["Scotty Putter"], 10)
        let recommendation = BagClubRecommendation.make(bag: Bag(clubs: clubs), playsLikeDistanceMeters: 10)
        XCTAssertNotEqual(recommendation.clubName, "Scotty")
    }

    func testActiveClubKeepsItsCarryWhenSameNumberModelsAreAddedAndRemoved() {
        let first = Club(name: "7I", typicalDistanceMeters: 145, brand: "PING", family: "i230")
        let second = Club(name: "7I", typicalDistanceMeters: 155, brand: "Mizuno", family: "JPX")
        let state = AppState(store: StubActiveRoundStore(), bagStore: StubBagStore(bag: Bag(clubs: [first])),
            gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())
        let round = LiveRoundState(hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)], clubCarryMetersByClubName: state.liveRoundClubCarryMetersByClubName)
        round.selectClub(named: "7I")
        state.resumeRound(id: UUID(), state: round, chromeMode: .live)
        state.addClubs([second])
        XCTAssertEqual(state.activeRoundState?.selectedClubWheelEntry.displayCarryMeters, 145)
        XCTAssertEqual(state.activeRoundState?.selectedClubName, "7I · PING • i230")
        state.activeRoundState?.selectClub(named: "7I · Mizuno • JPX")
        state.deleteClub(id: first.id)
        XCTAssertEqual(state.activeRoundState?.selectedClubWheelEntry.displayCarryMeters, 155)
        XCTAssertEqual(state.activeRoundState?.selectedClubName, "7I")
    }

    func testAddingSingleClubPersistsBag() {
        let bagStore = StubBagStore(bag: .init(clubs: []))
        let state = AppState(
            store: StubActiveRoundStore(),
            bagStore: bagStore,
            gpsModeStore: StubGPSModeStore(),
            appearanceModeStore: StubAppearanceModeStore()
        )
        let club = Club(name: "7I", typicalDistanceMeters: 150, brand: "Titleist", family: "T250", source: .catalog)

        state.addClubs([club])

        XCTAssertEqual(state.bag.clubs, [club])
        XCTAssertEqual(bagStore.savedBags.last, Bag(clubs: [club]))
    }

    func testAddingDuplicateClubsPreservesExistingCarryAndDistinctModels() {
        let owned = Club(name: "7I", typicalDistanceMeters: 145, brand: "PING", family: "i230", source: .catalog)
        let bagStore = StubBagStore(bag: Bag(clubs: [owned]))
        let state = AppState(store: StubActiveRoundStore(), bagStore: bagStore,
            gpsModeStore: StubGPSModeStore(), appearanceModeStore: StubAppearanceModeStore())
        let duplicate = Club(name: "7i", typicalDistanceMeters: 160, brand: "ping", family: "I230", source: .catalog)
        let different = Club(name: "7I", typicalDistanceMeters: 152, brand: "Mizuno", family: "JPX", source: .catalog)
        state.addClubs([duplicate, different, different])
        XCTAssertEqual(state.bag.clubs, [owned, different])
        XCTAssertEqual(bagStore.savedBags.last?.clubs, [owned, different])
    }

    func testAddingClubRefreshesActiveRoundClubContext() {
        let bagStore = StubBagStore(bag: .init(clubs: []))
        let state = AppState(
            store: StubActiveRoundStore(),
            bagStore: bagStore,
            gpsModeStore: StubGPSModeStore(),
            appearanceModeStore: StubAppearanceModeStore()
        )
        let liveRound = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.resumeRound(id: UUID(), state: liveRound, chromeMode: .live)
        state.addClubs([
            Club(name: "4H", typicalDistanceMeters: 190, brand: "PING", family: "G440", source: .catalog)
        ])

        XCTAssertEqual(state.activeRoundState?.availableClubNames, ["4H", "Driver"])
    }

    func testUpdatingClubPersistsEditedDistance() {
        let original = Club(name: "5W", typicalDistanceMeters: 205, brand: "TaylorMade", family: "Qi35", source: .catalog)
        let updated = Club(id: original.id, name: "5W", typicalDistanceMeters: 212, brand: "TaylorMade", family: "Qi35", source: .catalog)
        let bagStore = StubBagStore(bag: .init(clubs: [original]))
        let state = AppState(
            store: StubActiveRoundStore(),
            bagStore: bagStore,
            gpsModeStore: StubGPSModeStore(),
            appearanceModeStore: StubAppearanceModeStore()
        )

        state.updateClub(updated)

        XCTAssertEqual(state.bag.clubs, [updated])
        XCTAssertEqual(bagStore.savedBags.last, Bag(clubs: [updated]))
    }

    func testDeletingClubRemovesItFromBagAndPersists() {
        let first = Club(name: "5W", typicalDistanceMeters: 205, brand: "TaylorMade", family: "Qi35", source: .catalog)
        let second = Club(name: "7I", typicalDistanceMeters: 150, brand: "Titleist", family: "T250", source: .catalog)
        let bagStore = StubBagStore(bag: .init(clubs: [first, second]))
        let state = AppState(
            store: StubActiveRoundStore(),
            bagStore: bagStore,
            gpsModeStore: StubGPSModeStore(),
            appearanceModeStore: StubAppearanceModeStore()
        )

        state.deleteClub(id: first.id)

        XCTAssertEqual(state.bag.clubs, [second])
        XCTAssertEqual(bagStore.savedBags.last, Bag(clubs: [second]))
    }

    func testClubCatalogDocumentDecodesFamiliesFromJSONData() throws {
        let data = Data(
            """
            {
              "brands": ["Titleist", "TaylorMade"],
              "families": [
                {
                  "brand": "Titleist",
                  "name": "GT Drivers",
                  "category": "driver",
                  "variants": [
                    { "id": "1W", "code": "1W", "displayName": "Driver" }
                  ]
                },
                {
                  "brand": "TaylorMade",
                  "name": "P790",
                  "category": "iron",
                  "variants": [
                    { "id": "4I", "code": "4I", "displayName": "4I" },
                    { "id": "7I", "code": "7I", "displayName": "7I" }
                  ]
                }
              ]
            }
            """.utf8
        )

        let document = try ClubCatalogDocument.load(from: data)

        XCTAssertEqual(document.brands, ["Titleist", "TaylorMade"])
        XCTAssertEqual(document.families.count, 2)
        XCTAssertEqual(document.families(for: "TaylorMade").map(\.name), ["P790"])
        XCTAssertEqual(document.families(for: "TaylorMade").first?.variants.map(\.code), ["4I", "7I"])
    }

    func testMissingCatalogLeavesCustomEntryAvailableWithoutInventingModels() throws {
        let document = try ClubCatalogDocument.load(from: nil)
        XCTAssertTrue(document.brands.isEmpty)
        XCTAssertTrue(document.families.isEmpty)
        var selection = AddClubSelection(existingClubs: [])
        XCTAssertTrue(selection.addCustom(name: "7I", brand: "My maker", model: "My model",
                                         category: .iron, distanceText: "150", unit: .meters))
        XCTAssertEqual(selection.clubs?.first?.family, "My model")
    }

    func testClubAutoRecommendationDefaultsToEnabled() {
        let state = AppState(
            store: StubActiveRoundStore(),
            gpsModeStore: StubGPSModeStore(),
            appearanceModeStore: StubAppearanceModeStore(),
            clubAutoRecommendationPreferenceStore: StubClubAutoRecommendationPreferenceStore()
        )

        XCTAssertTrue(state.clubAutoRecommendationEnabled)
    }

    func testInitializerRestoresPersistedClubAutoRecommendationPreference() {
        let state = AppState(
            store: StubActiveRoundStore(),
            gpsModeStore: StubGPSModeStore(),
            appearanceModeStore: StubAppearanceModeStore(),
            clubAutoRecommendationPreferenceStore: StubClubAutoRecommendationPreferenceStore(isEnabled: false)
        )

        XCTAssertFalse(state.clubAutoRecommendationEnabled)
    }

    func testSetClubAutoRecommendationEnabledPersistsAndPropagatesToActiveRound() {
        let preferenceStore = StubClubAutoRecommendationPreferenceStore()
        let state = AppState(
            store: StubActiveRoundStore(),
            gpsModeStore: StubGPSModeStore(),
            appearanceModeStore: StubAppearanceModeStore(),
            clubAutoRecommendationPreferenceStore: preferenceStore
        )

        let liveRound = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.resumeRound(id: UUID(), state: liveRound, chromeMode: .live)

        state.setClubAutoRecommendationEnabled(false)

        XCTAssertFalse(state.clubAutoRecommendationEnabled)
        XCTAssertEqual(preferenceStore.savedValues.last, false)
        XCTAssertFalse(liveRound.isClubAutoRecommendationEnabled)
    }

    func testInWheelTogglePushesPreferenceUpToAppStateForPersistence() {
        let preferenceStore = StubClubAutoRecommendationPreferenceStore(isEnabled: true)
        let state = AppState(
            store: StubActiveRoundStore(),
            gpsModeStore: StubGPSModeStore(),
            appearanceModeStore: StubAppearanceModeStore(),
            clubAutoRecommendationPreferenceStore: preferenceStore
        )

        let liveRound = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.resumeRound(id: UUID(), state: liveRound, chromeMode: .live)

        // Simulate the user tapping the in-wheel "Auto / Manual" toggle.
        liveRound.toggleClubAutoRecommendation()

        XCTAssertFalse(state.clubAutoRecommendationEnabled)
        XCTAssertEqual(preferenceStore.savedValues.last, false)
    }

    func testTestPreviewGPSModeUsesPreviewLocationProvider() {
        let state = AppState(
            store: StubActiveRoundStore(),
            gpsModeStore: StubGPSModeStore(mode: .testPreview)
        )

        let provider = state.makeRoundLocationProvider()

        XCTAssertTrue(provider is PreviewRoundLocationProvider)
    }

    func testLiveGPSModeUsesInjectedLocationProviderFactory() {
        let state = AppState(
            store: StubActiveRoundStore(),
            gpsModeStore: StubGPSModeStore(mode: .live),
            locationProviderFactory: { StubLocationProvider(status: .permissionDenied) }
        )

        XCTAssertEqual(state.makeRoundLocationProvider().currentStatus, .permissionDenied)
    }

    func testChangingGPSModePersistsAndRebuildsActiveRoundWithPreviewLocation() throws {
        let store = StubActiveRoundStore()
        let gpsModeStore = StubGPSModeStore()
        let appearanceModeStore = StubAppearanceModeStore()
        let state = AppState(
            store: store,
            gpsModeStore: gpsModeStore,
            appearanceModeStore: appearanceModeStore,
            weatherLoaderFactory: { PreviewRoundWeatherLoader() },
            locationProviderFactory: { StubLocationProvider(status: .permissionDenied) }
        )
        let liveRound = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)],
            locationProvider: StubLocationProvider(status: .permissionDenied)
        )

        state.resumeRound(id: UUID(), state: liveRound, chromeMode: .live)
        state.setGPSMode(.testPreview)

        XCTAssertEqual(state.gpsMode, .testPreview)
        XCTAssertEqual(gpsModeStore.savedModes.last, .testPreview)
        XCTAssertEqual(state.activeRoundState?.playerLocationStatusText, "GPS ±8m • heading 32°")
        XCTAssertNotNil(store.savedSnapshots.last ?? nil)
    }

    func testChangingAppearanceModePersistsSelection() {
        let appearanceModeStore = StubAppearanceModeStore()
        let state = AppState(
            store: StubActiveRoundStore(),
            gpsModeStore: StubGPSModeStore(),
            appearanceModeStore: appearanceModeStore
        )

        state.setAppearanceMode(.dark)

        XCTAssertEqual(state.appearanceMode, .dark)
        XCTAssertEqual(appearanceModeStore.savedModes.last, .dark)
    }

    func testSigningInPromotesGuestStateToAuthenticated() {
        let state = AppState(
            store: StubActiveRoundStore(),
            gpsModeStore: StubGPSModeStore(),
            appearanceModeStore: StubAppearanceModeStore()
        )

        XCTAssertEqual(state.authState, .guest)

        state.completeSignIn()

        XCTAssertEqual(state.authState, .authenticated)
    }

    func testResumingActiveRoundPersistsSnapshotToStore() throws {
        let store = StubActiveRoundStore()
        let state = AppState(store: store)
        let id = UUID()
        let liveRound = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.resumeRound(id: id, state: liveRound, chromeMode: .live)
        let savedSnapshot = try XCTUnwrap(store.savedSnapshots.last ?? nil)

        XCTAssertEqual(savedSnapshot.id, id)
        XCTAssertEqual(savedSnapshot.chromeMode, .live)
        XCTAssertEqual(savedSnapshot.liveRound.hole.number, 1)
    }

    func testMutatingActiveRoundPersistsUpdatedSnapshot() throws {
        let store = StubActiveRoundStore()
        let state = AppState(store: store)
        let liveRound = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.resumeRound(id: UUID(), state: liveRound, chromeMode: .live)
        liveRound.logShot(clubName: "7i", distanceToTargetMeters: 152)
        let savedSnapshot = try XCTUnwrap(store.savedSnapshots.last ?? nil)

        XCTAssertEqual(savedSnapshot.liveRound.hole.shots.count, 1)
        XCTAssertEqual(savedSnapshot.liveRound.reviewPlayers.first?.strokes, 1)
    }

    func testResumingActiveRoundPublishesCompanionSnapshotThroughAppStateBinding() {
        let sync = RecordingRoundCompanionSync()
        let state = AppState(
            store: StubActiveRoundStore(),
            roundCompanionSync: sync
        )
        let liveRound = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.resumeRound(id: UUID(), state: liveRound, chromeMode: .live)
        liveRound.selectClub(named: "5i")

        XCTAssertEqual(sync.lastSnapshot?.holeNumber, 1)
        XCTAssertEqual(sync.lastSnapshot?.selectedClubName, "5i")
    }

    func testInitializerBindsCompanionSnapshotToRestoredRound() {
        let sync = RecordingRoundCompanionSync()
        let snapshot = ActiveRoundSnapshot(
            id: UUID(),
            chromeMode: .live,
            liveRound: LiveRoundState(
                hole: HoleSession(number: 3, par: 5),
                players: [.init(name: "You", kind: .selfPlayer)]
            ).snapshot
        )
        let store = StubActiveRoundStore(snapshot: snapshot)

        let state = AppState(
            store: store,
            roundCompanionSync: sync
        )

        state.activeRoundState?.selectClub(named: "6i")

        XCTAssertEqual(sync.lastSnapshot?.holeNumber, 3)
        XCTAssertEqual(sync.lastSnapshot?.selectedClubName, "6i")
    }

    func testInitializerPublishesRestoredCompanionSnapshotOnlyOnce() {
        let sync = RecordingRoundCompanionSync()
        let snapshot = ActiveRoundSnapshot(
            id: UUID(),
            chromeMode: .live,
            liveRound: LiveRoundState(
                hole: HoleSession(number: 3, par: 5),
                players: [.init(name: "You", kind: .selfPlayer)]
            ).snapshot
        )

        _ = AppState(
            store: StubActiveRoundStore(snapshot: snapshot),
            roundCompanionSync: sync
        )

        XCTAssertEqual(sync.publishedSnapshots.count, 1)
        XCTAssertEqual(sync.lastSnapshot?.holeNumber, 3)
    }

    func testHandleRoundCompanionActionRoutesToActiveRound() {
        let sync = RecordingRoundCompanionSync()
        let state = AppState(
            store: StubActiveRoundStore(),
            roundCompanionSync: sync
        )

        state.resumeRound(
            id: UUID(),
            state: LiveRoundState(
                hole: HoleSession(number: 1, par: 4),
                players: [.init(name: "You", kind: .selfPlayer)]
            ),
            chromeMode: .live
        )

        state.handleRoundCompanionAction(.changeClub(name: "7i"))

        XCTAssertEqual(state.activeRoundState?.selectedClubName, "7i")
        XCTAssertEqual(sync.lastSnapshot?.lastMutationSource, .watch)
    }

    func testHandleRoundCompanionActionDropsSafelyWhenNoActiveRoundExists() {
        let sync = RecordingRoundCompanionSync()
        let state = AppState(
            store: StubActiveRoundStore(),
            roundCompanionSync: sync
        )

        state.handleRoundCompanionAction(.changeClub(name: "7i"))

        XCTAssertNil(state.activeRoundState)
        XCTAssertTrue(sync.publishedSnapshots.isEmpty)
    }

    func testAppStateWiresIncomingTransportActionsIntoRoundHandling() {
        let transport = RecordingRoundCompanionTransport()
        let state = AppState(
            store: StubActiveRoundStore(),
            roundCompanionSync: transport
        )

        state.resumeRound(
            id: UUID(),
            state: LiveRoundState(
                hole: HoleSession(number: 1, par: 4),
                players: [.init(name: "You", kind: .selfPlayer)]
            ),
            chromeMode: .live
        )

        transport.deliverIncomingAction(.changeClub(name: "7i"))

        XCTAssertEqual(state.activeRoundState?.selectedClubName, "7i")
        XCTAssertEqual(transport.lastSnapshot?.selectedClubName, "7i")
    }

    func testClearingActiveRoundRemovesPersistedSnapshot() {
        let sync = RecordingRoundCompanionSync()
        let store = StubActiveRoundStore()
        let state = AppState(
            store: store,
            roundCompanionSync: sync
        )

        state.resumeRound(
            id: UUID(),
            state: LiveRoundState(
                hole: HoleSession(number: 1, par: 4),
                players: [.init(name: "You", kind: .selfPlayer)]
            ),
            chromeMode: .live
        )
        state.clearActiveRound()

        XCTAssertNil(store.savedSnapshots.last!)
        XCTAssertNil(state.activeRoundID)
        XCTAssertNil(state.activeRoundState)
        XCTAssertNil(sync.lastSnapshot)
        XCTAssertEqual(sync.clearCount, 1)
    }

    func testSuspendingActiveRoundPersistsSetupChromeAndKeepsResumableHistorySummary() throws {
        let store = StubActiveRoundStore()
        let historyStore = StubRoundHistoryStore()
        let state = AppState(
            store: store,
            roundHistoryStore: historyStore
        )
        let roundID = UUID()
        let liveRound = LiveRoundState(
            hole: HoleSession(number: 2, par: 4),
            courseName: "Royal Melbourne",
            courseHoles: [
                .init(number: 1, par: 4, features: []),
                .init(number: 2, par: 4, features: []),
                .init(number: 3, par: 5, features: [])
            ],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.resumeRound(id: roundID, state: liveRound, chromeMode: .live)
        liveRound.logShot(
            clubName: "Driver",
            distanceToTargetMeters: 230,
            penaltyCount: 1
        )
        liveRound.logShot(
            clubName: "Putter",
            distanceToTargetMeters: 9,
            shotType: .putt,
            puttDetail: .init(puttCount: 2, firstPuttDistanceMeters: 9)
        )
        var draft = liveRound.makeCurrentHoleEditDraft()
        draft.score = 5
        draft.putts = 2
        draft.penaltyCount = 1
        draft.dropCount = 0
        liveRound.applyCurrentHoleEditDraft(draft)
        state.suspendActiveRound()

        let savedSnapshot = try XCTUnwrap(store.savedSnapshots.last ?? nil)
        let savedSummary = try XCTUnwrap((historyStore.savedSnapshots.last ?? nil)?.first)

        XCTAssertEqual(state.activeRoundID, roundID)
        XCTAssertNotNil(state.activeRoundState)
        XCTAssertEqual(state.roundChromeMode, .setup)
        XCTAssertEqual(savedSnapshot.chromeMode, .setup)
        XCTAssertEqual(savedSummary.id, roundID)
        XCTAssertEqual(savedSummary.status, .unfinished)
        XCTAssertEqual(savedSummary.courseName, "Royal Melbourne")
        XCTAssertEqual(savedSummary.holeNumber, 2)
        XCTAssertEqual(savedSummary.totalHoleCount, 3)
        XCTAssertEqual(savedSummary.totalStrokes, 5)
        XCTAssertEqual(savedSummary.completedHoleCount, 0)
        XCTAssertEqual(savedSummary.totalPutts, 2)
        XCTAssertEqual(savedSummary.totalPenalties, 1)
        XCTAssertEqual(state.previousRounds.first?.id, roundID)
    }

    func testCompletingIncompleteRoundRetainsResumableDraftAndActualProgress() throws {
        let store = StubActiveRoundStore()
        let historyStore = StubRoundHistoryStore()
        let state = AppState(store: store, roundHistoryStore: historyStore)
        let roundID = UUID()
        let liveRound = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseHoles: [
                .init(number: 1, par: 4, features: []),
                .init(number: 2, par: 3, features: [])
            ],
            players: [.init(name: "You", kind: .selfPlayer)]
        )
        state.resumeRound(id: roundID, state: liveRound, chromeMode: .live)
        liveRound.presentHoleConfirmation()
        liveRound.setPendingHoleScore(5)
        XCTAssertTrue(liveRound.confirmCurrentHole())
        liveRound.logShot(clubName: "7i", distanceToTargetMeters: 130)

        state.completeActiveRound()

        XCTAssertEqual(state.activeRoundID, roundID)
        XCTAssertNotNil(store.savedSnapshots.last ?? nil)
        XCTAssertEqual(state.previousRounds.first?.status, .unfinished)
        XCTAssertEqual(state.previousRounds.first?.completedHoleCount, 1)
        XCTAssertEqual(state.previousRounds.first?.totalStrokes, 6)
    }

    func testCompletingActiveRoundArchivesFinishedSummaryAndClearsActiveState() throws {
        let store = StubActiveRoundStore()
        let historyStore = StubRoundHistoryStore()
        let state = AppState(
            store: store,
            roundHistoryStore: historyStore
        )
        let roundID = UUID()
        let liveRound = LiveRoundState(
            hole: HoleSession(number: 1, par: 4),
            courseName: "Kingston Heath",
            courseHoles: [
                .init(number: 1, par: 4, features: []),
                .init(number: 2, par: 3, features: []),
                .init(number: 3, par: 5, features: []),
            ],
            players: [.init(name: "You", kind: .selfPlayer)]
        )

        state.resumeRound(id: roundID, state: liveRound, chromeMode: .live)
        for score in [4, 3, 5] {
            liveRound.presentHoleConfirmation()
            liveRound.setPendingHoleScore(score)
            XCTAssertTrue(liveRound.confirmCurrentHole())
        }
        state.completeActiveRound()

        let savedSummary = try XCTUnwrap((historyStore.savedSnapshots.last ?? nil)?.first)

        XCTAssertNil(store.savedSnapshots.last!)
        XCTAssertNil(state.activeRoundID)
        XCTAssertNil(state.activeRoundState)
        XCTAssertEqual(state.roundChromeMode, .setup)
        XCTAssertEqual(savedSummary.id, roundID)
        XCTAssertEqual(savedSummary.status, .finished)
        XCTAssertEqual(savedSummary.courseName, "Kingston Heath")
        XCTAssertEqual(savedSummary.holeNumber, 3)
        XCTAssertEqual(savedSummary.totalHoleCount, 3)
        XCTAssertEqual(savedSummary.totalStrokes, 12)
        XCTAssertEqual(savedSummary.completedHoleCount, 3)
        XCTAssertEqual(state.previousRounds.first?.status, .finished)
    }
}

private final class StubActiveRoundStore: ActiveRoundStoring {
    var savedSnapshots: [ActiveRoundSnapshot?] = []
    private let initialSnapshot: ActiveRoundSnapshot?

    init(snapshot: ActiveRoundSnapshot? = nil) {
        initialSnapshot = snapshot
    }

    func loadActiveRound() -> ActiveRoundSnapshot? {
        initialSnapshot
    }

    func saveActiveRound(_ snapshot: ActiveRoundSnapshot?) {
        savedSnapshots.append(snapshot)
    }
}

private final class StubRoundHistoryStore: RoundHistoryStoring {
    var savedSnapshots: [[RoundHistorySummary]?] = []
    private let initialSummaries: [RoundHistorySummary]

    init(summaries: [RoundHistorySummary] = []) {
        initialSummaries = summaries
    }

    func loadRoundHistory() -> [RoundHistorySummary] {
        initialSummaries
    }

    func saveRoundHistory(_ summaries: [RoundHistorySummary]) {
        savedSnapshots.append(summaries)
    }
}

private final class StubBagStore: BagStoring {
    private let initialBag: Bag
    private(set) var savedBags: [Bag] = []

    init(bag: Bag = .starter) {
        initialBag = bag
    }

    func loadBag() -> Bag {
        initialBag
    }

    func saveBag(_ bag: Bag) {
        savedBags.append(bag)
    }
}

private final class StubLocationProvider: RoundLocationProviding {
    var currentSnapshot: RoundLocationSnapshot?
    var currentStatus: RoundLocationStatus

    init(status: RoundLocationStatus) {
        currentStatus = status
    }

    func setUpdateHandler(_ handler: @escaping (RoundLocationSnapshot) -> Void) {}

    func setStatusHandler(_ handler: @escaping (RoundLocationStatus) -> Void) {}

    func startUpdating() {}

    func stopUpdating() {}
}

private final class StubGPSModeStore: GPSModeStoring {
    private let initialMode: AppGPSMode
    private(set) var savedModes: [AppGPSMode] = []

    init(mode: AppGPSMode = .live) {
        initialMode = mode
    }

    func loadGPSMode() -> AppGPSMode {
        initialMode
    }

    func saveGPSMode(_ mode: AppGPSMode) {
        savedModes.append(mode)
    }
}

private final class StubAppearanceModeStore: AppearanceModeStoring {
    private let initialMode: AppAppearanceMode
    private(set) var savedModes: [AppAppearanceMode] = []

    init(mode: AppAppearanceMode = .system) {
        initialMode = mode
    }

    func loadAppearanceMode() -> AppAppearanceMode {
        initialMode
    }

    func saveAppearanceMode(_ mode: AppAppearanceMode) {
        savedModes.append(mode)
    }
}

private final class StubClubAutoRecommendationPreferenceStore: ClubAutoRecommendationPreferenceStoring {
    private let initialValue: Bool
    private(set) var savedValues: [Bool] = []

    init(isEnabled: Bool = true) {
        initialValue = isEnabled
    }

    func loadClubAutoRecommendationEnabled() -> Bool {
        initialValue
    }

    func saveClubAutoRecommendationEnabled(_ isEnabled: Bool) {
        savedValues.append(isEnabled)
    }
}

final class RecordingRoundCompanionSync: RoundCompanionSyncing {
    private(set) var publishedSnapshots: [RoundCompanionSnapshot] = []
    private(set) var clearCount = 0

    var lastSnapshot: RoundCompanionSnapshot? {
        publishedSnapshots.last
    }

    func publish(snapshot: RoundCompanionSnapshot) {
        publishedSnapshots.append(snapshot)
    }

    func clear() {
        clearCount += 1
        publishedSnapshots.removeAll()
    }
}

final class RecordingRoundCompanionTransport: RoundCompanionSyncing, RoundCompanionActionReceiving {
    private(set) var publishedSnapshots: [RoundCompanionSnapshot] = []
    private var actionHandler: ((RoundCompanionAction) -> Void)?

    var lastSnapshot: RoundCompanionSnapshot? {
        publishedSnapshots.last
    }

    func publish(snapshot: RoundCompanionSnapshot) {
        publishedSnapshots.append(snapshot)
    }

    func clear() {
        publishedSnapshots.removeAll()
    }

    func setIncomingActionHandler(_ handler: @escaping (RoundCompanionAction) -> Void) {
        actionHandler = handler
    }

    func deliverIncomingAction(_ action: RoundCompanionAction) {
        actionHandler?(action)
    }
}
