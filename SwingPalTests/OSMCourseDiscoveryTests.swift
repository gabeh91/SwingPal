import XCTest
import CoreLocation
@testable import SwingPal

final class OSMCourseDiscoveryTests: XCTestCase {
    // MARK: - Overpass parser

    func testOverpassParserReturnsCoursesWithComputedDistance() throws {
        let json = """
        {
          "version": 0.6,
          "elements": [
            {
              "type": "relation",
              "id": 100,
              "tags": {
                "leisure": "golf_course",
                "name": "Royal Melbourne Golf Club",
                "addr:state": "Victoria",
                "addr:country": "AU"
              },
              "center": { "lat": -37.974, "lon": 145.034 }
            },
            {
              "type": "way",
              "id": 200,
              "tags": {
                "leisure": "golf_course",
                "name": "Yarra Yarra Golf Club"
              },
              "center": { "lat": -37.92, "lon": 145.10 }
            }
          ]
        }
        """.data(using: .utf8)!

        let anchor = CLLocationCoordinate2D(latitude: -37.97, longitude: 145.03)
        let discoveries = try OverpassDiscoveryParser.parse(data: json, anchor: anchor)

        XCTAssertEqual(discoveries.map(\.name), [
            "Royal Melbourne Golf Club",
            "Yarra Yarra Golf Club"
        ])
        XCTAssertEqual(discoveries.first?.osmType, .relation)
        XCTAssertEqual(discoveries.first?.countryCode, "AU")
        XCTAssertEqual(discoveries.first?.region, "Victoria")
        XCTAssertNotNil(discoveries.first?.distanceKilometers)
        XCTAssertLessThan(discoveries.first!.distanceKilometers!, 2)
    }

    func testOverpassParserSkipsElementsMissingNameOrCoordinates() throws {
        let json = """
        {
          "elements": [
            { "type": "relation", "id": 1, "tags": { "leisure": "golf_course" }, "center": { "lat": 0, "lon": 0 } },
            { "type": "way", "id": 2, "tags": { "name": "Has Name" } },
            { "type": "way", "id": 3, "tags": { "name": "Has Centre", "leisure": "golf_course" }, "center": { "lat": 1, "lon": 1 } }
          ]
        }
        """.data(using: .utf8)!

        let discoveries = try OverpassDiscoveryParser.parse(
            data: json,
            anchor: .init(latitude: 0, longitude: 0)
        )

        XCTAssertEqual(discoveries.map(\.name), ["Has Centre"])
    }

    func testOverpassParserDedupesByOSMTypeAndID() throws {
        let json = """
        {
          "elements": [
            { "type": "way", "id": 7, "tags": { "name": "Dup Course" }, "center": { "lat": 0, "lon": 0 } },
            { "type": "way", "id": 7, "tags": { "name": "Dup Course" }, "center": { "lat": 0, "lon": 0 } }
          ]
        }
        """.data(using: .utf8)!

        let discoveries = try OverpassDiscoveryParser.parse(
            data: json,
            anchor: .init(latitude: 0, longitude: 0)
        )

        XCTAssertEqual(discoveries.count, 1)
    }

    func testOverpassParserThrowsOnInvalidJSON() {
        let json = Data("not json".utf8)
        XCTAssertThrowsError(
            try OverpassDiscoveryParser.parse(data: json, anchor: .init(latitude: 0, longitude: 0))
        ) { error in
            XCTAssertEqual(error as? OSMCourseDiscoveryError, .invalidResponse)
        }
    }

    // MARK: - Nominatim parser

    func testNominatimParserKeepsGolfTaggedHits() throws {
        let json = """
        [
          {
            "osm_type": "relation",
            "osm_id": 100,
            "lat": "-37.97",
            "lon": "145.03",
            "display_name": "Royal Melbourne Golf Club, Black Rock, Victoria, Australia",
            "name": "Royal Melbourne Golf Club",
            "class": "leisure",
            "type": "golf_course",
            "address": { "country_code": "au", "state": "Victoria" }
          },
          {
            "osm_type": "node",
            "osm_id": 999,
            "lat": "10.0",
            "lon": "10.0",
            "display_name": "Random Suburb, ZZ",
            "class": "place",
            "type": "suburb"
          }
        ]
        """.data(using: .utf8)!

        let discoveries = try NominatimSearchParser.parse(data: json)

        XCTAssertEqual(discoveries.map(\.name), ["Royal Melbourne Golf Club"])
        XCTAssertEqual(discoveries.first?.countryCode, "AU")
        XCTAssertEqual(discoveries.first?.osmType, .relation)
        XCTAssertNil(discoveries.first?.distanceKilometers)
    }

    func testNominatimParserFallsBackOnDisplayNameWhenNameMissing() throws {
        let json = """
        [
          {
            "osm_type": "way",
            "osm_id": 1,
            "lat": "0", "lon": "0",
            "display_name": "Cool Golf Club, Suburbia, ZZ",
            "class": "leisure",
            "type": "golf_course"
          }
        ]
        """.data(using: .utf8)!

        let discoveries = try NominatimSearchParser.parse(data: json)
        XCTAssertEqual(discoveries.first?.name, "Cool Golf Club")
    }

    func testNominatimParserDropsNonGolfHitsByText() throws {
        let json = """
        [
          {
            "osm_type": "way",
            "osm_id": 1,
            "lat": "0", "lon": "0",
            "display_name": "Some Park, Town, ZZ",
            "class": "leisure",
            "type": "park"
          }
        ]
        """.data(using: .utf8)!

        let discoveries = try NominatimSearchParser.parse(data: json)
        XCTAssertTrue(discoveries.isEmpty)
    }

    // MARK: - Bounding box

    func testBoundingBoxBracketsCentreSymmetrically() {
        let bbox = OSMBoundingBox(
            centre: .init(latitude: 0, longitude: 0),
            radiusKilometres: 10
        )
        XCTAssertEqual(bbox.south, -bbox.north, accuracy: 0.0001)
        XCTAssertEqual(bbox.west, -bbox.east, accuracy: 0.0001)
        XCTAssertGreaterThan(bbox.north, 0)
        XCTAssertGreaterThan(bbox.east, 0)
    }

    // MARK: - Search phrasing

    func testSearchDropsVenueWordsSoClubNamesMatchOpenStreetMap() {
        // OpenStreetMap calls it "Westgate Golf Course"; people type "Westgate golf club".
        XCTAssertEqual(CourseSearchQuery.variants(for: "Westgate golf club"), ["westgate golf course", "westgate golf"])
        XCTAssertEqual(CourseSearchQuery.variants(for: "The Metropolitan Golf Club").first, "metropolitan golf course")
    }

    func testSearchFallsBackToEachWordForSuburbsAndExtras() {
        let variants = CourseSearchQuery.variants(for: "Westgate Spotswood")
        XCTAssertEqual(variants.first, "westgate spotswood golf course")
        XCTAssertTrue(variants.contains("westgate golf course"))
        XCTAssertLessThanOrEqual(variants.count, 4, "Nominatim allows one request a second")
    }

    func testSearchWithNothingDistinctiveIsSearchedAsTypedOrNotAtAll() {
        XCTAssertEqual(CourseSearchQuery.variants(for: "The Golf Club"), ["The Golf Club"])
        XCTAssertEqual(CourseSearchQuery.variants(for: "  "), [])
    }

    // MARK: - Overpass answers

    func testBusyServerPagesAreRetryableNotUnreadableCourses() {
        let xml = Data(#"<?xml version="1.0"?><osm><remark>runtime error: open64: 0 Success /osm3s_osm_base Dispatcher_Client::request_read_and_idx::rate_limited</remark></osm>"#.utf8)
        XCTAssertThrowsError(try OverpassClient.checkPayload(xml)) { XCTAssertEqual($0 as? OSMCourseDiscoveryError, .rateLimited) }

        let timedOut = Data(#"{"elements":[],"remark":"runtime error: Query timed out in \"query\" at line 3 after 61 seconds."}"#.utf8)
        XCTAssertThrowsError(try OverpassClient.checkPayload(timedOut)) { XCTAssertEqual($0 as? OSMCourseDiscoveryError, .rateLimited) }

        XCTAssertNoThrow(try OverpassClient.checkPayload(Data(#"{"elements":[]}"#.utf8)))
    }

    func testQueryBodyEscapesCharactersFormEncodingReserves() {
        let body = String(decoding: OverpassClient.formBody(for: #"way["golf"~"a+b&c=d"];"#), as: UTF8.self)
        XCTAssertFalse(body.dropFirst(5).contains("+"))
        XCTAssertFalse(body.dropFirst(5).contains("&"))
        XCTAssertTrue(body.hasPrefix("data="))
    }

    func testGeometryIsFetchedFromTheCourseBoundaryWhenItHasOne() {
        let course = DiscoveredCourse(id: "way-29233650", name: "Westgate Golf Course", coordinate: .init(latitude: -37.8239, longitude: 144.8864), osmID: 29233650, osmType: .way, countryCode: "AU", region: nil, distanceKilometers: nil)
        let query = LiveOSMCourseGeometryFetcher.boundaryQuery(for: course) ?? ""
        XCTAssertTrue(query.contains("way(29233650)->.course;"))
        XCTAssertTrue(query.contains("map_to_area"))
        XCTAssertTrue(query.contains(#"node["golf"="pin"]"#))

        let relation = DiscoveredCourse(id: "relation-4180358", name: "Royal Melbourne", coordinate: .init(latitude: -37.97, longitude: 145.03), osmID: 4180358, osmType: .relation, countryCode: "AU", region: nil, distanceKilometers: nil)
        XCTAssertTrue(LiveOSMCourseGeometryFetcher.boundaryQuery(for: relation)?.contains("way(r.course)->.edges;") == true)

        let node = DiscoveredCourse(id: "node-1", name: "Point", coordinate: .init(latitude: 0, longitude: 0), osmID: 1, osmType: .node, countryCode: nil, region: nil, distanceKilometers: nil)
        XCTAssertNil(LiveOSMCourseGeometryFetcher.boundaryQuery(for: node), "A course mapped as a point falls back to the box query")
    }

    func testOnlyPayloadsWithHolesCountAsCourseData() {
        XCTAssertEqual(LiveOSMCourseGeometryFetcher.holeCount(in: Data(#"{"elements":[{"type":"way","id":1,"tags":{"golf":"hole"}},{"type":"way","id":2,"tags":{"golf":"green"}}]}"#.utf8)), 1)
        XCTAssertEqual(LiveOSMCourseGeometryFetcher.holeCount(in: Data("<html>busy</html>".utf8)), 0)
    }
}
