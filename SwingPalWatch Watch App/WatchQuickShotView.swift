import SwiftUI

struct WatchQuickShotView: View {
    @ObservedObject var store: WatchRoundCompanionStore
    let model: WatchRoundCompanionViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                headerCard
                if model.showsTrustBanner {
                    trustBanner
                }
                outcomeGrid
                utilityGrid
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .navigationTitle("Log Shot")
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.clubLabel)
                .font(.headline.weight(.semibold))
            Text("\(model.primaryYardage) to pin")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var outcomeGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            actionButton("Hit", systemImage: "dot.scope", prominence: .primary) {
                store.sendQuickShot(direction: "hit", distance: "onNumber")
            }
            actionButton("Long", systemImage: "arrow.up", prominence: .secondary) {
                store.sendQuickShot(direction: "hit", distance: "long")
            }
            actionButton("Left", systemImage: "arrow.left", prominence: .secondary) {
                store.sendQuickShot(direction: "left", distance: "onNumber")
            }
            actionButton("Right", systemImage: "arrow.right", prominence: .secondary) {
                store.sendQuickShot(direction: "right", distance: "onNumber")
            }
            actionButton("Short", systemImage: "arrow.down", prominence: .secondary) {
                store.sendQuickShot(direction: "hit", distance: "short")
            }
            actionButton("Drop", systemImage: "arrow.down.to.line", prominence: .secondary) {
                store.sendMarkDrop()
            }
        }
    }

    private var utilityGrid: some View {
        HStack(spacing: 8) {
            actionButton("Putt +1", systemImage: "plus.circle", prominence: .secondary) {
                store.sendAddPutt()
            }
            actionButton("Penalty", systemImage: "exclamationmark.triangle", prominence: .secondary) {
                store.sendAddPenalty()
            }
        }
    }

    private var trustBanner: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.trustBannerTitle)
                .font(.caption.weight(.semibold))
            Text(model.trustBannerDetail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func actionButton(
        _ title: String,
        systemImage: String,
        prominence: WatchActionProminence,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.vertical, 6)
            .background(backgroundStyle(for: prominence), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func backgroundStyle(for prominence: WatchActionProminence) -> some ShapeStyle {
        switch prominence {
        case .primary:
            return AnyShapeStyle(Color(red: 0.81, green: 0.89, blue: 0.77).opacity(0.28))
        case .secondary:
            return AnyShapeStyle(.thinMaterial)
        }
    }
}

private enum WatchActionProminence {
    case primary
    case secondary
}
