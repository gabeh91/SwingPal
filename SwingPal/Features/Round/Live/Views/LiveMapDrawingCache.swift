import SwiftUI
import MapKit

/// Map drawings that only change with the hole (the page) or the ball (hazard
/// figures), kept between renders so location ticks and taps don't rebuild them.
final class LiveMapDrawingCache {
    private var pageHole: Int?
    private var pageValue: (sheet: MKPolygon, edge: [CLLocationCoordinate2D])?
    private var hazardKey: String?
    private var hazardValue: [HoleMapGeometry.HazardYardage] = []

    func page(for hole: Int, make: () -> (sheet: MKPolygon, edge: [CLLocationCoordinate2D])?) -> (sheet: MKPolygon, edge: [CLLocationCoordinate2D])? {
        if pageHole != hole {
            pageValue = make()
            pageHole = hole
        }
        return pageValue
    }

    func hazards(for key: String, make: () -> [HoleMapGeometry.HazardYardage]) -> [HoleMapGeometry.HazardYardage] {
        if hazardKey != key {
            hazardValue = make()
            hazardKey = key
        }
        return hazardValue
    }
}
