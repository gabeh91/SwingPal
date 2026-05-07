import SwiftUI

struct DistanceHUDView: View {
    let distanceToPinMeters: Int
    let distanceUnit: DistanceUnit

    init(distanceToPinMeters: Int, distanceUnit: DistanceUnit = .meters) {
        self.distanceToPinMeters = distanceToPinMeters
        self.distanceUnit = distanceUnit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x4) {
            Text("Distance")
                .font(.caption)
                .foregroundStyle(ShellTokens.ColorRole.textSecondary)
            Text(distanceUnit.shortLabel(forMeters: distanceToPinMeters))
                .font(.title3.bold())
                .foregroundStyle(ShellTokens.ColorRole.textPrimary)
        }
        .padding(ShellTokens.Spacing.x12)
        .background(ShellTokens.ColorRole.surfaceHUD, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.sm)
                .stroke(ShellTokens.ColorRole.strokeDefault, lineWidth: 1)
        )
    }
}
