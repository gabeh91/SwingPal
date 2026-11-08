import SwiftUI

struct AuthGateView: View {
    let title: String
    let detail: String
    let onAuthenticated: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
            HStack(alignment: .top, spacing: ShellTokens.Spacing.x12) {
                ZStack {
                    Circle()
                        .fill(ShellTokens.ColorRole.pine700.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(ShellTokens.ColorRole.pine700)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                    Text(detail)
                        .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                benefitRow("Save rounds to the cloud")
                benefitRow("Sync across devices")
                benefitRow("Share round summaries")
            }

            VStack(spacing: ShellTokens.Spacing.x8) {
                Button("Continue with Apple", action: onAuthenticated)
                    .buttonStyle(.borderedProminent)
                    .tint(ShellTokens.ColorRole.pine700)
                    .frame(maxWidth: .infinity)
                Button("Continue with Google", action: onAuthenticated)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("Email Magic Link", action: onAuthenticated)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }

            Button("Not now", action: onDismiss)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(ShellTokens.Spacing.x20)
        .background(ShellTokens.ColorRole.surfacePrimary)
        .presentationDetents([.medium])
    }

    private func benefitRow(_ text: String) -> some View {
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
