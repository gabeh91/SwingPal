import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private enum WatchRoundHomePanel: Int {
    case map
    case actions
}

struct WatchRoundHomeView: View {
    @ObservedObject var store: WatchRoundCompanionStore
    let model: WatchRoundCompanionViewModel
    @State private var selectedPanel: WatchRoundHomePanel = .map

    var body: some View {
        TabView(selection: $selectedPanel) {
            mapPanel
                .tag(WatchRoundHomePanel.map)

            actionsPanel
                .tag(WatchRoundHomePanel.actions)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var mapPanel: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.03, green: 0.08, blue: 0.05),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geometry in
                let previewWidth = min(138.0, geometry.size.width * 0.54)
                let previewHeight = geometry.size.height - 10
                let previewTop = -2.0

                ZStack(alignment: .topLeading) {
                    previewStrip(
                        width: previewWidth,
                        height: previewHeight,
                        topInset: previewTop
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: 10, y: -2)

                    VStack(spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            yardageRail
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Color.clear
                                .frame(width: max(previewWidth - 92, 24), height: 1)
                        }

                        if model.showsTrustBanner {
                            compactTrustBanner
                                .padding(.trailing, previewWidth * 0.08)
                        }

                        Spacer(minLength: 0)

                        clubShotBar
                            .padding(.trailing, previewWidth * 0.04)

                        pageIndicators
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                }
            }
        }
    }

    private var yardageRail: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Hole \(model.holeLabel.replacingOccurrences(of: "Hole ", with: ""))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 2) {
                mapMetricLabel("FRONT", value: model.mapFooterMetrics[0].value, emphasized: false)
                mapMetricLabel("PIN", value: model.mapFooterMetrics[1].value, emphasized: true)
                mapMetricLabel("BACK", value: model.mapFooterMetrics[2].value, emphasized: false)
            }

            Spacer(minLength: 0)
        }
    }

    private var clubShotBar: some View {
        HStack(spacing: 8) {
            Label(model.clubLabel, systemImage: "figure.golf")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            Text(model.shotLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.74))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06), in: Capsule())
    }

    private func previewStrip(width: CGFloat, height: CGFloat, topInset: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let previewImage = previewUIImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    geometryMap
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay {
                previewFadeOverlay(cornerRadius: 34)
            }
            .mask {
                previewCoverMask(cornerRadius: 34)
            }
            .shadow(color: .black.opacity(0.34), radius: 18, y: 6)

            Text(model.clubLabel)
                .font(.system(size: 11, weight: .bold).width(.condensed))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 1.0, green: 0.455, blue: 0.322), in: Capsule())
                .padding(.top, topInset + 6)
                .padding(.trailing, 6)
        }
    }

    private func previewFadeOverlay(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.48),
                        .clear,
                        .clear,
                        Color.black.opacity(0.58),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.black.opacity(0.58), Color.black.opacity(0.20), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.18), Color.black.opacity(0.30)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
    }

    private func previewCoverMask(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.18), location: 0.08),
                        .init(color: .white.opacity(0.72), location: 0.16),
                        .init(color: .white, location: 0.22),
                        .init(color: .white, location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }

    private var geometryMap: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let presentation = model.mapPresentation
            let ball = CGPoint(x: width * presentation.ballX, y: height * presentation.ballY)
            let target = CGPoint(x: width * presentation.targetX, y: height * presentation.targetMarkerY)

            ZStack {
                fairwayShape(in: geometry.size)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.19, blue: 0.11),
                                Color(red: 0.17, green: 0.30, blue: 0.18),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Path { path in
                    path.move(to: ball)
                    path.addLine(to: target)
                }
                .stroke(
                    Color.white.opacity(0.7),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4])
                )

                targetMarker(value: presentation.targetLabel)
                    .position(x: target.x, y: target.y)

                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .white.opacity(0.24), radius: 6)
                    .position(x: ball.x, y: ball.y)
            }
        }
    }

    private var previewUIImage: UIImage? {
        #if canImport(UIKit)
        guard let data = store.latestPreviewImageData else { return nil }
        return UIImage(data: data)
        #else
        return nil
        #endif
    }

    private func mapMetricLabel(_ title: String, value: String, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .bold).width(.condensed))
                .foregroundStyle(.white.opacity(0.74))
            Text(value)
                .font(.system(size: emphasized ? 34 : 21, weight: .bold).width(.condensed))
                .monospacedDigit()
                .foregroundStyle(emphasized ? Color(red: 1.0, green: 0.455, blue: 0.322) : .white)
        }
    }

    private var compactTrustBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "wave.3.right")
                .font(.caption.weight(.semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(model.trustBannerTitle)
                    .font(.caption2.weight(.semibold))
                Text(model.trustBannerDetail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var pageIndicators: some View {
        HStack(spacing: 5) {
            pageDot(for: .map)
            pageDot(for: .actions)
        }
        .padding(.top, 2)
    }

    private func pageDot(for panel: WatchRoundHomePanel) -> some View {
        Circle()
            .fill(selectedPanel == panel ? Color.white.opacity(0.92) : Color.white.opacity(0.28))
            .frame(width: selectedPanel == panel ? 6 : 5, height: selectedPanel == panel ? 6 : 5)
    }

    private var actionsPanel: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Actions")
                            .font(.headline.weight(.semibold))
                        Text(model.holeLabel)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(model.connectionLabel)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }

                if model.showsTrustBanner {
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

                NavigationLink {
                    WatchQuickShotView(store: store, model: model)
                } label: {
                    HStack {
                        Label("Log Shot", systemImage: "figure.golf")
                            .font(.headline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color(red: 0.075, green: 0.141, blue: 0.11))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.81, green: 0.89, blue: 0.77), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    NavigationLink {
                        WatchClubPickerView(store: store, model: model)
                    } label: {
                        actionTile(title: "Club", subtitle: model.clubLabel, systemImage: "square.grid.2x2")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        WatchHoleFinishView(store: store, model: model)
                    } label: {
                        actionTile(title: "Finish", subtitle: model.canFinishHole ? "Ready" : "Review", systemImage: "flag.pattern.checkered")
                    }
                    .buttonStyle(.plain)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    inlineActionButton("+Putt", systemImage: "plus.circle") {
                        store.sendAddPutt()
                    }
                    inlineActionButton("Penalty", systemImage: "exclamationmark.triangle") {
                        store.sendAddPenalty()
                    }
                    inlineActionButton("Drop", systemImage: "arrow.down.to.line") {
                        store.sendMarkDrop()
                    }
                    inlineActionButton("Undo", systemImage: "arrow.uturn.backward") {
                        store.sendUndoLastAction()
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func targetMarker(value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: "flag.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
            Text(value)
                .font(.system(size: 10, weight: .bold).width(.condensed))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.6), in: Capsule())
        }
    }

    private func actionTile(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption.weight(.semibold))
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func inlineActionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func fairwayShape(in size: CGSize) -> Path {
        let width = size.width
        let height = size.height

        return Path { path in
            path.move(to: CGPoint(x: width * 0.37, y: height * 0.92))
            path.addQuadCurve(
                to: CGPoint(x: width * 0.30, y: height * 0.44),
                control: CGPoint(x: width * 0.22, y: height * 0.72)
            )
            path.addQuadCurve(
                to: CGPoint(x: width * 0.42, y: height * 0.16),
                control: CGPoint(x: width * 0.26, y: height * 0.24)
            )
            path.addLine(to: CGPoint(x: width * 0.66, y: height * 0.16))
            path.addQuadCurve(
                to: CGPoint(x: width * 0.78, y: height * 0.46),
                control: CGPoint(x: width * 0.84, y: height * 0.28)
            )
            path.addQuadCurve(
                to: CGPoint(x: width * 0.63, y: height * 0.92),
                control: CGPoint(x: width * 0.88, y: height * 0.76)
            )
            path.closeSubpath()
        }
    }
}
