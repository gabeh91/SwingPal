import SwiftUI

/// The margin of the book, where a golfer pencils totals and tracks the
/// trend: a stroke line over comparable cards, one stated signal, then the
/// recorded figures by topic. Every number names its sample.
struct StatsView: View {
    let model: StatsViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedSection = "Scoring"
    @State private var selectedRound: RoundHistorySummary?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    header
                    if model.strokeLine.isEmpty {
                        emptyState
                    } else {
                        strokeLine
                        signal
                    }
                    if !model.recentRounds.isEmpty {
                        recordedFigures
                        history
                    }
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedRound) { HomeRoundAnalysisDetailView(summary: $0) }
        }
        .tint(Book.stamp)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SwingPal")
                .font(.system(.headline, weight: .heavy).width(.expanded))
            Text("Your numbers")
                .font(Book.Typeface.display)
                .accessibilityAddTraits(.isHeader)
            Text(sampleLine)
                .font(.subheadline)
                .foregroundStyle(Book.pencil)
        }
    }

    private var sampleLine: String {
        guard let latest = model.strokeLine.last else {
            return "Figures appear after your first completed card."
        }
        let count = model.strokeLine.count
        return "From \(count) completed \(latest.totalHoleCount)-hole card\(count == 1 ? "" : "s"). Course difficulty is not adjusted."
    }

    // MARK: Stroke line

    private var strokeLine: some View {
        let rounds = model.strokeLine
        let latest = rounds.last!
        let best = rounds.map(\.totalStrokes).min() ?? latest.totalStrokes
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(latest.totalStrokes)")
                        .font(.system(size: 72, weight: .bold).width(.condensed))
                        .monospacedDigit()
                    BookNote("Latest · \(latest.courseName)")
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(best)")
                        .font(.system(size: 34, weight: .bold).width(.condensed))
                        .monospacedDigit()
                        .foregroundStyle(Book.flag)
                    BookNote("Best")
                }
            }
            .accessibilityElement(children: .combine)

            if rounds.count > 1 {
                StrokeLineChart(rounds: rounds)
                    .frame(height: 150)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Strokes over the last \(rounds.count) cards")
                    .accessibilityValue(rounds.map { "\($0.totalStrokes)" }.joined(separator: ", "))
            }
        }
    }

    private var signal: some View {
        HStack(alignment: .top, spacing: 14) {
            Rectangle()
                .fill(toneColor)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.trendSignalTitle).font(.headline)
                Text(model.trendSignalDetail).font(.subheadline).foregroundStyle(Book.pencil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(model.trendSignalValue)
                .font(Book.Typeface.heading)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var toneColor: Color {
        switch model.trendSignalTone {
        case .positive: return Book.stamp
        case .caution: return Book.warning
        case .neutral: return Book.rule
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            GraphPaper()
                .frame(height: 150)
                .overlay {
                    Text("Your stroke line starts with your first signed card.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Book.pencil)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Book.paper)
                }
            Text("Scores, putts and penalties from completed rounds are totalled here. Drafts stay in your history without counting.")
                .font(.subheadline)
                .foregroundStyle(Book.pencil)
        }
    }

    // MARK: Figures

    private var recordedFigures: some View {
        VStack(alignment: .leading, spacing: 14) {
            BookSectionRule(title: "Recorded")
            if dynamicTypeSize.isAccessibilitySize {
                ForEach(model.sections, id: \.title) { sectionDetails($0) }
            } else {
                BookTabs(titles: model.sections.map(\.title), selection: $selectedSection)
                if let section = model.sections.first(where: { $0.title == selectedSection }) ?? model.sections.first {
                    sectionDetails(section)
                        .id(section.title)
                        .transition(.opacity)
                }
            }
        }
        .animation(.snappy(duration: 0.2), value: selectedSection)
    }

    private func sectionDetails(_ section: StatsSkillSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.summary)
                .font(.subheadline)
                .foregroundStyle(Book.pencil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            ForEach(section.facts, id: \.title) { fact in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.title).font(.body)
                        Text(fact.detail).font(.caption).foregroundStyle(Book.pencil)
                    }
                    Spacer(minLength: 12)
                    Text(fact.value)
                        .font(.system(size: 30, weight: .bold).width(.condensed))
                        .monospacedDigit()
                        .foregroundStyle(fact.value == "--" ? Book.pencil : Book.ink)
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
                BookHairline()
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 0) {
            BookSectionRule(title: "Cards", trailing: "\(model.recentRounds.count)").padding(.bottom, 6)
            ForEach(model.recentRounds) { round in
                Button { selectedRound = round } label: { ScorecardStub(round: round) }
                    .buttonStyle(BookRowButtonStyle())
                BookHairline()
            }
        }
    }
}
