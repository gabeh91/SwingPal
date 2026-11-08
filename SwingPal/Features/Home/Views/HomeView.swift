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
