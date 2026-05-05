enum PremiumFeature: Equatable {
    case watchCompanion
    case deeperCoaching

    var title: String {
        switch self {
        case .watchCompanion:
            return "Apple Watch Companion"
        case .deeperCoaching:
            return "Deeper Coaching"
        }
    }
}
