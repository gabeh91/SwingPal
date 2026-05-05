import SwiftUI

struct PremiumGateView: View {
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
            HStack(alignment: .top, spacing: ShellTokens.Spacing.x12) {
                ZStack {
                    Circle()
                        .fill(ShellTokens.ColorRole.sun400.opacity(0.20))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .foregroundStyle(ShellTokens.ColorRole.sun400)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock Premium Intelligence")
                        .font(.title3.bold())
                        .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                    Text("Play smarter with deeper assistance and a live Apple Watch companion.")
                        .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                bullet("Apple Watch live round companion")
                bullet("Richer caddie-style guidance")
                bullet("Advanced post-round analytics")
            }

            VStack(spacing: ShellTokens.Spacing.x8) {
                Button("Unlock Premium", action: onUpgrade)
                    .buttonStyle(.borderedProminent)
                    .tint(ShellTokens.ColorRole.pine700)
                    .frame(maxWidth: .infinity)
                Button("Not now", action: onDismiss)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(ShellTokens.Spacing.x20)
        .background(ShellTokens.ColorRole.surfacePremium)
        .presentationDetents([.medium])
    }

    private func bullet(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(ShellTokens.ColorRole.pine500)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(ShellTokens.ColorRole.textSecondary)
        }
    }
}
