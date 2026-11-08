import SwiftUI

/// Eight equal sectors of a compass-style shot outcome ring, plus a
/// resolved (direction, distance) pair.
///
/// Indexing is clockwise starting from the top (`long` = north, 0°).
enum FreshLiveRoundShotOutcomeNode: Int, CaseIterable {
    case long = 0       // N
    case longRight = 1  // NE
    case right = 2      // E
    case shortRight = 3 // SE
    case short = 4      // S
    case shortLeft = 5  // SW
    case left = 6       // W
    case longLeft = 7   // NW

    /// 0 = up (N), increases clockwise.
    var midAngleDegrees: Double {
        Double(rawValue) * 45
    }

    var distance: ShotEvent.DistanceResult {
        switch self {
        case .long, .longRight, .longLeft: return .long
        case .short, .shortRight, .shortLeft: return .short
        case .right, .left: return .onNumber
        }
    }

    /// Whether this sector has a left/right component that intensity can modify.
    enum LateralLean { case left, none, right }

    var lateralLean: LateralLean {
        switch self {
        case .longRight, .right, .shortRight: return .right
        case .longLeft, .left, .shortLeft: return .left
        case .long, .short: return .none
        }
    }

    func resolvedDirection(intensity: FreshLiveRoundShotOutcomeIntensity) -> ShotEvent.DirectionResult {
        switch lateralLean {
        case .left:
            return intensity == .far ? .farLeft : .left
        case .right:
            return intensity == .far ? .farRight : .right
        case .none:
            return .hit
        }
    }
}
