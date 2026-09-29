import CoreLocation
import XCTest
@testable import SwingPal

final class HoleMapGeometryTests: XCTestCase {
    private let tee = CLLocationCoordinate2D(latitude: -37.8, longitude: 145.0)

    private func point(east: Double, north: Double) -> CLLocationCoordinate2D {
        HoleMapGeometry.coordinate(from: tee, east: east, north: north)
    }

    private func square(east: Double, north: Double, half: Double, kind: SwingPalCourse.Hole.FeatureKind) -> SwingPalCourse.Hole.Feature {
        let corners = [(-half, -half), (half, -half), (half, half), (-half, half)].map { point(east: east + $0.0, north: north + $0.1) }
        return .init(kind: kind, label: kind.rawValue, coordinates: corners.map { .init(latitude: $0.latitude, longitude: $0.longitude) })
    }

    func testBearingAndDistanceOnTheLocalPlane() {
        XCTAssertEqual(HoleMapGeometry.bearing(from: tee, to: point(east: 0, north: 100)), 0, accuracy: 0.01)
        XCTAssertEqual(HoleMapGeometry.bearing(from: tee, to: point(east: 100, north: 0)), 90, accuracy: 0.01)
        XCTAssertEqual(HoleMapGeometry.bearing(from: tee, to: point(east: -100, north: 0)), 270, accuracy: 0.01)
        XCTAssertEqual(HoleMapGeometry.distance(tee, point(east: 30, north: 40)), 50, accuracy: 0.01)
        let out = HoleMapGeometry.coordinate(from: tee, bearing: 45, distance: 200)
        XCTAssertEqual(HoleMapGeometry.distance(tee, out), 200, accuracy: 0.05)
    }

    func testCarryArcKeepsItsRadiusAndSpread() {
        let arc = HoleMapGeometry.arc(centre: tee, radius: 220, centreBearing: 0, halfSpread: 10, steps: 10)
        XCTAssertEqual(arc.count, 11)
        for p in arc { XCTAssertEqual(HoleMapGeometry.distance(tee, p), 220, accuracy: 0.1) }
        XCTAssertEqual(HoleMapGeometry.bearing(from: tee, to: arc.first!), 350, accuracy: 0.05)
        XCTAssertEqual(HoleMapGeometry.bearing(from: tee, to: arc.last!), 10, accuracy: 0.05)
        XCTAssertEqual(HoleMapGeometry.arcHalfSpread(radius: 20), 35)
        XCTAssertEqual(HoleMapGeometry.arcHalfSpread(radius: 10_000), 7)
    }

    func testHazardYardagesMeasureNearAndFarEdgesOfHazardsInPlay() {
        let pin = point(east: 0, north: 360)
        let features = [
            square(east: 20, north: 220, half: 10, kind: .bunker),   // right of the line, in play
            square(east: -30, north: 150, half: 15, kind: .water),   // left of the line, in play
            square(east: 0, north: -40, half: 8, kind: .bunker),     // behind the tee
            square(east: 150, north: 200, half: 8, kind: .bunker),   // out of play
            square(east: 0, north: 200, half: 30, kind: .fairway)
        ]
        let yardages = HoleMapGeometry.hazardYardages(features: features, origin: tee, pin: pin)
        XCTAssertEqual(yardages.map(\.kind), [.water, .bunker], "nearest first, only hazards in play")

        let water = yardages[0]
        XCTAssertFalse(water.isRightOfLine)
        XCTAssertLessThan(water.reachMetres, water.carryMetres)
        XCTAssertEqual(Double(water.reachMetres), HoleMapGeometry.distance(tee, point(east: -15, north: 135)), accuracy: 1)

        let bunker = yardages[1]
        XCTAssertTrue(bunker.isRightOfLine)
        XCTAssertEqual(Double(bunker.carryMetres), HoleMapGeometry.distance(tee, point(east: 30, north: 230)), accuracy: 1)
        // The figures are written outside the hazard, away from the line.
        let label = HoleMapGeometry.offset(from: tee, to: bunker.labelCoordinate)
        XCTAssertGreaterThan(label.east, 30)
    }

    func testNeighbouringBunkersAreWrittenAsOneComplex() {
        let pin = point(east: 0, north: 360)
        let features = [
            square(east: 25, north: 210, half: 8, kind: .bunker),
            square(east: 28, north: 232, half: 8, kind: .bunker)
        ]
        let yardages = HoleMapGeometry.hazardYardages(features: features, origin: tee, pin: pin)
        XCTAssertEqual(yardages.count, 1)
        XCTAssertEqual(Double(yardages[0].reachMetres), HoleMapGeometry.distance(tee, point(east: 17, north: 202)), accuracy: 1)
        XCTAssertEqual(Double(yardages[0].carryMetres), HoleMapGeometry.distance(tee, point(east: 36, north: 240)), accuracy: 1)
    }

    func testHazardTheBallIsInIsNotMeasured() {
        let pin = point(east: 0, north: 150)
        let features = [square(east: 0, north: 0, half: 6, kind: .bunker)]
        XCTAssertTrue(HoleMapGeometry.hazardYardages(features: features, origin: tee, pin: pin).isEmpty)
    }

    func testPageOutlineWrapsTheHoleWithAMargin() {
        let points = [point(east: 0, north: 0), point(east: 10, north: 300), point(east: -40, north: 150), point(east: 30, north: 160)]
        let outline = HoleMapGeometry.pageOutline(around: points, bufferMetres: 45)
        XCTAssertNotNil(outline)
        let ring = outline!.map { HoleMapGeometry.offset(from: tee, to: $0) }
        // Every input point is inside the (convex, counter-clockwise) outline.
        for p in points.map({ HoleMapGeometry.offset(from: tee, to: $0) }) {
            for (a, b) in zip(ring, ring.dropFirst() + ring.prefix(1)) {
                let cross = (b.east - a.east) * (p.north - a.north) - (b.north - a.north) * (p.east - a.east)
                XCTAssertGreaterThan(cross, 0)
            }
        }
        XCTAssertNil(HoleMapGeometry.pageOutline(around: [tee], bufferMetres: 45))
    }
}
