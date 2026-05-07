import SwiftUI

struct PlayerSelectionView: View {
    @ObservedObject var state: RoundSetupState
    let distanceUnit: DistanceUnit
    let onStartRound: () -> Void
    @State private var isShowingGuestSheet = false

    init(state: RoundSetupState, distanceUnit: DistanceUnit = .meters, onStartRound: @escaping () -> Void) {
        self.state = state
        self.distanceUnit = distanceUnit
        self.onStartRound = onStartRound
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x20) {
                roundSummaryCard

                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                    Text("Players")
                        .font(.headline)

                    FlowStack {
                        ForEach(state.players) { player in
                            playerChip(for: player)
                        }
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

                HStack(spacing: ShellTokens.Spacing.x12) {
                    Button("Add Guest Player") {
                        isShowingGuestSheet = true
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, ShellTokens.Spacing.x16)
                    .padding(.vertical, ShellTokens.Spacing.x12)
                    .background(ShellTokens.ColorRole.bgGrouped, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.sm))
                    .foregroundStyle(ShellTokens.ColorRole.textPrimary)

                    Button("Start Round", action: onStartRound)
                        .buttonStyle(.plain)
                        .padding(.horizontal, ShellTokens.Spacing.x16)
                        .padding(.vertical, ShellTokens.Spacing.x12)
                        .background(ShellTokens.ColorRole.pine700, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.sm))
                        .foregroundStyle(ShellTokens.ColorRole.textInverse)
                }
            }
            .padding(ShellTokens.Spacing.x20)
            .padding(.bottom, AppChromeMetrics.roundScreenBottomPadding)
        }
        .background(ShellTokens.ColorRole.bgApp)
        .sheet(isPresented: $isShowingGuestSheet) {
            AddGuestPlayerSheet(
                onAdd: { state.addGuest(named: $0) },
                onDismiss: { isShowingGuestSheet = false }
            )
        }
    }

    private var roundSummaryCard: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            HStack {
                Text("\(state.players.count) golfers")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ShellTokens.ColorRole.pine700)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ShellTokens.ColorRole.surfaceTinted, in: Capsule())
                Spacer()
                Text(state.selectedTeeName ?? "Select tees")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ShellTokens.ColorRole.textSecondary)
            }

            Text(state.roundSetupSummaryTitle)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(ShellTokens.ColorRole.textPrimary)

            Text("Confirm who is in the group, add guests if needed, then move straight into the live round.")
                .foregroundStyle(ShellTokens.ColorRole.textSecondary)

            HStack(spacing: ShellTokens.Spacing.x8) {
                summaryChip(state.selectedTeeName ?? "Choose tees")
                if let selectedTeeYards = state.selectedTeeYards {
                    summaryChip(teeDistanceLabel(forYards: selectedTeeYards))
                }
                summaryChip("Guests supported")
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

    private func playerChip(for player: RoundPlayerDraft) -> some View {
        HStack(spacing: ShellTokens.Spacing.x8) {
            Circle()
                .fill(player.kind == .selfPlayer ? ShellTokens.ColorRole.pine700 : ShellTokens.ColorRole.strokeDefault)
                .frame(width: 8, height: 8)

            Text(player.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ShellTokens.ColorRole.textPrimary)

            if player.kind == .guest {
                Text("Guest")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ShellTokens.ColorRole.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ShellTokens.ColorRole.bgGrouped, in: Capsule())
    }

    private func summaryChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(ShellTokens.ColorRole.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(ShellTokens.ColorRole.surfaceHUD, in: Capsule())
    }

    private func teeDistanceLabel(forYards yards: Int) -> String {
        switch distanceUnit {
        case .yards:
            return "\(yards)yd"
        case .meters:
            let meters = Int((Double(yards) * 0.9144).rounded())
            return "\(meters)m"
        }
    }
}

private struct FlowStack: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
