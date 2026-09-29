import Foundation

struct BagClubRecommendation: Equatable {
    let clubName: String
    let reason: String

    static func make(bag: Bag, playsLikeDistanceMeters: Int, distanceUnit: DistanceUnit = .meters) -> Self {
        guard playsLikeDistanceMeters > 0 else {
            return Self(clubName: "No recommendation", reason: "A target distance is needed before suggesting a club.")
        }
        guard let club = bag.clubs.filter({ !$0.isPutter && $0.typicalDistanceMeters > 0 }).min(by: {
            abs($0.typicalDistanceMeters - playsLikeDistanceMeters) <
            abs($1.typicalDistanceMeters - playsLikeDistanceMeters)
        }) else {
            return Self(clubName: "No recommendation", reason: "Add a club with a typical distance to get a suggestion.")
        }

        return Self(
            clubName: club.name,
            reason: "Your bag lists \(club.name) at \(distanceUnit.shortLabel(forMeters: club.typicalDistanceMeters)); this shot plays like \(distanceUnit.shortLabel(forMeters: playsLikeDistanceMeters))."
        )
    }

    static func make(bag: Bag, playsLikeDistanceMeters: Int) -> Self {
        make(bag: bag, playsLikeDistanceMeters: playsLikeDistanceMeters, distanceUnit: .meters)
    }
}
