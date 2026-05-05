import SwiftUI

struct RoundReviewView: View {
    let players: [PlayerScoreState]
    let onDone: () -> Void

    private var summary: RoundReviewSummary {
        RoundReviewSummary(players: players)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                hero

                scorecard

                attestationNote

                Button(action: onDone) {
                    HStack {
                        Text(summary.isReadyToClose ? "Close Round" : "Save Review")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .padding(.horizontal, ShellTokens.Spacing.x16)
                    .padding(.vertical, ShellTokens.Spacing.x16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ShellTokens.ColorRole.textInverse)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            ShellTokens.ColorRole.pine700,
                            ShellTokens.ColorRole.pine500
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                )
            }
            .padding(ShellTokens.Spacing.x20)
        }
        .background(ShellTokens.ColorRole.bgApp)
        .navigationTitle("Review & Attest")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            Text("Review & Attest")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(ShellTokens.ColorRole.textPrimary)
            Text("Confirm each hole before ending the round.")
                .foregroundStyle(ShellTokens.ColorRole.textSecondary)

            HStack(spacing: ShellTokens.Spacing.x12) {
                summaryPill("Players \(summary.playerCount)")
                summaryPill("Pending \(summary.pendingCount)")
                summaryPill("Logged \(summary.loggedCount)")
            }
        }
        .padding(ShellTokens.Spacing.x20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    ShellTokens.ColorRole.surfacePrimary,
                    ShellTokens.ColorRole.surfaceSecondary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: ShellTokens.Radius.lg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.lg)
                .stroke(ShellTokens.ColorRole.strokeDefault, lineWidth: 1)
        )
    }

    private var scorecard: some View {
        VStack(spacing: ShellTokens.Spacing.x12) {
            ForEach(players) { player in
                HStack(spacing: ShellTokens.Spacing.x12) {
                    Circle()
                        .fill(player.isGuest ? ShellTokens.ColorRole.surfaceSecondary : ShellTokens.ColorRole.bgGrouped)
                        .frame(width: 42, height: 42)
                        .overlay {
                            Text(initials(for: player.name))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(player.name)
                                .font(.headline)
                                .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                            roleBadge(player.isGuest ? "Guest" : "Account")
                        }

                        Text(statusDetail(for: player))
                            .font(.subheadline)
                            .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(player.strokes.map(String.init) ?? "--")
                            .font(.system(size: 26, weight: .semibold, design: .serif))
                            .foregroundStyle(ShellTokens.ColorRole.pine700)
                        statusBadge(for: player.status)
                    }
                }
                .padding(ShellTokens.Spacing.x16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    ShellTokens.ColorRole.surfacePrimary,
                    in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                        .stroke(ShellTokens.ColorRole.strokeDefault, lineWidth: 1)
                )
            }
        }
    }

    private var attestationNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summary.isReadyToClose ? "Ready to close" : "Attestation still open")
                .font(.headline)
                .foregroundStyle(ShellTokens.ColorRole.textPrimary)
            Text(summary.isReadyToClose ? "All visible player states are confirmed or edited. This can close as the round’s final review state." : "Any player still marked pending will carry into the saved review state so the round stays honest and easy to revisit.")
                .foregroundStyle(ShellTokens.ColorRole.textSecondary)
        }
        .padding(ShellTokens.Spacing.x16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShellTokens.ColorRole.surfaceSecondary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                .stroke(ShellTokens.ColorRole.strokeDefault, lineWidth: 1)
        )
    }

    private func statusText(for status: PlayerScoreState.Status) -> String {
        switch status {
        case .confirmed:
            return "Confirmed"
        case .pending:
            return "Pending"
        case .edited:
            return "Edited"
        }
    }

    private func statusBadge(for status: PlayerScoreState.Status) -> some View {
        Text(statusText(for: status))
            .font(.caption.weight(.medium))
            .foregroundStyle(statusForeground(for: status))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusBackground(for: status), in: Capsule())
    }

    private func summaryPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(ShellTokens.ColorRole.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(ShellTokens.ColorRole.surfaceHUD, in: Capsule())
    }

    private func roleBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(ShellTokens.ColorRole.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(ShellTokens.ColorRole.bgGrouped, in: Capsule())
    }

    private func initials(for name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    private func statusDetail(for player: PlayerScoreState) -> String {
        if let strokes = player.strokes {
            return "\(strokes) strokes entered for this review"
        }

        return player.isGuest ? "Waiting on guest score confirmation" : "Waiting on signed-in score confirmation"
    }

    private func statusForeground(for status: PlayerScoreState.Status) -> Color {
        switch status {
        case .confirmed:
            return ShellTokens.ColorRole.pine700
        case .pending:
            return ShellTokens.ColorRole.textSecondary
        case .edited:
            return ShellTokens.ColorRole.sun400
        }
    }

    private func statusBackground(for status: PlayerScoreState.Status) -> Color {
        switch status {
        case .confirmed:
            return ShellTokens.ColorRole.pine700.opacity(0.12)
        case .pending:
            return ShellTokens.ColorRole.bgGrouped
        case .edited:
            return ShellTokens.ColorRole.surfacePremium
        }
    }
}
