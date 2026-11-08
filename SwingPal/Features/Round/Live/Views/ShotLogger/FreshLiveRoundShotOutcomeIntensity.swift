import SwiftUI

enum FreshLiveRoundShotOutcomeIntensity: CaseIterable {
    case normal
    case far

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .far: return "Far"
        }
    }
}
