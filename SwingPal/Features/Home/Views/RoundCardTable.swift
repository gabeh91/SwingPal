import SwiftUI

/// The round's card, hole by hole, ruled the way a paper one is: a grid per
/// nine with par, score (in scorecard notation), putts, and fairways and
/// greens hit. At accessibility text sizes it becomes one line per hole.
struct RoundCardTable: View {
    let holes: [RoundHistorySummary.HoleRecord]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    struct Nine: Identifiable {
        let id: Int
        let title: String
        let numbers: [Int]
        let holes: [Int: RoundHistorySummary.HoleRecord]

        var played: [RoundHistorySummary.HoleRecord] { numbers.compactMap { holes[$0] } }
    }

    /// The nines that have at least one scored hole, each with all nine
    /// columns so a part-played nine still reads as a card.
    static func nines(for holes: [RoundHistorySummary.HoleRecord]) -> [Nine] {
        let byNumber = Dictionary(holes.map { ($0.number, $0) }, uniquingKeysWith: { _, latest in latest })
        let highest = holes.map(\.number).max() ?? 0
        guard highest > 0 else { return [] }
        return stride(from: 1, through: highest, by: 9).compactMap { start -> Nine? in
            let numbers = Array(start...(start + 8))
            guard numbers.contains(where: { byNumber[$0] != nil }) else { return nil }
            let title = start == 1 ? "Out" : start == 10 ? "In" : "\(start)–\(start + 8)"
            return Nine(id: start, title: title, numbers: numbers, holes: byNumber)
        }
    }

    static func totalLine(for holes: [RoundHistorySummary.HoleRecord]) -> String {
        let strokes = holes.reduce(0) { $0 + $1.score }
        let toPar = holes.reduce(0) { $0 + $1.toPar }
        return "\(strokes) (\(toPar == 0 ? "E" : toPar > 0 ? "+\(toPar)" : "\(toPar)"))"
    }

    static func spoken(_ hole: RoundHistorySummary.HoleRecord) -> String {
        var parts = ["Hole \(hole.number)", "par \(hole.par)", ScoreMark.spoken(score: hole.score, par: hole.par)]
        if let putts = hole.putts { parts.append("\(putts) putt\(putts == 1 ? "" : "s")") }
        if hole.penalties > 0 { parts.append("\(hole.penalties) penalty stroke\(hole.penalties == 1 ? "" : "s")") }
        if let fairway = hole.fairwayHit { parts.append(fairway ? "fairway hit" : "fairway missed") }
        if let green = hole.greenInRegulation { parts.append(green ? "green in regulation" : "green missed") }
        return parts.joined(separator: ", ")
    }

    private var showsPutts: Bool { holes.contains { $0.putts != nil } }
    private var showsFairways: Bool { holes.contains { $0.fairwayHit != nil } }
    private var showsGreens: Bool { holes.contains { $0.greenInRegulation != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BookSectionRule(title: "Scorecard", trailing: Self.totalLine(for: holes))
            if dynamicTypeSize.isAccessibilitySize {
                holeList
            } else {
                VStack(spacing: 18) {
                    ForEach(Self.nines(for: holes)) { nine in
                        grid(nine)
                    }
                }
                .accessibilityRepresentation { holeList }
                if showsFairways || showsGreens {
                    HStack(spacing: 14) {
                        HStack(spacing: 6) { hitMark(true); Text("Hit") }
                        HStack(spacing: 6) { hitMark(false); Text("Missed") }
                    }
                    .font(.caption)
                    .foregroundStyle(Book.pencil)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: Grid

    private let labelWidth: CGFloat = 42
    private let totalWidth: CGFloat = 36
    private let rowHeight: CGFloat = 30
    private var cellFont: Font { .system(size: 14, weight: .regular).width(.condensed).monospacedDigit() }

    private func grid(_ nine: Nine) -> some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            BookHairline(color: Book.ink.opacity(0.8)).gridCellUnsizedAxes(.horizontal)
            GridRow {
                rowLabel("Hole")
                ForEach(nine.numbers, id: \.self) { number in
                    cell(Text("\(number)").fontWeight(.semibold).foregroundStyle(nine.holes[number] == nil ? Book.pencil : Book.ink))
                }
                totalCell(Text(nine.title.uppercased()).font(Book.Typeface.noteSmall).foregroundStyle(Book.pencil))
            }
            BookHairline().gridCellUnsizedAxes(.horizontal)
            GridRow {
                rowLabel("Par")
                ForEach(nine.numbers, id: \.self) { number in
                    cell(Text(nine.holes[number].map { "\($0.par)" } ?? "").foregroundStyle(Book.pencil))
                }
                totalCell(Text("\(nine.played.reduce(0) { $0 + $1.par })").foregroundStyle(Book.pencil))
            }
            BookHairline().gridCellUnsizedAxes(.horizontal)
            GridRow {
                rowLabel("Score")
                ForEach(nine.numbers, id: \.self) { number in
                    Group {
                        if let hole = nine.holes[number] {
                            ScoreMark(score: hole.score, par: hole.par, size: 22,
                                      font: .system(size: 14, weight: .semibold).width(.condensed))
                        } else {
                            Text("–").font(cellFont).foregroundStyle(Book.pencil)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: rowHeight + 4)
                }
                totalCell(Text("\(nine.played.reduce(0) { $0 + $1.score })").fontWeight(.bold))
            }
            if showsPutts {
                BookHairline().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    rowLabel("Putts")
                    ForEach(nine.numbers, id: \.self) { number in
                        cell(Text(nine.holes[number]?.putts.map { "\($0)" } ?? ""))
                    }
                    totalCell(Text("\(nine.played.reduce(0) { $0 + ($1.putts ?? 0) })"))
                }
            }
            if showsFairways {
                BookHairline().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    rowLabel("Fwy")
                    ForEach(nine.numbers, id: \.self) { number in
                        markCell(nine.holes[number]?.fairwayHit)
                    }
                    totalCell(Text(fraction(nine.played.compactMap(\.fairwayHit))))
                }
            }
            if showsGreens {
                BookHairline().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    rowLabel("GIR")
                    ForEach(nine.numbers, id: \.self) { number in
                        markCell(nine.holes[number]?.greenInRegulation)
                    }
                    totalCell(Text(fraction(nine.played.compactMap(\.greenInRegulation))))
                }
            }
            BookHairline(color: Book.ink.opacity(0.8)).gridCellUnsizedAxes(.horizontal)
        }
    }

    private func fraction(_ results: [Bool]) -> String {
        results.isEmpty ? "" : "\(results.filter { $0 }.count)/\(results.count)"
    }

    private func rowLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Book.Typeface.noteSmall)
            .foregroundStyle(Book.pencil)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: labelWidth, alignment: .leading)
            .frame(minHeight: rowHeight)
    }

    private func cell(_ text: Text) -> some View {
        text.font(cellFont)
            .frame(maxWidth: .infinity, minHeight: rowHeight)
    }

    private func totalCell(_ text: Text) -> some View {
        text.font(cellFont)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: totalWidth, alignment: .trailing)
            .frame(minHeight: rowHeight)
    }

    private func markCell(_ hit: Bool?) -> some View {
        Group {
            if let hit { hitMark(hit) } else { Color.clear.frame(width: 8, height: 8) }
        }
        .frame(maxWidth: .infinity, minHeight: rowHeight)
    }

    /// Filled for hit, hollow for missed: shape carries it, not colour.
    @ViewBuilder private func hitMark(_ hit: Bool) -> some View {
        if hit {
            Circle().fill(Book.stamp).frame(width: 8, height: 8)
        } else {
            Circle().strokeBorder(Book.pencil, lineWidth: 1.2).frame(width: 8, height: 8)
        }
    }

    // MARK: One line per hole

    private var holeList: some View {
        VStack(spacing: 0) {
            BookHairline(color: Book.ink.opacity(0.8))
            ForEach(holes, id: \.number) { hole in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hole \(hole.number)").font(.headline)
                        Text(Self.detail(hole)).font(.subheadline).foregroundStyle(Book.pencil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    ScoreMark(score: hole.score, par: hole.par, size: 40)
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.spoken(hole))
                BookHairline()
            }
        }
    }

    static func detail(_ hole: RoundHistorySummary.HoleRecord) -> String {
        var parts = ["Par \(hole.par)"]
        if let putts = hole.putts { parts.append("\(putts) putt\(putts == 1 ? "" : "s")") }
        if let fairway = hole.fairwayHit { parts.append(fairway ? "fairway hit" : "fairway missed") }
        if let green = hole.greenInRegulation { parts.append(green ? "green hit" : "green missed") }
        return parts.joined(separator: " · ")
    }
}
