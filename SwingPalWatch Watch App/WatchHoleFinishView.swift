import SwiftUI

struct WatchHoleFinishView: View {
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
                summaryCard
                if model.showsTrustBanner {
                    trustBanner
                }
                actionStack
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .navigationTitle("Finish")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.holeLabel)
                .font(.headline.weight(.semibold))

            LazyVGrid(columns: columns, spacing: 8) {
                metric("Score", model.scoreLabel.replacingOccurrences(of: "Score ", with: ""))
                metric("Shot", model.shotLabel.replacingOccurrences(of: "Shot ", with: ""))
                metric("Club", model.clubLabel)
                metric("Surface", model.surfaceLabel)
            }

            Text(model.canFinishHole ? "Ready to close out this hole." : "Log at least one shot before finishing.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var actionStack: some View {
        VStack(spacing: 8) {
            Button {
                store.sendFinishHole()
                dismiss()
            } label: {
                HStack {
                    Label("Finish Hole", systemImage: "flag.pattern.checkered")
                    Spacer()
                    Image(systemName: "checkmark")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(.green.opacity(0.24), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!model.canFinishHole || !model.canSendCriticalActions)
            .opacity(model.canFinishHole && model.canSendCriticalActions ? 1.0 : 0.5)

            Button {
                store.sendUndoLastAction()
                dismiss()
            } label: {
                HStack {
                    Label("Undo Last Action", systemImage: "arrow.uturn.backward")
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
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

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
