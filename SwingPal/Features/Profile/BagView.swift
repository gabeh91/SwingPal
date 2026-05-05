import SwiftUI

struct BagView: View {
    let bag: Bag
    let distanceUnit: DistanceUnit

    var body: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            HStack {
                Text("Your Bag")
                    .font(.headline)
                    .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                Spacer()
                Text("\(bag.clubs.count) clubs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ShellTokens.ColorRole.pine700)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(ShellTokens.ColorRole.surfaceOverlay, in: Capsule())
            }

            ForEach(bag.clubs) { club in
                HStack(spacing: ShellTokens.Spacing.x12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: ShellTokens.Radius.sm)
                            .fill(ShellTokens.ColorRole.surfaceTinted)
                            .frame(width: 44, height: 44)
                        Text(club.name.prefix(2).uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ShellTokens.ColorRole.pine700)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(club.name)
                            .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                            .font(.subheadline.weight(.semibold))
                        Text("Carry distance")
                            .font(.caption)
                            .foregroundStyle(ShellTokens.ColorRole.textTertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(distanceUnit.shortLabel(forMeters: club.typicalDistanceMeters))
                            .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                            .font(.subheadline.weight(.semibold))
                        Text("Set")
                            .font(.caption)
                            .foregroundStyle(ShellTokens.ColorRole.pine700)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(ShellTokens.Spacing.x20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    ShellTokens.ColorRole.surfacePrimary,
                    ShellTokens.ColorRole.surfaceTinted.opacity(0.7)
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
}
