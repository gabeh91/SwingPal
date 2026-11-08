import SwiftUI

struct HomeRoundAnalysisDetailView: View {
    let summary: RoundHistorySummary

    @State private var analysisState: ProfileViewModel.PreviousRoundAnalysisState = .loading
    @State private var analysisService = RoundSummaryAnalysisService()

    private var resolvedAnalysis: RoundSummaryAnalysis? {
        if case let .ready(analysis) = analysisState { return analysis }
        return nil
    }

    private var detailModel: HomeRoundDetailModel {
        HomeViewModel.roundDetailModel(for: summary, analysis: resolvedAnalysis)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header
                ledger
                notes
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 36)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Book.paper.ignoresSafeArea())
        .foregroundStyle(Book.ink)
        .navigationTitle("Round record")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: summary.id) { await loadAnalysis() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            BookNote(summary.updatedAt.formatted(date: .complete, time: .omitted))
            Text(summary.courseName)
                .font(Book.Typeface.display)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Circle()
                    .fill(summary.status == .finished ? Book.stamp : Book.flag)
                    .frame(width: 7, height: 7)
                Text(summary.status == .finished ? "Completed round" : "Draft · saved to resume")
                    .font(.subheadline.weight(.medium))
                Text("· \(summary.playerCount) golfer\(summary.playerCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(Book.pencil)
            }
        }
    }

    private var ledger: some View {
        VStack(spacing: 0) {
            BookHairline(color: Book.ink.opacity(0.8))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) { ledgerFigures(axis: .horizontal) }
                VStack(alignment: .leading, spacing: 0) { ledgerFigures(axis: .vertical) }
            }
            BookHairline()
            ForEach(Array(ledgerRows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0).foregroundStyle(Book.pencil)
                    Spacer()
                    Text(row.1).monospacedDigit()
                }
                .font(.subheadline)
                .padding(.vertical, 11)
                .accessibilityElement(children: .combine)
                BookHairline()
            }
        }
    }

    private var ledgerRows: [(String, String)] {
        [
            ("Progress", "Hole \(summary.holeNumber) of \(summary.totalHoleCount)"),
            ("Holes confirmed", "\(summary.completedHoleCount)"),
            ("Last saved", summary.updatedAt.formatted(date: .abbreviated, time: .shortened))
        ]
    }

    @ViewBuilder private func ledgerFigures(axis: Axis) -> some View {
        let figures = [("Strokes", summary.totalStrokes), ("Putts", summary.totalPutts), ("Penalties", summary.totalPenalties)]
        ForEach(Array(figures.enumerated()), id: \.offset) { index, figure in
            VStack(alignment: .leading, spacing: 0) {
                Text(summary.totalStrokes > 0 || figure.1 > 0 ? "\(figure.1)" : "–")
                    .font(.system(size: 44, weight: .bold).width(.condensed))
                    .monospacedDigit()
                BookNote(figure.0)
            }
            .frame(maxWidth: axis == .horizontal ? .infinity : nil, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.leading, index == 0 || axis == .vertical ? 0 : 14)
            .overlay(alignment: .leading) {
                if index > 0 && axis == .horizontal { Rectangle().fill(Book.rule).frame(width: 1) }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 14) {
            BookSectionRule(title: "Caddie’s notes", trailing: detailModel.analysisProviderLabel)
            if resolvedAnalysis == nil {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Reading this round’s record…").font(.subheadline).foregroundStyle(Book.pencil)
                }
                .padding(.vertical, 6)
            } else {
                Text(detailModel.analysisSummary)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(detailModel.analysisSections.enumerated()), id: \.offset) { index, section in
                    VStack(alignment: .leading, spacing: 10) {
                        BookNote(section.title, color: index == 0 ? Book.stamp : Book.warning)
                        if section.items.isEmpty {
                            Text("Nothing recorded for this yet.").font(.subheadline).foregroundStyle(Book.pencil)
                        }
                        ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("—").foregroundStyle(Book.pencil)
                                Text(item).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                if let generated = detailModel.analysisGeneratedAtTitle {
                    Text("Written \(generated) from this round’s totals. Totals are recorded facts; notes are interpretation.")
                        .font(.caption)
                        .foregroundStyle(Book.pencil)
                        .padding(.top, 4)
                }
            }
        }
    }

    @MainActor private func loadAnalysis() async {
        if let cached = analysisService.cachedAnalysis(for: summary) {
            analysisState = .ready(cached)
            return
        }
        analysisState = .loading
        let resolved = await resolveAnalysis()
        analysisState = .ready(resolved)
    }

    private func resolveAnalysis() async -> RoundSummaryAnalysis {
        if let analysis = try? await analysisService.analysis(for: summary) {
            return analysis
        }
        return RoundSummaryAnalysis(
            roundID: summary.id,
            cacheKey: RoundSummaryAnalysis.CacheKey(summary: summary).rawValue,
            provider: .deterministic,
            summary: ProfileViewModel.legacySummary(for: summary),
            whatWentWell: ProfileViewModel.legacyStrengths(for: summary),
            needsWork: ProfileViewModel.legacyImprovements(for: summary),
            generatedAt: Date(),
            updatedAt: nil
        )
    }
}
