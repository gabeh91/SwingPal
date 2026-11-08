import Foundation

/// The phone's eight-sector landing dial, clockwise from long (north).
enum WatchShotOutcome: Int, CaseIterable, Identifiable {
    case long
    case longRight
    case right
    case shortRight
    case short
    case shortLeft
    case left
    case longLeft

    var id: Int { rawValue }

    var midAngleDegrees: Double { Double(rawValue) * 45 }

    var label: String {
        switch self {
        case .long: return "Long"
        case .longRight: return "Long R"
        case .right: return "Right"
        case .shortRight: return "Short R"
        case .short: return "Short"
        case .shortLeft: return "Short L"
        case .left: return "Left"
        case .longLeft: return "Long L"
        }
    }

    var spokenLabel: String {
        switch self {
        case .long: return "Long"
        case .longRight: return "Long right"
        case .right: return "Right"
        case .shortRight: return "Short right"
        case .short: return "Short"
        case .shortLeft: return "Short left"
        case .left: return "Left"
        case .longLeft: return "Long left"
        }
    }

    var distance: RoundCompanionDistance {
        switch self {
        case .long, .longRight, .longLeft: return .long
        case .short, .shortRight, .shortLeft: return .short
        case .right, .left: return .onNumber
        }
    }

    var hasLateralMiss: Bool {
        switch self {
        case .long, .short: return false
        default: return true
        }
    }

    func direction(far: Bool) -> RoundCompanionDirection {
        switch self {
        case .longRight, .right, .shortRight: return far ? .farRight : .right
        case .longLeft, .left, .shortLeft: return far ? .farLeft : .left
        case .long, .short: return .hit
        }
    }

    /// The sector under an angle measured clockwise from north, in degrees.
    static func sector(atDegrees degrees: Double) -> WatchShotOutcome {
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let index = Int(((normalized + 22.5) / 45).rounded(.down)) % 8
        return WatchShotOutcome(rawValue: index) ?? .long
    }
}

/// What the Watch logger has chosen so far. `nil` outcome with `isCentre`
/// means a centre hit.
struct WatchShotDraft: Equatable {
    var clubName: String
    var surface: RoundCompanionSurface
    var outcome: WatchShotOutcome? = nil
    var isCentre: Bool = false
    var isFar: Bool = false
    var isProvisional: Bool = false

    var isComplete: Bool { isCentre || outcome != nil }

    var entry: RoundCompanionShotEntry? {
        if isCentre {
            return .init(clubName: clubName, surface: surface, direction: .hit, distance: .onNumber, isProvisional: isProvisional)
        }
        guard let outcome else { return nil }
        return .init(
            clubName: clubName,
            surface: surface,
            direction: outcome.direction(far: isFar),
            distance: outcome.distance,
            isProvisional: isProvisional
        )
    }

    var summary: String {
        if isCentre { return "Centre" }
        guard let outcome else { return "Where did it finish?" }
        return isFar && outcome.hasLateralMiss ? "\(outcome.spokenLabel), far" : outcome.spokenLabel
    }
}

struct WatchPuttDraft: Equatable {
    var holed: Bool? = nil
    var miss: WatchShotOutcome? = nil

    var entry: RoundCompanionPuttEntry? {
        guard let holed else { return nil }
        guard !holed, let miss else { return .init(holed: holed) }
        return .init(holed: false, missDirection: miss.direction(far: false), missDistance: miss.distance)
    }
}
