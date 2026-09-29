import SwiftUI

/// A card pinned to the clubhouse board: who, where, the figure, and the one
/// line worth reading.
struct SocialPostCard: View {
    let post: SocialPost
    let palette: SocialPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Text(String(post.playerName.prefix(1)).uppercased())
                        .font(.system(.subheadline, weight: .bold).width(.condensed))
                        .foregroundStyle(post.ownership == .currentUser ? Book.onStamp : Book.ink)
                        .frame(width: 34, height: 34)
                        .background {
                            if post.ownership == .currentUser { Circle().fill(Book.stamp) }
                            else { Circle().strokeBorder(Book.ink.opacity(0.5), lineWidth: 1) }
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.playerName).font(.headline)
                        Text(post.courseName).font(.subheadline).foregroundStyle(Book.pencil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(post.scoreSummary)
                            .font(.system(size: 30, weight: .bold).width(.condensed))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        BookNote(post.kindLabel)
                    }
                }
                if !post.highlight.isEmpty {
                    Text(post.highlight)
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !post.metadataPills.isEmpty {
                    Text(post.metadataPills.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Book.pencil)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bookLeaf(cornerRadius: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(post.actionTitle)
    }
}
