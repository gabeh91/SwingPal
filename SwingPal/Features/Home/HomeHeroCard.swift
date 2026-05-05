import SwiftUI

struct HomeHeroCard: View {
    let title: String
    let subtitle: String
    let highlights: [String]
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
            HStack {
                Text("Your Round")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ShellTokens.ColorRole.textInverse)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.16), in: Capsule())
                Spacer()
                Text(title == "Resume Round" ? "Live" : "Ready")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ShellTokens.ColorRole.textInverse)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.16), in: Capsule())
            }

            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                Text(title)
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .foregroundStyle(ShellTokens.ColorRole.textInverse)
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(ShellTokens.ColorRole.textInverse.opacity(0.88))
            }

            HStack(spacing: ShellTokens.Spacing.x8) {
                ForEach(highlights, id: \.self) { highlight in
                    miniPill(highlight)
                }
            }

            Button(action: action) {
                HStack(spacing: 10) {
                    Text(actionTitle)
                        .font(.headline)
                    Image(systemName: "arrow.up.right")
                        .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, ShellTokens.Spacing.x20)
                .padding(.vertical, ShellTokens.Spacing.x12)
                .background(Color.white, in: Capsule())
                .foregroundStyle(ShellTokens.ColorRole.pine700)
            }
            .buttonStyle(.plain)
        }
        .padding(ShellTokens.Spacing.x20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: ShellTokens.Radius.lg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.lg)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: ShellTokens.Shadow.floating, radius: 18, y: 12)
        .clipped()
    }

    private func miniPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(ShellTokens.ColorRole.textInverse)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.14), in: Capsule())
    }
}
