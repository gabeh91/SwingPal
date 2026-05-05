import SwiftUI

struct SocialPostCard: View {
    let post: SocialPost
    let palette: SocialPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                HStack(alignment: .top, spacing: ShellTokens.Spacing.x12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: post.symbolName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.accent)

                            Text(post.kindLabel.uppercased())
                                .font(ShellTokens.Typography.microEyebrow)
                                .tracking(1.1)
                                .foregroundStyle(palette.tertiaryText)
                        }

                        Text(post.title)
                            .font(ShellTokens.Typography.cardTitle)
                            .foregroundStyle(palette.primaryText)
                    }

                    Spacer()

                    Text(post.scoreSummary)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(palette.accentForeground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(palette.accent, in: Capsule())
                }

                Text(post.highlight)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Text(post.subtitle)
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(3)

                HStack(spacing: ShellTokens.Spacing.x8) {
                    ForEach(Array(post.metadataPills.prefix(2)), id: \.self) { pill in
                        recapChip(pill)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        Text(post.actionTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.accent)
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.accent)
                    }
                }
            }
            .padding(ShellTokens.Spacing.x18)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.quietFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func recapChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(palette.quietFill, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(palette.border, lineWidth: 1)
            }
    }
}
