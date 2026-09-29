enum AuthState: Equatable {
    case guest
    case authenticated
}

enum AuthModalPresentation: Equatable {
    case authFlow
    case premiumGate

    static func resolve(for requirement: GateRequirement) -> AuthModalPresentation {
        switch requirement {
        case .signIn:
            return .authFlow
        case .premium, .none:
            return .premiumGate
        }
    }
}

enum AuthFlowServiceSource: Equatable {
    case injected
    case appState
    case fallbackMock

    static func resolve(hasInjectedService: Bool, hasAppStateService: Bool) -> AuthFlowServiceSource {
        if hasInjectedService {
            return .injected
        }
        if hasAppStateService {
            return .appState
        }
        return .fallbackMock
    }
}

enum AppAuthServiceMode: Equatable {
    case supabase
    case missingConfiguration

    static func resolve(hasSupabaseConfig: Bool) -> AppAuthServiceMode {
        hasSupabaseConfig ? .supabase : .missingConfiguration
    }
}
