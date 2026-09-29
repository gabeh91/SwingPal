import XCTest
@testable import SwingPal

final class ProfileViewModelTests: XCTestCase {
    func testGuestFreeModelFramesProfileAroundSavingAndPremiumUpgrade() {
        let model = ProfileViewModel(
            authState: .guest,
            entitlements: .free,
            bag: Bag(clubs: [
                Club(name: "Driver", typicalDistanceMeters: 235),
                Club(name: "7i", typicalDistanceMeters: 150),
                Club(name: "PW", typicalDistanceMeters: 115)
            ]),
            gpsMode: .live
        )

        XCTAssertEqual(model.statusTitle, "Guest Mode")
        XCTAssertEqual(model.identityTitle, "Guest profile")
        XCTAssertEqual(model.gpsModeSubtitle, "Use your real on-course location for live yardages and planning.")
    }

    func testPremiumAuthenticatedModelReframesActionsAroundAccess() {
        let model = ProfileViewModel(
            authState: .authenticated,
            entitlements: .premium,
            bag: Bag(clubs: [
                Club(name: "Driver", typicalDistanceMeters: 235),
                Club(name: "3W", typicalDistanceMeters: 210),
                Club(name: "5i", typicalDistanceMeters: 175),
                Club(name: "7i", typicalDistanceMeters: 150)
            ]),
            gpsMode: .testPreview
        )

        XCTAssertEqual(model.statusTitle, "Signed In")
        XCTAssertEqual(model.identityTitle, "Your profile")
        XCTAssertEqual(model.gpsModeSubtitle, "Keep the live round pinned to the stable preview location while you build and QA.")
    }

    func testPreviousRoundSheetModelFramesUnfinishedRoundForSummarySheet() {
        let summary = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .unfinished,
            holeNumber: 7,
            totalHoleCount: 18,
            playerCount: 2,
            totalStrokes: 27,
            completedHoleCount: 4,
            totalPutts: 8,
            totalPenalties: 2,
            updatedAt: .distantPast
        )

        let model = ProfileViewModel.previousRoundSheetModel(for: summary)

        XCTAssertEqual(model.title, "Royal Melbourne")
        XCTAssertEqual(model.statusTitle, "Saved to Resume")
        XCTAssertEqual(model.statusDetail, "This round was saved before it was finished.")
        XCTAssertEqual(model.progressTitle, "Hole 7 of 18")
        XCTAssertEqual(model.playersTitle, "2 golfers")
        XCTAssertEqual(model.strokesTitle, "27 strokes logged")
        XCTAssertEqual(model.holesCompletedTitle, "4 holes completed")
        XCTAssertEqual(model.puttsTitle, "8 putts tracked")
        XCTAssertEqual(model.penaltiesTitle, "2 penalties")
    }

    func testPreviousRoundAnalysisModelHighlightsStrengthsAndImprovementAreas() {
        let summary = RoundHistorySummary(
            id: UUID(),
            courseName: "Royal Melbourne",
            status: .unfinished,
            holeNumber: 7,
            totalHoleCount: 18,
            playerCount: 1,
            totalStrokes: 27,
            completedHoleCount: 4,
            totalPutts: 6,
            totalPenalties: 2,
            updatedAt: .distantPast
        )

        let model = ProfileViewModel.previousRoundAnalysisModel(for: summary)

        XCTAssertEqual(model.heading, "Round insights")
        XCTAssertEqual(model.summary, "This saved round captured enough scoring context to show where the round was trending before you stopped.")
        XCTAssertEqual(model.strengths.count, 3)
        XCTAssertEqual(model.improvements.count, 3)
        XCTAssertEqual(model.strengths.first, "You completed 4 holes before saving, giving the round a useful scoring baseline.")
        XCTAssertEqual(model.improvements.first, "2 penalty strokes were logged, so keeping the next ball in play is the clearest scoring gain.")
    }

    func testPreviousRoundAnalysisModelCanBeBuiltFromCachedAnalysis() {
        let analysis = RoundSummaryAnalysis(
            roundID: UUID(),
            cacheKey: "cache-key",
            provider: .foundationModels,
            summary: "Your round stayed stable through the saved holes.",
            whatWentWell: ["Short-game logging stayed sharp", "Penalty damage stayed manageable"],
            needsWork: ["Keep the ball in play off the tee", "Convert more saved holes into confirmed holes"],
            generatedAt: .distantPast,
            updatedAt: nil
        )

        let model = ProfileViewModel.previousRoundAnalysisModel(for: analysis)

        XCTAssertEqual(model.heading, "Round insights")
        XCTAssertEqual(model.summary, "Your round stayed stable through the saved holes.")
        XCTAssertEqual(model.strengths.count, 2)
        XCTAssertEqual(model.improvements.count, 2)
    }

    func testPreviousRoundAnalysisModelFiltersBlankBulletItems() {
        let analysis = RoundSummaryAnalysis(
            roundID: UUID(),
            cacheKey: "cache-key",
            provider: .foundationModels,
            summary: "Your round stayed stable through the saved holes.",
            whatWentWell: ["Short-game logging stayed sharp", "", "Penalty damage stayed manageable", " "],
            needsWork: ["", "Keep the ball in play off the tee", " ", "Convert more saved holes into confirmed holes"],
            generatedAt: .distantPast,
            updatedAt: nil
        )

        let model = ProfileViewModel.previousRoundAnalysisModel(for: analysis)

        XCTAssertEqual(model.strengths, ["Short-game logging stayed sharp", "Penalty damage stayed manageable"])
        XCTAssertEqual(model.improvements, ["Keep the ball in play off the tee", "Convert more saved holes into confirmed holes"])
    }

    func testAnalysisActionLabelsReflectIdleLoadingAndReadyStates() {
        XCTAssertEqual(ProfileViewModel.previousRoundAnalysisButtonTitle(for: .idle), "View Analysis")
        XCTAssertEqual(ProfileViewModel.previousRoundAnalysisButtonTitle(for: .loading), "Analyzing…")

        let ready = RoundSummaryAnalysis(
            roundID: UUID(),
            cacheKey: "cache-key",
            provider: .deterministic,
            summary: "Ready",
            whatWentWell: ["One", "Two"],
            needsWork: ["Three", "Four"],
            generatedAt: .distantPast,
            updatedAt: nil
        )
        XCTAssertEqual(ProfileViewModel.previousRoundAnalysisButtonTitle(for: .ready(ready)), "Analysis Ready")
    }

    func testAnalysisActionDisablesButtonWhenLoadingOrReady() {
        XCTAssertFalse(ProfileViewModel.previousRoundAnalysisButtonIsDisabled(for: .idle))
        XCTAssertTrue(ProfileViewModel.previousRoundAnalysisButtonIsDisabled(for: .loading))

        let ready = RoundSummaryAnalysis(
            roundID: UUID(),
            cacheKey: "cache-key",
            provider: .deterministic,
            summary: "Ready",
            whatWentWell: ["One", "Two"],
            needsWork: ["Three", "Four"],
            generatedAt: .distantPast,
            updatedAt: nil
        )
        XCTAssertTrue(ProfileViewModel.previousRoundAnalysisButtonIsDisabled(for: .ready(ready)))
    }

    func testCachedAnalysisShouldAutoPresentWhenReady() {
        XCTAssertFalse(ProfileViewModel.previousRoundAnalysisShouldBePresented(for: .idle))
        XCTAssertFalse(ProfileViewModel.previousRoundAnalysisShouldBePresented(for: .loading))

        let ready = RoundSummaryAnalysis(
            roundID: UUID(),
            cacheKey: "cache-key",
            provider: .foundationModels,
            summary: "Ready",
            whatWentWell: ["One", "Two"],
            needsWork: ["Three", "Four"],
            generatedAt: .distantPast,
            updatedAt: nil
        )
        XCTAssertTrue(ProfileViewModel.previousRoundAnalysisShouldBePresented(for: .ready(ready)))
    }

    func testAnalysisActionUsesAnimatedGlyphOnlyWhileLoading() {
        XCTAssertFalse(ProfileViewModel.previousRoundAnalysisShowsLoadingGlyph(for: .idle))
        XCTAssertTrue(ProfileViewModel.previousRoundAnalysisShowsLoadingGlyph(for: .loading))

        let ready = RoundSummaryAnalysis(
            roundID: UUID(),
            cacheKey: "cache-key",
            provider: .foundationModels,
            summary: "Ready",
            whatWentWell: ["One", "Two"],
            needsWork: ["Three", "Four"],
            generatedAt: .distantPast,
            updatedAt: nil
        )
        XCTAssertFalse(ProfileViewModel.previousRoundAnalysisShowsLoadingGlyph(for: .ready(ready)))
    }

}

final class AddClubFlowTests: XCTestCase {
    private let irons = ClubCatalogFamily(brand: "PING", name: "i230", category: .iron,
        variants: [.init(code: "6I"), .init(code: "7I")])
    private let wedge = ClubCatalogFamily(brand: "Titleist", name: "Vokey SM10", category: .wedge,
        variants: [.init(code: "56°")])

    func testSuggestedCustomDetailsDoNotCreateAnUnfinishedDraft() {
        var custom = AddCustomClubForm()
        custom.suggest(irons)
        XCTAssertEqual(custom.maker, "PING")
        XCTAssertEqual(custom.model, "i230")
        XCTAssertFalse(custom.hasChanges)

        custom.suggest(wedge)
        XCTAssertEqual(custom.model, "Vokey SM10")
        XCTAssertEqual(custom.category, .wedge)
        XCTAssertFalse(custom.hasChanges)
    }

    func testCustomEditsRemainUntilExplicitlyCleared() {
        var custom = AddCustomClubForm()
        custom.suggest(irons)
        custom.name = "5I"
        custom.carry = "180"
        custom.suggest(wedge)
        XCTAssertEqual(custom.model, "i230")
        XCTAssertEqual(custom.name, "5I")
        XCTAssertTrue(custom.hasChanges)
        custom.clear()
        XCTAssertFalse(custom.hasChanges)
        XCTAssertTrue(custom.name.isEmpty)
    }

    func testPendingCustomDraftDoesNotHijackCatalogReviewOrSave() {
        XCTAssertEqual(AddClubPrimaryAction.resolve(isReview: false, isCustomPage: false, hasCustomChanges: true), .review)
        XCTAssertEqual(AddClubPrimaryAction.resolve(isReview: true, isCustomPage: false, hasCustomChanges: true), .addSelected)
        XCTAssertEqual(AddClubPrimaryAction.resolve(isReview: false, isCustomPage: true, hasCustomChanges: true), .stageCustom)
    }

    func testSearchCombinesMakerModelAndClubNumberAcrossFields() {
        let document = ClubCatalogDocument(brands: ["PING", "Titleist"], families: [irons, wedge])
        XCTAssertEqual(document.search(query: " ping i-230 7 iron ").map(\.id), [irons.id])
        XCTAssertEqual(document.search(query: "SM10 56").map(\.id), [wedge.id])
        XCTAssertTrue(document.search(query: "PING SM10").isEmpty)
    }

    func testSearchComposesCategoryAndMakerFiltersAndHandlesEmptyQuery() {
        let document = ClubCatalogDocument(brands: [], families: [irons, wedge])
        XCTAssertEqual(document.search(query: "  ").count, 2)
        XCTAssertEqual(document.search(query: "", category: .wedge).map(\.id), [wedge.id])
        XCTAssertTrue(document.search(query: "i230", brand: "Titleist").isEmpty)
        XCTAssertEqual(document.search(query: "56", category: .wedge, brand: "Titleist").count, 1)
    }

    func testSelectionKeepsClubsFromDifferentModelsAndCustomEntry() {
        var selection = AddClubSelection(existingClubs: [])
        selection.toggle(family: irons, variant: irons.variants[1], unit: .yards)
        selection.drafts[0].distanceText = "170"
        selection.toggle(family: wedge, variant: wedge.variants[0], unit: .yards)
        XCTAssertTrue(selection.addCustom(name: "Driving iron", brand: "Mizuno", model: "Old favourite", category: .utilityIron, distanceText: "210", unit: .yards))
        XCTAssertEqual(selection.drafts.map(\.name), ["7I", "56°", "Driving iron"])
        XCTAssertEqual(selection.drafts[0].distanceText, "170")
        XCTAssertEqual(selection.clubs?.first?.typicalDistanceMeters, 155)
        selection.toggle(family: wedge, variant: wedge.variants[0], unit: .yards)
        XCTAssertEqual(selection.drafts.count, 2)
    }

    func testAlreadyOwnedCatalogClubCannotBeSelectedAgain() {
        let owned = Club(name: "7I", typicalDistanceMeters: 149, brand: "PING", family: "i230", source: .catalog)
        var selection = AddClubSelection(existingClubs: [owned])
        selection.toggle(family: irons, variant: irons.variants[1], unit: .meters)
        XCTAssertTrue(selection.drafts.isEmpty)
        XCTAssertTrue(selection.isOwned(family: irons, variant: irons.variants[1]))
    }

    func testCustomDuplicateDoesNotReplaceEarlierSelectionOrCarry() {
        var selection = AddClubSelection(existingClubs: [])
        XCTAssertTrue(selection.addCustom(name: "  7I ", brand: "PING", model: "i230", category: .iron, distanceText: "150", unit: .meters))
        XCTAssertFalse(selection.addCustom(name: "7i", brand: " ping ", model: "I230", category: .iron, distanceText: "160", unit: .meters))
        XCTAssertEqual(selection.clubs?.count, 1)
        XCTAssertEqual(selection.clubs?.first?.typicalDistanceMeters, 150)
    }

    func testCarryInputConvertsYardsAndRejectsInvalidOrExcessiveValues() {
        XCTAssertEqual(ClubCarryInput.meters(from: " 150 ", unit: .yards), 137)
        XCTAssertEqual(ClubCarryInput.meters(from: "150", unit: .meters), 150)
        XCTAssertEqual(ClubCarryInput.text(meters: 150, unit: .yards), "164")
        for text in ["", "0", "-1", "abc", "1.5", "999999999999999999999", "501"] {
            XCTAssertNil(ClubCarryInput.meters(from: text, unit: .meters), text)
        }
        XCTAssertNil(ClubCarryInput.meters(from: "550", unit: .yards))
    }

    func testInvalidReviewCarryPreventsPartialCommit() {
        var selection = AddClubSelection(existingClubs: [])
        selection.toggle(family: irons, variant: irons.variants[0], unit: .meters)
        selection.toggle(family: irons, variant: irons.variants[1], unit: .meters)
        selection.drafts[1].distanceText = "0"
        XCTAssertNil(selection.clubs)
        XCTAssertTrue(selection.hasChanges)
        selection.drafts.removeAll()
        XCTAssertNil(selection.clubs)
        XCTAssertFalse(selection.hasChanges)
    }

    func testPutterCanBeAddedWithoutInventingAFullSwingCarry() {
        var selection = AddClubSelection(existingClubs: [])
        XCTAssertTrue(selection.addCustom(name: "My blade", brand: "", model: "", category: .putter, distanceText: "", unit: .meters))
        XCTAssertEqual(selection.clubs?.first?.category, .putter)
        XCTAssertEqual(selection.clubs?.first?.isPutter, true)
    }

    func testExplicitIronCategoryOverridesLegacyPutterName() {
        let iron = Club(name: "Blade", typicalDistanceMeters: 155, category: .iron)
        XCTAssertFalse(iron.isPutter)
    }

    func testLegacyClubDecodesWithoutCategoryAndRetainsID() throws {
        let old = Club(name: "7I", typicalDistanceMeters: 150)
        let data = try JSONEncoder().encode(old)
        let decoded = try JSONDecoder().decode(Club.self, from: data)
        XCTAssertEqual(decoded, old)
        XCTAssertNil(decoded.category)
    }
}

final class ManufacturerCatalogTests: XCTestCase {
    func testBrandModelVersionHierarchyPreservesEveryCatalogClub() throws {
        let catalog = try XCTUnwrap(ClubCatalogLoader.loadBundled())
        let brands = ClubCatalogBrandSection.alphabetical(catalog.families).flatMap(\.brands)
        XCTAssertEqual(Set(brands.map(\.name)), Set(catalog.brands))
        let models = brands.flatMap { ClubCatalogModelGroup.grouped($0.families) }
        let families = models.flatMap(\.families)
        XCTAssertEqual(families.count, catalog.families.count)
        XCTAssertEqual(Set(families.map(\.id)), Set(catalog.families.map(\.id)))

        let ping = try XCTUnwrap(models.first { $0.brand == "PING" && $0.name == "G440" })
        let max = try XCTUnwrap(ping.families.first { $0.name == "G440 MAX Driver" })
        XCTAssertEqual(ping.versionName(max), "MAX")
        XCTAssertTrue(ping.families.contains { $0.name == "G440 LST Driver" })
        XCTAssertTrue(ping.families.contains { $0.name == "G440 SFT Driver" })
        XCTAssertFalse(ping.families.contains { $0.name.contains("G430") })
        let elyte = try XCTUnwrap(models.first { $0.brand == "Callaway" && $0.name == "Elyte" })
        XCTAssertTrue(elyte.families.contains { $0.name == "Elyte Triple Diamond Driver" })
        XCTAssertTrue(models.contains { $0.brand == "XXIO" && $0.name == "14+" })
        XCTAssertTrue(models.contains { $0.brand == "XXIO" && $0.name == "14" })
    }

    func testHierarchySearchKeepsOnlyMatchingVersionsAndSavedModelIdentity() throws {
        let catalog = try XCTUnwrap(ClubCatalogLoader.loadBundled())
        let matches = catalog.search(query: "PING G440 LST", category: .driver)
        let brands = ClubCatalogBrandSection.alphabetical(matches).flatMap(\.brands)
        XCTAssertEqual(brands.map(\.name), ["PING"])
        let models = ClubCatalogModelGroup.grouped(try XCTUnwrap(brands.first).families)
        XCTAssertEqual(models.map(\.name), ["G440"])
        let family = try XCTUnwrap(models.first?.families.first)
        XCTAssertEqual(family.name, "G440 LST Driver")
        var selection = AddClubSelection(existingClubs: [])
        selection.toggle(family: family, variant: try XCTUnwrap(family.variants.first), unit: .meters)
        XCTAssertEqual(selection.clubs?.first?.family, "G440 LST Driver")
        XCTAssertTrue(ClubCatalogBrandSection.alphabetical(catalog.search(query: "not-a-real-model-xyz")).isEmpty)
    }

    func testUnknownModelNamesRemainSeparate() {
        let families = ["Future One", "Future Two"].map {
            ClubCatalogFamily(brand: "PING", name: $0, category: .driver, variants: [.init(code: "Driver")])
        }
        XCTAssertEqual(ClubCatalogModelGroup.grouped(families).map(\.name), ["Future One", "Future Two"])
    }

    func testBundledCatalogContainsSpecificModelsAndPublishedClubRanges() throws {
        let catalog = try XCTUnwrap(ClubCatalogLoader.loadBundled())
        let ping = try XCTUnwrap(catalog.search(query: "PING G440", category: .iron).first)
        XCTAssertEqual(ping.variants.map(\.code), ["4I", "5I", "6I", "7I", "8I", "9I", "PW", "UW", "52°", "56°"])
        let cobra = try XCTUnwrap(catalog.search(query: "Cobra DS ADAPT MAX", category: .fairwayWood).first)
        XCTAssertEqual(cobra.variants.map(\.code), ["3W", "5W", "7W", "9W"])
        XCTAssertFalse(catalog.families.contains { $0.name == "T-Series Irons" })
        XCTAssertFalse(catalog.families.contains { $0.name == "Blueprint Irons" })
    }

    func testRealPutterModelAddsOnePutterWithoutAFullSwingCarry() throws {
        let catalog = try XCTUnwrap(ClubCatalogLoader.loadBundled())
        let model = try XCTUnwrap(catalog.search(query: "Scotty Newport 2", category: .putter)
            .first { $0.name == "Studio Style Newport 2" })
        XCTAssertEqual(model.variants.map(\.displayName), ["Putter"])
        let variant = try XCTUnwrap(model.variants.first)
        var selection = AddClubSelection(existingClubs: [])
        selection.toggle(family: model, variant: variant, unit: .yards)
        let club = try XCTUnwrap(selection.clubs?.first)
        XCTAssertTrue(club.isPutter)
        XCTAssertEqual(club.family, "Studio Style Newport 2")
        XCTAssertEqual(club.typicalDistanceMeters, 10)
        XCTAssertTrue(AddClubSelection(existingClubs: [club]).isOwned(family: model, variant: variant))
    }

    func testManufacturerMarkingsUseAppropriateCarryEstimates() {
        func carry(_ code: String, _ category: ClubCatalogCategory) -> Int {
            ClubCatalog.defaultDistanceMeters(for: .init(code: code), category: category)
        }
        XCTAssertLessThan(carry("UW", .iron), carry("PW", .iron))
        XCTAssertEqual(carry("52°", .iron), carry("52°", .wedge))
        XCTAssertLessThan(carry("53°", .iron), carry("49°", .iron))
        XCTAssertGreaterThan(carry("15°", .fairwayWood), carry("21°", .fairwayWood))
        XCTAssertGreaterThan(carry("18°", .hybrid), carry("29°", .hybrid))
        XCTAssertGreaterThan(carry("3HL", .fairwayWood), carry("7W", .fairwayWood))
        XCTAssertLessThan(carry("8H", .hybrid), carry("7H", .hybrid))
        XCTAssertLessThan(carry("10I", .iron), carry("9I", .iron))
        XCTAssertLessThan(carry("11I", .iron), carry("10I", .iron))
        XCTAssertEqual(carry("3U", .hybrid), carry("3H", .hybrid))
        XCTAssertEqual(carry("3W-16.5°", .fairwayWood), carry("16.5°", .fairwayWood))
        XCTAssertGreaterThan(carry("18°", .utilityIron), carry("27°", .utilityIron))
        XCTAssertEqual(carry("W", .iron), carry("PW", .iron))
    }
}

@MainActor
final class RemoteClubCatalogTests: XCTestCase {
    func testExpandedManufacturerSnapshotPassesTheActualRemoteValidator() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "club_catalog", withExtension: "json"))
        let catalog = try ClubCatalogStore.validate(Data(contentsOf: url))
        XCTAssertGreaterThan(catalog.families.count, 600)
        for brand in ["Bettinardi", "Evnroll", "New Level", "Haywood", "XXIO"] {
            XCTAssertFalse(catalog.families(for: brand).isEmpty)
        }
        let honma = try XCTUnwrap(catalog.families.first { $0.brand == "Honma" && $0.name == "TW777 PCB MAX Irons" })
        XCTAssertTrue(honma.variants.contains { $0.code == "11I" })
        let takomo = try XCTUnwrap(catalog.families.first { $0.brand == "Takomo" && $0.name == "101 MKII Irons" })
        XCTAssertEqual(takomo.variants.map(\.code), ["5I", "6I", "7I", "8I", "9I", "PW", "GW"])
    }
    func testBuiltAppContainsCatalogConfiguration() throws {
        let config = try XCTUnwrap(SupabaseConfig.loadFromEnvironment())
        XCTAssertEqual(config.url.scheme, "https")
        XCTAssertFalse(config.anonKey.isEmpty)
    }
    private let endpoint = URL(string: "https://example.supabase.co/storage/v1/object/public/club-catalog/v1/catalog.json")!
    private var sample: Data {
        Data(#"{"schemaVersion":1,"brands":["PING"],"families":[{"brand":"PING","name":"G440 Irons","category":"iron","variants":[{"code":"7I","displayName":"7I"}]}]}"#.utf8)
    }
    private func cacheURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("catalog.json")
    }
    private func response(_ code: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: endpoint, statusCode: code, httpVersion: nil, headerFields: nil)!
    }
    func testValidatedRemoteCatalogPersistsAndLoadsWithoutNetwork() async throws {
        let file = cacheURL()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let data = sample, http = response()
        let store = ClubCatalogStore(endpoint: endpoint, cacheURL: file, fallback: .fallback, fetch: { _ in (data, http) })
        XCTAssertTrue(store.document.families.isEmpty)
        await store.refreshIfNeeded()
        XCTAssertEqual(store.document.families.first?.name, "G440 Irons")
        let offline = ClubCatalogStore(endpoint: endpoint, cacheURL: file, fallback: .fallback, fetch: { _ in throw URLError(.notConnectedToInternet) })
        XCTAssertEqual(offline.document, store.document)
        await offline.refreshIfNeeded()
        XCTAssertEqual(offline.document, store.document)
    }
    func testFailureRetainsLastGoodCatalogAndDoesNotWriteCache() async throws {
        let good = try ClubCatalogDocument.load(from: sample)
        for (data, status) in [(Data("oops".utf8), 200), (sample, 503), (Data(#"{"schemaVersion":2,"brands":[],"families":[]}"#.utf8), 200)] {
            let file = cacheURL(), http = response(status)
            let store = ClubCatalogStore(endpoint: endpoint, cacheURL: file, fallback: good, fetch: { _ in (data, http) })
            await store.refreshIfNeeded()
            XCTAssertEqual(store.document, good)
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        }
    }
    func testRefreshUsesDailyTTLAndBacksOffAfterFailure() async {
        var now = Date(timeIntervalSince1970: 1_800_000_000), requests = 0
        let file = cacheURL(), data = sample, http = response()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = ClubCatalogStore(endpoint: endpoint, cacheURL: file, fallback: .fallback, now: { now }, fetch: { _ in
            requests += 1
            if requests > 1 { throw URLError(.notConnectedToInternet) }
            return (data, http)
        })
        await store.refreshIfNeeded()
        now.addTimeInterval(86_399)
        await store.refreshIfNeeded()
        XCTAssertEqual(requests, 1)
        now.addTimeInterval(2)
        await store.refreshIfNeeded()
        await store.refreshIfNeeded()
        XCTAssertEqual(requests, 2)
        now.addTimeInterval(301)
        await store.refreshIfNeeded()
        XCTAssertEqual(requests, 3)
        XCTAssertEqual(store.document.families.count, 1)
    }
    func testConcurrentRefreshesShareOneRequest() async {
        var requests = 0
        let data = sample, http = response(), file = cacheURL()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = ClubCatalogStore(endpoint: endpoint, cacheURL: file, fallback: .fallback, fetch: { _ in
            requests += 1
            try await Task.sleep(nanoseconds: 20_000_000)
            return (data, http)
        })
        async let first: Void = store.refreshIfNeeded()
        async let second: Void = store.refreshIfNeeded()
        _ = await (first, second)
        XCTAssertEqual(requests, 1)
    }
    func testCacheCannotCrossProjectsAndCorruptCacheFallsBack() async throws {
        let file = cacheURL(), data = sample, http = response()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = ClubCatalogStore(endpoint: endpoint, cacheURL: file, fallback: .fallback, fetch: { _ in (data, http) })
        await store.refreshIfNeeded()
        let other = ClubCatalogStore(endpoint: URL(string: "https://other.supabase.co/catalog.json"), cacheURL: file, fallback: .fallback)
        XCTAssertTrue(other.document.families.isEmpty)
        try Data("corrupt".utf8).write(to: file)
        let corrupted = ClubCatalogStore(endpoint: endpoint, cacheURL: file, fallback: .fallback)
        XCTAssertTrue(corrupted.document.families.isEmpty)
    }
    func testRemoteValidationRejectsUnsafeSchemaAndIdentityCollisions() throws {
        XCTAssertNoThrow(try ClubCatalogStore.validate(sample))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: sample) as? [String: Any])
        var family = try XCTUnwrap((object["families"] as? [[String: Any]])?.first)
        object["families"] = [family, family]
        XCTAssertThrowsError(try ClubCatalogStore.validate(JSONSerialization.data(withJSONObject: object)))
        family["variants"] = [["code": "7I", "displayName": "7I"], ["code": "seven", "displayName": "7i"]]
        object["families"] = [family]
        XCTAssertThrowsError(try ClubCatalogStore.validate(JSONSerialization.data(withJSONObject: object)))
        object["families"] = []
        XCTAssertThrowsError(try ClubCatalogStore.validate(JSONSerialization.data(withJSONObject: object)))
        XCTAssertThrowsError(try ClubCatalogStore.validate(Data(repeating: 0, count: 2_000_001)))
    }
}
