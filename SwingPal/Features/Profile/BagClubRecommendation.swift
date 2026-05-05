import Foundation

struct BagClubRecommendation: Equatable {
    let clubName: String
    let reason: String

    static func make(bag: Bag, playsLikeDistanceMeters: Int, distanceUnit: DistanceUnit = .meters) -> Self {
        let club = bag.clubs.min {
            abs($0.typicalDistanceMeters - playsLikeDistanceMeters) <
            abs($1.typicalDistanceMeters - playsLikeDistanceMeters)
        } ?? .init(name: "Unknown", typicalDistanceMeters: 0)

        return Self(
            clubName: club.name,
            reason: "Your \(club.name) average is \(distanceUnit.shortLabel(forMeters: club.typicalDistanceMeters)) and this shot plays like \(distanceUnit.shortLabel(forMeters: playsLikeDistanceMeters))."
        )
    }

    static func make(bag: Bag, playsLikeDistanceMeters: Int) -> Self {
        make(bag: bag, playsLikeDistanceMeters: playsLikeDistanceMeters, distanceUnit: .meters)
    }
}
