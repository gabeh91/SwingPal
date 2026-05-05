import Foundation

struct Bag: Equatable, Codable {
    let clubs: [Club]

    static let starter = Bag(clubs: [
        Club(name: "7I", typicalDistanceMeters: 145, brand: "Titleist", family: "T-Series", source: .catalog),
        Club(name: "6I", typicalDistanceMeters: 158, brand: "Titleist", family: "T-Series", source: .catalog),
        Club(name: "5W", typicalDistanceMeters: 205, brand: "Titleist", family: "GT Metals", source: .catalog)
    ])
}
