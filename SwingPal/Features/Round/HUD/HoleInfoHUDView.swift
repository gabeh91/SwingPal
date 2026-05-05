import SwiftUI

struct HoleInfoHUDView: View {
    let number: Int
    let par: Int
    let strokeCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x4) {
            Text("Hole \(number) • Par \(par)")
                .font(.caption)
                .foregroundStyle(ShellTokens.ColorRole.textSecondary)
            Text("Strokes: \(strokeCount)")
                .font(.headline)
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
