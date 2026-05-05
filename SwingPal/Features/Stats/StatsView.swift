import SwiftUI

private struct StatsPalette {
    let backgroundBase: Color
    let backgroundGlow: Color
    let cardTint: Color
    let heroTint: Color
    let border: Color
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    let accent: Color
    let quietFill: Color
    let quietStrongFill: Color
    let positiveFill: Color
    let cautionFill: Color
    let positiveAccent: Color
    let cautionAccent: Color
    let shadow: Color

    static func forColorScheme(_ colorScheme: ColorScheme) -> StatsPalette {
        switch colorScheme {
        case .dark:
            return .init(
                backgroundBase: Color(red: 0.05, green: 0.08, blue: 0.09),
                backgroundGlow: Color(red: 0.12, green: 0.27, blue: 0.22).opacity(0.56),
                cardTint: Color.white.opacity(0.08),
                heroTint: Color(red: 0.16, green: 0.20, blue: 0.24).opacity(0.76),
                border: Color.white.opacity(0.20),
                primaryText: Color.white.opacity(0.96),
                secondaryText: Color.white.opacity(0.82),
                tertiaryText: Color.white.opacity(0.62),
                accent: ShellTokens.ColorRole.pine500,
                quietFill: Color.white.opacity(0.07),
                quietStrongFill: Color.white.opacity(0.12),
                positiveFill: Color(red: 0.12, green: 0.28, blue: 0.20).opacity(0.72),
                cautionFill: Color(red: 0.31, green: 0.18, blue: 0.13).opacity(0.74),
                positiveAccent: Color(red: 0.56, green: 0.88, blue: 0.70),
                cautionAccent: Color(red: 0.98, green: 0.78, blue: 0.52),
                shadow: Color.black.opacity(0.34)
            )
        default:
            return .init(
                backgroundBase: Color(red: 0.95, green: 0.96, blue: 0.94),
                backgroundGlow: Color(red: 0.84, green: 0.90, blue: 0.86).opacity(0.74),
                cardTint: Color.white.opacity(0.48),
                heroTint: Color(red: 0.90, green: 0.93, blue: 0.95).opacity(0.88),
                border: Color.white.opacity(0.42),
                primaryText: ShellTokens.ColorRole.textPrimary,
                secondaryText: ShellTokens.ColorRole.textSecondary,
                tertiaryText: ShellTokens.ColorRole.textTertiary,
                accent: ShellTokens.ColorRole.pine700,
                quietFill: Color.white.opacity(0.44),
                quietStrongFill: Color.white.opacity(0.72),
                positiveFill: Color(red: 0.87, green: 0.94, blue: 0.89).opacity(0.96),
                cautionFill: Color(red: 0.97, green: 0.90, blue: 0.82).opacity(0.96),
                positiveAccent: ShellTokens.ColorRole.pine700,
                cautionAccent: Color(red: 0.61, green: 0.37, blue: 0.10),
                shadow: Color.black.opacity(0.10)
            )
        }
    }
}

struct StatsView: View {
    let model: StatsViewModel

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var palette: StatsPalette {
        StatsPalette.forColorScheme(colorScheme)
    }

    private var usesCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private let sectionColumns = [
        GridItem(.flexible(), spacing: ShellTokens.Spacing.x12)
    ]
    private let factColumns = [
        GridItem(.flexible(), spacing: ShellTokens.Spacing.x10),
        GridItem(.flexible(), spacing: ShellTokens.Spacing.x10),
        GridItem(.flexible(), spacing: ShellTokens.Spacing.x10)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x20) {
                    masthead
                    overviewRail
                    heroCard
                    trendCard
                    skillSections
                    recentRoundsSection
                }
                .padding(.horizontal, ShellTokens.Spacing.x20)
                .padding(.top, ShellTokens.Spacing.x20)
                .padding(.bottom, ShellTokens.Spacing.x32 + AppChromeMetrics.bottomContentInset)
            }
            .background(background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var background: some View {
        ZStack {
            palette.backgroundBase

            LinearGradient(
                colors: [
                    palette.backgroundGlow,
                    palette.backgroundBase,
                    palette.backgroundBase
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette.accent.opacity(colorScheme == .dark ? 0.12 : 0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 42)
                .offset(x: 160, y: -160)
        }
        .ignoresSafeArea()
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            Text("STATS")
                .font(ShellTokens.Typography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(palette.accent)

            Text("Round insights, then the numbers.")
                .font(ShellTokens.Typography.mastheadTitle)
                .foregroundStyle(palette.primaryText)

            Text("Start with the latest takeaways, then drill into stats by skill area.")
                .font(ShellTokens.Typography.lead)
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
        }
    }

    private var heroCard: some View {
        card(tint: palette.heroTint, padding: 24) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                Text(model.heroTitle.uppercased())
                    .font(ShellTokens.Typography.microEyebrow)
                    .tracking(1.2)
                    .foregroundStyle(palette.tertiaryText)

                Text(model.heroCourseName)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Text(model.heroSummary)
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)

                LazyVGrid(columns: factColumns, spacing: ShellTokens.Spacing.x10) {
                    ForEach(model.heroSnapshotFacts, id: \.title) { fact in
                        snapshotTile(fact)
                    }
                }

                if !model.heroStrengths.isEmpty || !model.heroImprovements.isEmpty {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                        if !model.heroStrengths.isEmpty {
                            analysisList(title: "What Went Well", items: model.heroStrengths)
                        }
                        if !model.heroImprovements.isEmpty {
                            analysisList(title: "Needs Work", items: model.heroImprovements)
                        }
                    }
                }
            }
        }
    }

    private var overviewRail: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            Text("OVERVIEW")
                .font(ShellTokens.Typography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(palette.tertiaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ShellTokens.Spacing.x10) {
                    ForEach(model.overviewHighlights, id: \.title) { highlight in
                        overviewTile(highlight)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var trendCard: some View {
        card(tint: palette.cardTint, padding: 20) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
                HStack(alignment: .top, spacing: ShellTokens.Spacing.x12) {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
                        Text("TREND SIGNAL")
                            .font(ShellTokens.Typography.microEyebrow)
                            .tracking(1.2)
                            .foregroundStyle(palette.tertiaryText)

                        Text(model.trendSignalTitle)
                            .font(ShellTokens.Typography.cardTitle)
                            .foregroundStyle(palette.primaryText)

                        Text(model.trendSignalDetail)
                            .font(ShellTokens.Typography.body)
                            .foregroundStyle(palette.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 10) {
                        Image(systemName: trendSymbolName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(trendAccentColor)
                            .frame(width: 40, height: 40)
                            .background(trendFillColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Text(model.trendSignalValue)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(trendAccentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(trendFillColor, in: Capsule())
                    }
                }
            }
        }
    }

    private var skillSections: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            Text("SKILL AREAS")
                .font(ShellTokens.Typography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(palette.tertiaryText)

            LazyVGrid(columns: sectionColumns, spacing: ShellTokens.Spacing.x12) {
                ForEach(model.sections, id: \.title) { section in
                    skillCard(section)
                }
            }
        }
    }

    private var recentRoundsSection: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            Text(model.recentRoundsTitle.uppercased())
                .font(ShellTokens.Typography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(palette.tertiaryText)

            ForEach(model.recentRoundCards) { cardModel in
                card(tint: palette.cardTint, padding: 18) {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
                        HStack(alignment: .top, spacing: ShellTokens.Spacing.x12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(cardModel.courseName)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(palette.primaryText)

                                Text(cardModel.statusTitle)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(cardModel.statusTitle == "Finished Round" ? palette.positiveAccent : palette.cautionAccent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        cardModel.statusTitle == "Finished Round" ? palette.positiveFill : palette.cautionFill,
                                        in: Capsule()
                                    )
                            }

                            Spacer()

                            Text(cardModel.updatedAt.formatted(.relative(presentation: .named)))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(palette.secondaryText)
                        }

                        HStack(alignment: .center, spacing: ShellTokens.Spacing.x14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cardModel.scoreValue)
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(palette.primaryText)
                                Text(cardModel.scoreCaption.uppercased())
                                    .font(ShellTokens.Typography.microEyebrow)
                                    .tracking(1.1)
                                    .foregroundStyle(palette.tertiaryText)
                            }
                            .frame(width: 92, alignment: .leading)
                            .padding(.horizontal, ShellTokens.Spacing.x12)
                            .padding(.vertical, ShellTokens.Spacing.x14)
                            .background(palette.quietStrongFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
                                HStack {
                                    Text("Round Progress")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(palette.secondaryText)

                                    Spacer()

                                    Text(cardModel.progressLabel)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(palette.primaryText)
                                }

                                GeometryReader { proxy in
                                    let width = max(proxy.size.width * cardModel.progressValue, 14)

                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(palette.quietFill)

                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [palette.accent.opacity(0.78), palette.accent],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: width)
                                    }
                                }
                                .frame(height: 10)

                                if usesCompactLayout {
                                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                                        ForEach(cardModel.metadataPills, id: \.self) { pill in
                                            recentRoundPill(pill)
                                        }
                                    }
                                } else {
                                    HStack(spacing: ShellTokens.Spacing.x8) {
                                        ForEach(cardModel.metadataPills, id: \.self) { pill in
                                            recentRoundPill(pill)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func analysisList(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
            Text(title.uppercased())
                .font(ShellTokens.Typography.microEyebrow)
                .tracking(1.1)
                .foregroundStyle(palette.tertiaryText)

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(item)
                        .font(ShellTokens.Typography.body)
                        .foregroundStyle(palette.secondaryText)
                }
            }
        }
    }

    private func skillCard(_ section: StatsSkillSection) -> some View {
        card(tint: palette.cardTint, padding: 20) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                HStack(alignment: .center, spacing: ShellTokens.Spacing.x12) {
                    Text(section.title)
                        .font(ShellTokens.Typography.sectionTitle)
                        .foregroundStyle(palette.primaryText)

                    Spacer()

                    Image(systemName: iconName(for: section.title))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 34, height: 34)
                        .background(palette.quietFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text(section.summary)
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(palette.secondaryText)

                LazyVGrid(columns: factColumns, spacing: ShellTokens.Spacing.x10) {
                    ForEach(Array(section.facts.enumerated()), id: \.element.title) { index, fact in
                        factTile(fact, isPrimary: index == 0)
                    }
                }
            }
        }
    }

    private func snapshotTile(_ fact: StatsFact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(fact.title.uppercased())
                .font(ShellTokens.Typography.microEyebrow)
                .tracking(1.1)
                .foregroundStyle(palette.tertiaryText)

            Text(fact.value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Text(fact.detail)
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ShellTokens.Spacing.x12)
        .padding(.vertical, ShellTokens.Spacing.x12)
        .background(palette.quietFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func overviewTile(_ highlight: StatsOverviewHighlight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: iconName(for: highlight.title))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accent)

                Text(highlight.title.uppercased())
                    .font(ShellTokens.Typography.microEyebrow)
                    .tracking(1.1)
                    .foregroundStyle(palette.tertiaryText)
            }

            Text(highlight.value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Text(highlight.detail)
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(2)
        }
        .frame(width: 148, alignment: .leading)
        .padding(.horizontal, ShellTokens.Spacing.x14)
        .padding(.vertical, ShellTokens.Spacing.x14)
        .background(palette.quietFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.border.opacity(0.7), lineWidth: 1)
        }
    }

    private func factTile(_ fact: StatsFact, isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(fact.title.uppercased())
                .font(ShellTokens.Typography.microEyebrow)
                .tracking(1.1)
                .foregroundStyle(isPrimary ? palette.secondaryText : palette.tertiaryText)

            Text(fact.value)
                .font(.system(size: isPrimary ? 24 : 21, weight: .bold, design: .rounded))
                .foregroundStyle(isPrimary ? palette.accent : palette.primaryText)

            Text(fact.detail)
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(.horizontal, ShellTokens.Spacing.x12)
        .padding(.vertical, ShellTokens.Spacing.x12)
        .background(isPrimary ? palette.quietStrongFill : palette.quietFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isPrimary ? palette.border.opacity(0.85) : palette.border.opacity(0.55), lineWidth: 1)
        }
    }

    private func recentRoundPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(palette.quietFill, in: Capsule())
    }

    private var trendFillColor: Color {
        switch model.trendSignalTone {
        case .positive:
            return palette.positiveFill
        case .caution:
            return palette.cautionFill
        case .neutral:
            return palette.quietFill
        }
    }

    private var trendAccentColor: Color {
        switch model.trendSignalTone {
        case .positive:
            return palette.positiveAccent
        case .caution:
            return palette.cautionAccent
        case .neutral:
            return palette.accent
        }
    }

    private var trendSymbolName: String {
        switch model.trendSignalTone {
        case .positive:
            return "arrow.down.right"
        case .caution:
            return "arrow.up.right"
        case .neutral:
            return "equal"
        }
    }

    private func iconName(for title: String) -> String {
        switch title {
        case "Driving":
            return "figure.golf"
        case "Approach":
            return "scope"
        case "Short Game":
            return "sparkles"
        case "Putting":
            return "circle.lefthalf.filled"
        default:
            return "chart.bar"
        }
    }

    private func card<Content: View>(tint: Color, padding: CGFloat, @ViewBuilder content: () -> Content) -> some View {
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
            shape.stroke(palette.border, lineWidth: 1)
        }
        .shadow(color: palette.shadow, radius: 18, y: 10)
    }
}
