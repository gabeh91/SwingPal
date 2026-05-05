enum GatedAction {
    case saveRound
    case openWatchCompanion
}

enum GateRequirement: Equatable {
    case none
    case signIn
    case premium
}

struct GatedActionResolver {
    let authState: AuthState
    let entitlements: EntitlementState

    var canOpenWatchCompanion: Bool {
        watchCompanionRequirement() == .none
    }

    func requirement(for action: GatedAction) -> GateRequirement {
        switch action {
        case .saveRound:
            authState == .guest ? .signIn : .none
        case .openWatchCompanion:
            entitlements == .premium ? .none : .premium
        }
    }

    func watchCompanionRequirement() -> GateRequirement {
        requirement(for: .openWatchCompanion)
    }
}
