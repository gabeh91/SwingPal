import SwiftUI

/// Home is the open yardage book: the selected course, one hole to a page,
/// and a thumb index down the page edge. The round action sits under the thumb.
struct HomeView: View {
    let model: HomeViewModel
    let entitlements: EntitlementState
    let onOpenRound: () -> Void
    let onOpenNearbyCourse: (UUID) -> Void
    let onOpenNearbyCourses: () -> Void
    let onOpenWatchCompanion: () -> Void
    var availableCourses: [SwingPalCourse] = []
    var activeHoleNumber: Int? = nil
    var confirmedHoleCount: Int? = nil

    @State private var chosenCourseID: UUID?
    @State private var pageIndex = 0
    @State private var hasOpenedAtActiveHole = false
    @State private var selectedAnalysisRound: RoundHistorySummary?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    masthead
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    if let course = selectedCourse, !course.holes.isEmpty {
                        coursePage(course)
                            .padding(.horizontal, 14)
                            .padding(.top, 16)
                    } else {
                        unavailablePage
                            .padding(.horizontal, 14)
                            .padding(.top, 16)
                    }
                    actions
                        .padding(.horizontal, 20)
                        .padding(.top, 22)
                    scorecards
                        .padding(.horizontal, 20)
                        .padding(.top, 40)
                    watchRow
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                }
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedAnalysisRound) { HomeRoundAnalysisDetailView(summary: $0) }
        }
        .tint(Book.stamp)
        .onAppear(perform: openAtActiveHole)
    }

    // MARK: Selection

    private var selectedCourse: SwingPalCourse? {
        if model.hasActiveRound, let active = availableCourses.first(where: { $0.name == model.heroSubtitle }) {
            return active
        }
        return availableCourses.first(where: { $0.id == chosenCourseID })
            ?? availableCourses.first(where: { $0.name == model.previousRounds.first?.courseName })
            ?? availableCourses.first
    }

    private func clampedIndex(_ course: SwingPalCourse) -> Int {
        min(max(pageIndex, 0), max(course.holes.count - 1, 0))
    }

    private func openAtActiveHole() {
        guard !hasOpenedAtActiveHole else { return }
        hasOpenedAtActiveHole = true
        if model.hasActiveRound, let activeHoleNumber,
           let index = selectedCourse?.holes.firstIndex(where: { $0.number == activeHoleNumber }) {
            pageIndex = index
        }
    }

    // MARK: Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("SwingPal")
                    .font(.system(.headline, weight: .heavy).width(.expanded))
                    .tracking(-0.2)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if model.handicapBadgeText.contains(where: \.isNumber) {
                    BookNote("HCP \(model.handicapBadgeText)")
                }
            }
            courseTitle
            courseSubtitle
        }
    }

    @ViewBuilder private var courseTitle: some View {
        let name = selectedCourse?.name ?? (model.hasActiveRound ? model.heroSubtitle : "Choose a course")
        if model.hasActiveRound {
            Text(name)
                .font(Book.Typeface.display)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Menu {
                ForEach(availableCourses) { course in
                    Button {
                        chosenCourseID = course.id
                        pageIndex = 0
                    } label: {
                        if course.id == selectedCourse?.id { Label(course.name, systemImage: "checkmark") }
                        else { Text(course.name) }
                    }
                }
                Divider()
                Button("Find another course", systemImage: "magnifyingglass", action: onOpenNearbyCourses)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(name)
                        .font(Book.Typeface.display)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.down")
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(Book.pencil)
                }
                .foregroundStyle(Book.ink)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Course, \(name)")
            .accessibilityHint("Choose another course")
        }
    }

    @ViewBuilder private var courseSubtitle: some View {
        if model.hasActiveRound {
            HStack(spacing: 8) {
                Circle().fill(Book.flag).frame(width: 7, height: 7)
                Text(activeRoundLine).font(.subheadline.weight(.medium))
            }
            .accessibilityElement(children: .combine)
        } else if let course = selectedCourse {
            Text(courseFacts(course))
                .font(.subheadline)
                .foregroundStyle(Book.pencil)
        }
    }

    private var activeRoundLine: String {
        var parts = ["Round in progress"]
        if let activeHoleNumber { parts.append("playing hole \(activeHoleNumber)") }
        if let confirmedHoleCount { parts.append("\(confirmedHoleCount) confirmed") }
        return parts.joined(separator: " · ")
    }

    private func courseFacts(_ course: SwingPalCourse) -> String {
        var parts = ["\(course.holeCount) holes", "Par \(course.par)"]
        if let source = course.sourceReferences.first?.kind.label { parts.append("\(source) geometry") }
        return parts.joined(separator: " · ")
    }

    // MARK: The page

    private func coursePage(_ course: SwingPalCourse) -> some View {
        let index = clampedIndex(course)
        let hole = course.holes[index]
        let projection = HoleProjection(hole: hole)
        let hasGeometry = projection != nil
        return ZStack {
            // The pages beneath: a book, not a card.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Book.leaf)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Book.rule))
                .padding(.horizontal, 10)
                .offset(y: 9)
                .accessibilityHidden(true)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Book.leaf)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Book.rule))
                .padding(.horizontal, 5)
                .offset(y: 4.5)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                pageHeader(hole: hole, projection: projection)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                HStack(alignment: .top, spacing: 0) {
                    ZStack {
                        if hasGeometry {
                            HolePageDrawing(
                                hole: hole,
                                neighbours: course.holes,
                                distanceUnit: model.distanceUnit,
                                insets: EdgeInsets(top: 34, leading: 26, bottom: 26, trailing: 18)
                            )
                            .id(hole.number)
                            .transition(.opacity)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "map").font(.title2)
                                Text("No layout recorded for this hole")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(Book.pencil)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .gesture(pageSwipe(count: course.holes.count))

                    if !dynamicTypeSize.isAccessibilitySize {
                        ThumbIndex(
                            numbers: course.holes.map(\.number),
                            selection: Binding(get: { index }, set: { pageIndex = $0 }),
                            marked: model.hasActiveRound ? activeHoleNumber : nil
                        )
                        .padding(.vertical, 10)
                    }
                }
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 280 : pageHeight)

                if dynamicTypeSize.isAccessibilitySize {
                    Stepper("Hole \(hole.number)", value: Binding(get: { index }, set: { pageIndex = $0 }),
                            in: 0...max(course.holes.count - 1, 0))
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 10)
                }

                pageFooter(course: course, hole: hole, index: index)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
            }
            .background(Book.leaf, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Book.rule).allowsHitTesting(false))
            .shadow(color: Book.ink.opacity(0.07), radius: 16, y: 10)
        }
        .padding(.bottom, 9)
    }

    private var pageHeight: CGFloat { 404 }

    private func pageHeader(hole: SwingPalCourse.Hole, projection: HoleProjection?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(String(format: "%02d", hole.number))
                .font(Book.Typeface.folio)
                .contentTransition(.numericText(value: Double(hole.number)))
                .accessibilityLabel("Hole \(hole.number)")
            VStack(alignment: .leading, spacing: 3) {
                Text("Par \(hole.par)")
                    .font(Book.Typeface.heading)
                if let metres = projection?.teeToGreenMetres {
                    Text("\(model.distanceUnit.shortLabel(forMeters: metres)) tee to green centre")
                        .font(.caption)
                        .foregroundStyle(Book.pencil)
                }
            }
            Spacer(minLength: 0)
            hazardNotes(hole)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func hazardNotes(_ hole: SwingPalCourse.Hole) -> some View {
        let bunkers = hole.features.filter { $0.kind == .bunker }.count
        let water = hole.features.contains { $0.kind == .water }
        if bunkers > 0 || water {
            VStack(alignment: .trailing, spacing: 3) {
                if bunkers > 0 { BookNote("\(bunkers) bunker\(bunkers == 1 ? "" : "s")") }
                if water { BookNote("Water", color: Book.waterLine) }
            }
        }
    }

    private func pageFooter(course: SwingPalCourse, hole: SwingPalCourse.Hole, index: Int) -> some View {
        HStack {
            if model.hasActiveRound, hole.number == activeHoleNumber {
                HStack(spacing: 6) {
                    Circle().fill(Book.flag).frame(width: 6, height: 6)
                    BookNote("Your current hole", color: Book.ink)
                }
            } else {
                BookNote(course.quality.readinessLabel)
            }
            Spacer()
            BookNote("Page \(index + 1) of \(course.holes.count)")
        }
        .accessibilityElement(children: .combine)
    }

    private func pageSwipe(count: Int) -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > abs(value.translation.height) * 1.4, abs(dx) > 44 else { return }
                let next = min(max(pageIndex + (dx < 0 ? 1 : -1), 0), max(count - 1, 0))
                guard next != pageIndex else { return }
                if reduceMotion { pageIndex = next }
                else { withAnimation(.snappy(duration: 0.2)) { pageIndex = next } }
            }
    }

    private var unavailablePage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "map").font(.title).foregroundStyle(Book.pencil)
            Text(selectedCourse == nil ? "Your book is empty" : "No hole layouts yet")
                .font(Book.Typeface.heading)
            Text(selectedCourse == nil
                 ? "Find a course to add its holes. Search works without location access."
                 : "This course has no hole geometry. You can still play and score it.")
                .font(.subheadline)
                .foregroundStyle(Book.pencil)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bookLeaf()
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                if model.hasActiveRound { onOpenRound() }
                else if let course = selectedCourse { onOpenNearbyCourse(course.id) }
                else { onOpenNearbyCourses() }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primaryTitle).font(.headline)
                        if let primaryDetail {
                            Text(primaryDetail).font(.subheadline).opacity(0.78)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: model.hasActiveRound ? "play.fill" : "arrow.right")
                        .font(.headline)
                }
            }
            .buttonStyle(BookStampButtonStyle())

            if !model.hasActiveRound {
                Button(action: onOpenNearbyCourses) {
                    Label("Find another course", systemImage: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Book.ink)
            }
        }
    }

    private var primaryTitle: String {
        if model.hasActiveRound { return "Resume round" }
        return selectedCourse == nil ? "Find a course" : "Tee off here"
    }

    private var primaryDetail: String? {
        if model.hasActiveRound {
            return activeHoleNumber.map { "Back to hole \($0)" }
        }
        return selectedCourse.map { "Choose tees and players for \($0.name)" }
    }

    // MARK: Scorecards

    private var scorecards: some View {
        VStack(alignment: .leading, spacing: 6) {
            BookSectionRule(title: "Scorecards", trailing: model.previousRounds.isEmpty ? nil : "\(model.previousRounds.count)")
                .padding(.bottom, 6)
            if model.previousRounds.isEmpty {
                emptyScorecard
            } else {
                ForEach(model.previousRounds.prefix(4)) { round in
                    Button { selectedAnalysisRound = round } label: {
                        ScorecardStub(round: round)
                    }
                    .buttonStyle(BookRowButtonStyle())
                    BookHairline()
                }
            }
        }
    }

    private var emptyScorecard: some View {
        HStack(alignment: .center, spacing: 18) {
            BlankScorecardGlyph()
                .frame(width: 92, height: 50)
            VStack(alignment: .leading, spacing: 4) {
                Text("No cards filed yet").font(.headline)
                Text("Rounds you save are kept here, newest first.")
                    .font(.subheadline)
                    .foregroundStyle(Book.pencil)
            }
        }
        .padding(.vertical, 10)
    }

    private var watchRow: some View {
        Button(action: onOpenWatchCompanion) {
            HStack(spacing: 14) {
                Image(systemName: "applewatch.side.right")
                    .font(.title3)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Watch").font(.headline)
                    Text("Yardages and quick shots on your wrist")
                        .font(.subheadline)
                        .foregroundStyle(Book.pencil)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Book.pencil)
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(BookRowButtonStyle())
        .overlay(alignment: .top) { BookHairline() }
        .overlay(alignment: .bottom) { BookHairline() }
    }
}

/// A saved round as a stub torn from its card: date on the stub, course and
/// record in the body, strokes as the figure.
struct ScorecardStub: View {
    let round: RoundHistorySummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: -2) {
                Text(round.updatedAt.formatted(.dateTime.day()))
                    .font(Book.Typeface.title)
                    .monospacedDigit()
                BookNote(round.updatedAt.formatted(.dateTime.month(.abbreviated)))
            }
            .frame(minWidth: 42)

            Rectangle()
                .fill(.clear)
                .frame(width: 1)
                .overlay {
                    GeometryReader { g in
                        Path { p in
                            p.move(to: .zero)
                            p.addLine(to: CGPoint(x: 0, y: g.size.height))
                        }
                        .stroke(Book.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(round.courseName)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Book.pencil)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                Text(round.totalStrokes > 0 ? "\(round.totalStrokes)" : "–")
                    .font(Book.Typeface.figure)
                BookNote(round.status == .finished ? "Strokes" : "Draft",
                         color: round.status == .finished ? Book.pencil : Book.flag)
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the round record")
    }

    private var detail: String {
        if round.status == .finished {
            return "\(round.totalPutts) putts · \(round.totalPenalties) penalt\(round.totalPenalties == 1 ? "y" : "ies")"
        }
        return "Saved at hole \(round.holeNumber) · \(round.completedHoleCount) of \(round.totalHoleCount) confirmed"
    }
}

/// A blank card: two rows of nine cells, drawn in hairline.
struct BlankScorecardGlyph: View {
    var body: some View {
        Canvas { context, size in
            let cols = 9, rows = 2
            let w = size.width / CGFloat(cols), h = size.height / CGFloat(rows + 1)
            var grid = Path()
            grid.addRect(CGRect(x: 0.5, y: 0.5, width: size.width - 1, height: size.height - 1))
            for c in 1..<cols { grid.move(to: CGPoint(x: CGFloat(c) * w, y: 0)); grid.addLine(to: CGPoint(x: CGFloat(c) * w, y: size.height)) }
            for r in 1...rows { grid.move(to: CGPoint(x: 0, y: CGFloat(r) * h)); grid.addLine(to: CGPoint(x: size.width, y: CGFloat(r) * h)) }
            context.stroke(grid, with: .color(Book.pencil.opacity(0.6)), lineWidth: 0.8)
            for c in 0..<cols {
                context.draw(Text("\(c + 1)").font(.system(size: 8, weight: .semibold).width(.condensed)).foregroundColor(Book.pencil),
                             at: CGPoint(x: CGFloat(c) * w + w / 2, y: h / 2))
            }
            let mark = Path(ellipseIn: CGRect(x: 2 * w + w / 2 - 5, y: h * 1.5 - 5, width: 10, height: 10))
            context.stroke(mark, with: .color(Book.flag), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Round record

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
