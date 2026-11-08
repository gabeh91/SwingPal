import Foundation

enum WatchBookLabels {
    /// The phone's club codes: Dr, 7i, PW, Pt.
    static func club(_ name: String) -> String {
        switch name.lowercased() {
        case "driver": return "Dr"
        case "putter": return "Pt"
        case "pitching wedge": return "PW"
        case "gap wedge", "approach wedge": return "GW"
        case "sand wedge": return "SW"
        case "lob wedge": return "LW"
        default:
            return name.replacingOccurrences(of: "-iron", with: "i", options: .caseInsensitive)
                .replacingOccurrences(of: " Iron", with: "i", options: .caseInsensitive)
                .replacingOccurrences(of: "-wood", with: "w", options: .caseInsensitive)
                .replacingOccurrences(of: "-hybrid", with: "h", options: .caseInsensitive)
        }
    }

    static func surface(_ surface: RoundCompanionSurface) -> String {
        switch surface {
        case .tee: return "Tee"
        case .fairway: return "Fairway"
        case .rough: return "Rough"
        case .bunker: return "Bunker"
        case .green: return "Green"
        }
    }

    static func surfaceSymbol(_ surface: RoundCompanionSurface) -> String {
        switch surface {
        case .tee: return "flag.fill"
        case .fairway: return "leaf.fill"
        case .rough: return "leaf"
        case .bunker: return "circle.dotted"
        case .green: return "circle.circle.fill"
        }
    }

    static func penalty(_ penalty: RoundCompanionPenalty) -> (title: String, detail: String, symbol: String) {
        switch penalty {
        case .lostBall: return ("Lost ball", "Stroke and distance", "questionmark.circle.fill")
        case .outOfBounds: return ("Out of bounds", "Stroke and distance", "rectangle.dashed")
        case .unplayable: return ("Unplayable lie", "+1 · drop", "leaf.fill")
        case .water: return ("Water hazard", "+1 · drop", "water.waves")
        }
    }

    static func toPar(_ value: Int) -> String {
        value == 0 ? "E" : value > 0 ? "+\(value)" : "\(value)"
    }

    static func scoreName(score: Int, par: Int) -> String {
        switch score - par {
        case ...(-3): return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double bogey"
        case 3: return "Triple bogey"
        default: return "+\(score - par)"
        }
    }

    static func shotConfirmTitle(context: RoundCompanionShotContext, puttHoled: Bool?) -> String {
        switch context {
        case .tee: return "Log tee shot"
        case .shot: return "Log shot"
        case .putt:
            switch puttHoled {
            case true?: return "Hole out"
            case false?: return "Log missed putt"
            case nil: return "Log putt"
            }
        }
    }
}
