import SwiftUI

private struct HomePalette {
    let backgroundBase: Color
    let backgroundTopGlow: Color
    let backgroundBottomGlow: Color
    let cardTint: Color
    let cardStrongTint: Color
    let cardMutedTint: Color
    let border: Color
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    let accent: Color
    let accentForeground: Color
    let quietFill: Color
    let premiumTint: Color
    let premiumBorder: Color
    let shadow: Color
    let glassHighlight: Color

    static func forColorScheme(_ colorScheme: ColorScheme) -> HomePalette {
        switch colorScheme {
        case .dark:
            return .init(
                backgroundBase: Color(red: 0.05, green: 0.08, blue: 0.07),
                backgroundTopGlow: Color(red: 0.18, green: 0.30, blue: 0.22).opacity(0.54),
                backgroundBottomGlow: Color(red: 0.10, green: 0.15, blue: 0.13).opacity(0.72),
                cardTint: Color.white.opacity(0.08),
                cardStrongTint: Color(red: 0.16, green: 0.22, blue: 0.19).opacity(0.78),
                cardMutedTint: Color(red: 0.14, green: 0.18, blue: 0.16).opacity(0.62),
                border: Color.white.opacity(0.22),
                primaryText: Color.white.opacity(0.96),
                secondaryText: Color.white.opacity(0.82),
                tertiaryText: Color.white.opacity(0.62),
                accent: ShellTokens.ColorRole.pine500,
                accentForeground: .white,
                quietFill: Color.white.opacity(0.08),
                premiumTint: Color(red: 0.27, green: 0.21, blue: 0.10).opacity(0.72),
                premiumBorder: Color(red: 0.90, green: 0.72, blue: 0.36).opacity(0.40),
                shadow: Color.black.opacity(0.34),
                glassHighlight: Color.white.opacity(0.14)
            )
        default:
            return .init(
                backgroundBase: Color(red: 0.95, green: 0.96, blue: 0.92),
                backgroundTopGlow: Color(red: 0.84, green: 0.92, blue: 0.80).opacity(0.78),
                backgroundBottomGlow: Color(red: 0.97, green: 0.95, blue: 0.89).opacity(0.66),
                cardTint: Color.white.opacity(0.56),
                cardStrongTint: Color(red: 0.90, green: 0.95, blue: 0.89).opacity(0.88),
                cardMutedTint: Color.white.opacity(0.40),
                border: Color.white.opacity(0.42),
                primaryText: ShellTokens.ColorRole.textPrimary,
                secondaryText: ShellTokens.ColorRole.textSecondary,
                tertiaryText: ShellTokens.ColorRole.textTertiary,
                accent: ShellTokens.ColorRole.pine700,
                accentForeground: .white,
                quietFill: Color.white.opacity(0.44),
                premiumTint: Color(red: 0.97, green: 0.93, blue: 0.82).opacity(0.92),
                premiumBorder: Color(red: 0.82, green: 0.69, blue: 0.38).opacity(0.54),
                shadow: Color.black.opacity(0.10),
                glassHighlight: Color.white.opacity(0.24)
            )
        }
    }
}

struct HomeView: View {
    let model: HomeViewModel
    let entitlements: EntitlementState
    let onOpenRound: () -> Void
    let onOpenNearbyCourse: (UUID) -> Void
    let onOpenNearbyCourses: () -> Void
    let onOpenWatchCompanion: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedAnalysisRound: RoundHistorySummary?
    @State private var isHeroPillListExpanded = false

    private var palette: HomePalette {
        HomePalette.forColorScheme(colorScheme)
    }

    private var recentFormColumns: [GridItem] {
        if horizontalSizeClass == .compact {
            return [
                GridItem(.flexible(), spacing: ShellTokens.Spacing.x12),
                GridItem(.flexible(), spacing: ShellTokens.Spacing.x12)
            ]
        }

        return Array(repeating: GridItem(.flexible(), spacing: ShellTokens.Spacing.x12), count: 4)
    }

    private var usesCompactHeroLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var compactHeroPillPresentation: ShellTokens.PillLayout.CompactPresentation {
        ShellTokens.PillLayout.compactPresentation(
            from: model.heroHighlights + [model.handicapBadgeText],
            isExpanded: isHeroPillListExpanded
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x20) {
                    masthead
                    roundActionCard
                    recentFormSection
                    latestAnalysisCard
                    if !model.hasActiveRound {
                        nearbyCoursesCard
                    }

                    watchCompanionPanel
                }
                .padding(.horizontal, ShellTokens.Spacing.x20)
                .padding(.top, ShellTokens.Spacing.x20)
                .padding(.bottom, ShellTokens.Spacing.x32 + AppChromeMetrics.bottomContentInset)
            }
            .background(background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedAnalysisRound) { summary in
                HomeRoundAnalysisDetailView(summary: summary)
            }
        }
    }

    private var background: some View {
        ZStack {
            palette.backgroundBase

            LinearGradient(
                colors: [
                    palette.backgroundTopGlow,
                    palette.backgroundBase,
                    palette.backgroundBottomGlow
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette.accent.opacity(colorScheme == .dark ? 0.16 : 0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 42)
                .offset(x: 156, y: -176)

            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.03 : 0.24))
                .frame(width: 240, height: 240)
                .blur(radius: 36)
                .offset(x: -142, y: 188)
        }
        .ignoresSafeArea()
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
            HStack(alignment: .center) {
                Text("HOME BASE")
                    .font(ShellTokens.Typography.eyebrow)
                    .tracking(1.2)
                    .foregroundStyle(palette.accent)

                Spacer()

                Text(model.mastheadEditionLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(palette.quietFill, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(palette.border, lineWidth: 1)
                    }
            }

            Text("Home")
                .font(ShellTokens.Typography.mastheadTitle)
                .foregroundStyle(palette.primaryText)

            Text("Move into your next round fast, scan recent form, and keep the smartest context close.")
                .font(ShellTokens.Typography.lead)
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
        }
    }

    private var roundActionCard: some View {
        cardContainer(tint: palette.cardStrongTint, padding: 24) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x18) {
                if usesCompactHeroLayout {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ROUND ACTION")
                                .font(ShellTokens.Typography.microEyebrow)
                                .tracking(1.2)
                                .foregroundStyle(palette.tertiaryText)

                            Text(model.heroTitle)
                                .font(ShellTokens.Typography.sectionTitle)
                                .foregroundStyle(palette.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text(model.heroTitle == "Resume Round" ? "Live round" : "Ready to play")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(palette.quietFill, in: Capsule())
                    }
                } else {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ROUND ACTION")
                                .font(ShellTokens.Typography.microEyebrow)
                                .tracking(1.2)
                                .foregroundStyle(palette.tertiaryText)

                            Text(model.heroTitle)
                                .font(ShellTokens.Typography.sectionTitle)
                                .foregroundStyle(palette.primaryText)
                        }

                        Spacer()

                        Text(model.heroTitle == "Resume Round" ? "Live round" : "Ready to play")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(palette.quietFill, in: Capsule())
                    }
                }

                Text(model.heroSubtitle)
                    .font(ShellTokens.Typography.cardTitle)
                    .foregroundStyle(palette.primaryText)

                Text(model.heroDeck)
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)

                if usesCompactHeroLayout {
                    ShellCompactPillFlow(spacing: ShellTokens.Spacing.x8) {
                        ForEach(compactHeroPillPresentation.visibleTexts, id: \.self) { text in
                            heroPill(text)
                        }
                        if compactHeroPillPresentation.showsCollapseControl {
                            heroOverflowPill("Less") {
                                isHeroPillListExpanded = false
                            }
                        } else if compactHeroPillPresentation.overflowCount > 0 {
                            heroOverflowPill("+\(compactHeroPillPresentation.overflowCount)") {
                                isHeroPillListExpanded = true
                            }
                        }
                    }
                } else {
                    HStack(spacing: ShellTokens.Spacing.x8) {
                        ForEach(model.heroHighlights, id: \.self) { highlight in
                            heroPill(highlight)
                        }
                        heroPill(model.handicapBadgeText)
                    }
                }

                if usesCompactHeroLayout {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                        Button(action: onOpenRound) {
                            HStack(spacing: 10) {
                                Text(model.heroPrimaryActionTitle)
                                    .font(.headline.weight(.semibold))
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(palette.accentForeground)
                            .padding(.horizontal, ShellTokens.Spacing.x18)
                            .padding(.vertical, ShellTokens.Spacing.x12)
                            .background(palette.accent, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Priority")
                                .font(ShellTokens.Typography.microEyebrow)
                                .tracking(1.0)
                                .foregroundStyle(palette.tertiaryText)
                            Text(priorityLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)
                        }
                    }
                } else {
                    HStack(spacing: ShellTokens.Spacing.x12) {
                        Button(action: onOpenRound) {
                            HStack(spacing: 10) {
                                Text(model.heroPrimaryActionTitle)
                                    .font(.headline.weight(.semibold))
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(palette.accentForeground)
                            .padding(.horizontal, ShellTokens.Spacing.x18)
                            .padding(.vertical, ShellTokens.Spacing.x12)
                            .background(palette.accent, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Priority")
                                .font(ShellTokens.Typography.microEyebrow)
                                .tracking(1.0)
                                .foregroundStyle(palette.tertiaryText)
                            Text(priorityLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)
                        }
                    }
                }
            }
        }
    }

    private var recentFormSection: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            sectionHeader(
                eyebrow: "RECENT FORM",
                title: "Fast stats you can actually scan",
                subtitle: "Your last score, plus rolling averages from recent rounds."
            )

            LazyVGrid(columns: recentFormColumns, spacing: ShellTokens.Spacing.x12) {
                ForEach(model.quickStats, id: \.title) { stat in
                    recentFormCard(stat)
                }
            }
        }
    }

    private var latestAnalysisCard: some View {
        Button {
            selectedAnalysisRound = model.spotlightRound
        } label: {
            cardContainer(tint: palette.cardTint, padding: 22) {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.spotlight.eyebrow.uppercased())
                                .font(ShellTokens.Typography.microEyebrow)
                                .tracking(1.2)
                                .foregroundStyle(palette.tertiaryText)

                            Text(model.spotlight.title)
                                .font(ShellTokens.Typography.cardTitle)
                                .foregroundStyle(palette.primaryText)
                        }

                        Spacer()

                        Image(systemName: "sparkles")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.accent)
                            .frame(width: 38, height: 38)
                            .background(palette.quietFill, in: Circle())
                    }

                    if let insight = model.insights.first {
                        Text(insight.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(palette.primaryText)

                        Text(insight.detail)
                            .font(ShellTokens.Typography.body)
                            .foregroundStyle(palette.secondaryText)
                            .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
                    } else {
                        Text(model.spotlight.subtitle)
                            .font(ShellTokens.Typography.body)
                            .foregroundStyle(palette.secondaryText)
                            .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
                    }

                    HStack {
                        Text(model.spotlight.actionTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.accent)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.accent)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(model.spotlightRound == nil)
    }

    private var nearbyCoursesCard: some View {
        cardContainer(tint: palette.cardMutedTint, padding: 22) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                sectionHeader(
                    eyebrow: "NEARBY COURSES",
                    title: "Pick a course and roll straight into setup",
                    subtitle: "Start with the closest options here, then open the full nearby list when you want to compare."
                )

                VStack(spacing: ShellTokens.Spacing.x10) {
                    ForEach(model.nearbyCoursePreview, id: \.courseID) { course in
                        nearbyCourseRow(course)
                    }
                }

                Button(action: onOpenNearbyCourses) {
                    HStack {
                        Text(model.nearbyCoursesActionTitle)
                            .font(.headline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(palette.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var watchCompanionPanel: some View {
        cardContainer(
            tint: entitlements == .premium ? palette.cardTint : palette.premiumTint,
            padding: 22,
            borderColor: entitlements == .premium ? palette.border : palette.premiumBorder
        ) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("APPLE WATCH COMPANION")
                            .font(ShellTokens.Typography.microEyebrow)
                            .tracking(1.2)
                            .foregroundStyle(palette.accent)

                        Text(entitlements == .premium ? "Open your live watch companion." : "Unlock live round control from your wrist.")
                            .font(ShellTokens.Typography.cardTitle)
                            .foregroundStyle(palette.primaryText)
                    }

                    Spacer()

                    Image(systemName: "applewatch.side.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.accent)
                }

                Text(
                    entitlements == .premium
                    ? "Check connection status and jump back into your active round."
                    : "Control key round actions from your wrist."
                )
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)

                ViewThatFits(in: .vertical) {
                    HStack(spacing: ShellTokens.Spacing.x8) {
                        premiumPill("Quick actions")
                        premiumPill("Live yardages")
                        premiumPill("Stay in rhythm")
                    }

                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                        premiumPill("Quick actions")
                        premiumPill("Live yardages")
                        premiumPill("Stay in rhythm")
                    }
                }

                Button(action: onOpenWatchCompanion) {
                    HStack {
                        Text(entitlements == .premium ? "Open Apple Watch companion" : "Unlock Apple Watch features")
                            .font(.headline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(entitlements == .premium ? palette.primaryText : palette.primaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cardContainer<Content: View>(
        tint: Color,
        padding: CGFloat,
        borderColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        return VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(padding)
        .background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(tint)
            }
        }
        .overlay {
            shape
                .stroke(borderColor ?? palette.border, lineWidth: 1)
                .overlay {
                    shape
                        .stroke(palette.glassHighlight, lineWidth: 1)
                        .blur(radius: 0.2)
                        .padding(1)
                }
        }
        .shadow(color: palette.shadow, radius: 18, y: 10)
    }

    private func sectionHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(ShellTokens.Typography.microEyebrow)
                .tracking(1.2)
                .foregroundStyle(palette.tertiaryText)

            Text(title)
                .font(ShellTokens.Typography.sectionTitle)
                .foregroundStyle(palette.primaryText)

            Text(subtitle)
                .font(ShellTokens.Typography.body)
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
        }
    }

    private func heroPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(palette.quietFill, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(palette.border, lineWidth: 1)
            }
    }

    private func heroOverflowPill(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            heroPill(text)
        }
        .buttonStyle(.plain)
    }

    private func recentFormCard(_ stat: HomeQuickStat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stat.title.uppercased())
                .font(ShellTokens.Typography.microEyebrow)
                .tracking(1.0)
                .foregroundStyle(palette.tertiaryText)

            Text(stat.value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()

            Text(stat.note)
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.secondaryText)
        }
        .padding(ShellTokens.Spacing.x16)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.quietFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
    }

    private func nearbyCourseRow(_ course: HomeNearbyCoursePreview) -> some View {
        Button {
            onOpenNearbyCourse(course.courseID)
        } label: {
            HStack(alignment: .center, spacing: ShellTokens.Spacing.x12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(palette.primaryText)

                    Text(course.detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                Text(course.distanceLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(palette.quietFill, in: Capsule())
            }
            .padding(.horizontal, ShellTokens.Spacing.x14)
            .padding(.vertical, ShellTokens.Spacing.x12)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(palette.quietFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func premiumPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(palette.quietFill, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(palette.premiumBorder, lineWidth: 1)
            }
    }

    private var priorityLabel: String {
        switch model.modules.first {
        case .insights:
            return "Insight-led"
        case .recentRounds:
            return "Round history"
        case .nearbyCourses:
            return "Plan nearby"
        case nil:
            return "Insight-led"
        }
    }
}

struct HomeRoundAnalysisDetailView: View {
    let summary: RoundHistorySummary

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var analysisState: ProfileViewModel.PreviousRoundAnalysisState = .loading
    @State private var analysisService = RoundSummaryAnalysisService()

    private var palette: HomePalette {
        HomePalette.forColorScheme(colorScheme)
    }

    private var sheetModel: ProfileViewModel.PreviousRoundSheetModel {
        ProfileViewModel.previousRoundSheetModel(for: summary)
    }

    private var resolvedAnalysis: RoundSummaryAnalysis? {
        switch analysisState {
        case .idle, .loading:
            return nil
        case let .ready(analysis):
            return analysis
        }
    }

    private var detailModel: HomeRoundDetailModel {
        HomeViewModel.roundDetailModel(for: summary, analysis: resolvedAnalysis)
    }

    private var heroMetricColumns: [GridItem] {
        if horizontalSizeClass == .compact {
            return [
                GridItem(.flexible(), spacing: ShellTokens.Spacing.x12),
                GridItem(.flexible(), spacing: ShellTokens.Spacing.x12)
            ]
        }

        return [
            GridItem(.flexible(), spacing: ShellTokens.Spacing.x12),
            GridItem(.flexible(), spacing: ShellTokens.Spacing.x12),
            GridItem(.flexible(), spacing: ShellTokens.Spacing.x12)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x20) {
                detailHeader
                heroMetricRail
                roundFacts
                analysisSection
            }
            .padding(.horizontal, ShellTokens.Spacing.x20)
            .padding(.top, ShellTokens.Spacing.x20)
            .padding(.bottom, ShellTokens.Spacing.x32 + AppChromeMetrics.bottomContentInset)
        }
        .background(detailBackground)
        .navigationTitle("Round Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: summary.id) {
            await loadAnalysis()
        }
    }

    private var detailBackground: some View {
        ZStack {
            palette.backgroundBase

            LinearGradient(
                colors: [
                    palette.backgroundTopGlow,
                    palette.backgroundBase,
                    palette.backgroundBottomGlow
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var detailHeader: some View {
        detailCard(tint: palette.cardStrongTint, padding: 24) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
                Text("ROUND ANALYSIS")
                    .font(ShellTokens.Typography.microEyebrow)
                    .tracking(1.2)
                    .foregroundStyle(palette.tertiaryText)

                Text(detailModel.title)
                    .font(ShellTokens.Typography.sectionTitle)
                    .foregroundStyle(palette.primaryText)

                Text(detailModel.statusTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.accent)

                Text(detailModel.statusDeck)
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
            }
        }
    }

    private var heroMetricRail: some View {
        LazyVGrid(
            columns: heroMetricColumns,
            spacing: ShellTokens.Spacing.x12
        ) {
            ForEach(detailModel.heroMetrics, id: \.title) { metric in
                heroMetricCard(metric)
            }
        }
    }

    private var roundFacts: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            sectionHeader(
                eyebrow: "ROUND SNAPSHOT",
                title: "Round context",
                subtitle: "The AI brief is anchored to this exact saved round and its logged scoring detail."
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: ShellTokens.Spacing.x12),
                    GridItem(.flexible(), spacing: ShellTokens.Spacing.x12)
                ],
                spacing: ShellTokens.Spacing.x12
            ) {
                ForEach(detailModel.supportMetrics, id: \.title) { metric in
                    detailFactCard(metric)
                }
                detailFactCard(.init(title: "Status", value: sheetModel.statusDetail, note: nil))
                detailFactCard(.init(title: "Updated", value: summary.updatedAt.formatted(date: .abbreviated, time: .shortened), note: nil))
            }
        }
    }

    private var analysisSection: some View {
        detailCard(tint: palette.cardTint, padding: 22) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                HStack(alignment: .center, spacing: ShellTokens.Spacing.x10) {
                        Text("AI ROUND BRIEF")
                            .font(ShellTokens.Typography.microEyebrow)
                            .tracking(1.2)
                            .foregroundStyle(palette.tertiaryText)

                    Spacer()

                    switch analysisState {
                    case .loading:
                        HomeAnalysisLoadingGlyph(accent: palette.accent)
                    case .idle, .ready:
                        Image(systemName: "sparkles")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.accent)
                    }
                }

                HStack(spacing: ShellTokens.Spacing.x8) {
                    detailMetaPill(detailModel.analysisProviderLabel)
                    if let generatedAtTitle = detailModel.analysisGeneratedAtTitle {
                        detailMetaPill(generatedAtTitle)
                    }
                }

                Text(detailModel.analysisSummary)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                if resolvedAnalysis != nil {
                    Text("Read the round as a story first, then drop into the strongest positives and the clearest scoring leaks.")
                        .font(ShellTokens.Typography.body)
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)

                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                        ForEach(Array(detailModel.analysisSections.enumerated()), id: \.offset) { index, section in
                            detailAnalysisCard(
                                title: section.title,
                                items: section.items,
                                accent: index == 0 ? palette.accent.opacity(0.9) : Color.orange.opacity(0.9)
                            )
                        }
                    }
                } else {
                    Text("The saved round context is ready. The AI brief is being resolved for this specific round now.")
                        .font(ShellTokens.Typography.body)
                        .foregroundStyle(palette.secondaryText)
                }
            }
        }
    }

    private func detailCard<Content: View>(
        tint: Color,
        padding: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        return VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(padding)
        .background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(tint)
            }
        }
        .overlay {
            shape
                .stroke(palette.border, lineWidth: 1)
                .overlay {
                    shape
                        .stroke(palette.glassHighlight, lineWidth: 1)
                        .blur(radius: 0.2)
                        .padding(1)
                }
        }
        .shadow(color: palette.shadow, radius: 18, y: 10)
    }

    private func sectionHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(ShellTokens.Typography.microEyebrow)
                .tracking(1.2)
                .foregroundStyle(palette.tertiaryText)

            Text(title)
                .font(ShellTokens.Typography.sectionTitle)
                .foregroundStyle(palette.primaryText)

            Text(subtitle)
                .font(ShellTokens.Typography.body)
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
        }
    }

    private func heroMetricCard(_ metric: HomeRoundDetailMetric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.title.uppercased())
                .font(ShellTokens.Typography.microEyebrow)
                .tracking(1.0)
                .foregroundStyle(palette.tertiaryText)

            Text(metric.value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()

            if let note = metric.note {
                Text(note)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(ShellTokens.Spacing.x16)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.quietFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
    }

    private func detailFactCard(_ metric: HomeRoundDetailMetric) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
            Text(metric.title.uppercased())
                .font(ShellTokens.Typography.microEyebrow)
                .tracking(1.0)
                .foregroundStyle(palette.tertiaryText)

            Text(metric.value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ShellTokens.Spacing.x16)
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.quietFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
    }

    private func detailAnalysisCard(title: String, items: [String], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(palette.primaryText)

            if items.isEmpty {
                Text("No structured notes yet for this section.")
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(palette.secondaryText)
            }

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: ShellTokens.Spacing.x10) {
                    Circle()
                        .fill(accent)
                        .frame(width: 7, height: 7)
                        .padding(.top, 7)

                    Text(item)
                        .font(ShellTokens.Typography.body)
                        .foregroundStyle(palette.secondaryText)
                }
            }
        }
        .padding(ShellTokens.Spacing.x16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.quietFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
    }

    private func detailMetaPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(palette.quietFill, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(palette.border, lineWidth: 1)
            }
    }

    private func loadAnalysis() async {
        if let cached = analysisService.cachedAnalysis(for: summary) {
            await MainActor.run {
                analysisState = .ready(cached)
            }
            return
        }

        await MainActor.run {
            analysisState = .loading
        }

        let resolved = await resolveAnalysis()
        await MainActor.run {
            analysisState = .ready(resolved)
        }
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
            generatedAt: Date()
        )
    }
}

private struct HomeAnalysisLoadingGlyph: View {
    let accent: Color
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.25), lineWidth: 1.5)
                .frame(width: 18, height: 18)

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(accent)
                    .frame(width: 4, height: 4)
                    .offset(y: -9)
                    .rotationEffect(.degrees(Double(index) * 120))
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .easeInOut(duration: 1.1)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.08),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}
