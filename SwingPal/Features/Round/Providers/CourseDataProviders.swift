import Foundation

struct OpenGolfCoursePayload: Equatable {
    let externalID: String
    let par: Int
    let holeCount: Int
    let teeNames: [String]
}

protocol OpenGolfCourseLoading {
    func coursePayload(named courseName: String) -> OpenGolfCoursePayload?
}

struct OSMCourseGeometryPayload: Equatable {
    let externalID: String
    let coordinate: SwingPalCourse.Coordinate
    let featureCount: Int
}

protocol OSMCourseGeometryLoading {
    func geometryPayload(named courseName: String) -> OSMCourseGeometryPayload?
}

struct SeededOpenGolfCourseLoader: OpenGolfCourseLoading {
    func coursePayload(named courseName: String) -> OpenGolfCoursePayload? {
        switch courseName {
        case "Royal Melbourne":
            return .init(
                externalID: "og-royal-melbourne",
                par: 72,
                holeCount: 18,
                teeNames: ["Championship", "Member", "Forward"]
            )
        case "Kingston Heath":
            return .init(
                externalID: "og-kingston-heath",
                par: 72,
                holeCount: 18,
                teeNames: ["Championship", "Member", "Forward"]
            )
        case "Peninsula Kingswood":
            return .init(
                externalID: "og-peninsula-kingswood",
                par: 72,
                holeCount: 18,
                teeNames: ["Championship", "Member", "Forward"]
            )
        default:
            return nil
        }
    }
}

struct SeededOSMCourseGeometryLoader: OSMCourseGeometryLoading {
    func geometryPayload(named courseName: String) -> OSMCourseGeometryPayload? {
        switch courseName {
        case "Royal Melbourne":
            return .init(
                externalID: "osm-royal-melbourne",
                coordinate: .init(latitude: -37.9742, longitude: 145.0338),
                featureCount: 24
            )
        case "Kingston Heath":
            return .init(
                externalID: "osm-kingston-heath",
                coordinate: .init(latitude: -37.9588, longitude: 145.0328),
                featureCount: 29
            )
        case "Peninsula Kingswood":
            return .init(
                externalID: "osm-peninsula-kingswood",
                coordinate: .init(latitude: -38.2432, longitude: 145.1378),
                featureCount: 18
            )
        default:
            return nil
        }
    }
}
