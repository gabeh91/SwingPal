import SwiftUI

struct SocialPalette {
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
    let shadow: Color
    let glassHighlight: Color

    static func forColorScheme(_ colorScheme: ColorScheme) -> SocialPalette {
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
                shadow: Color.black.opacity(0.10),
                glassHighlight: Color.white.opacity(0.24)
            )
        }
    }
}

struct SocialView: View {
    let posts: [SocialPost]

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedPost: SocialPost?
    @State private var isHeroPillListExpanded = false

    private var palette: SocialPalette {
        SocialPalette.forColorScheme(colorScheme)
    }

    private var pulseColumns: [GridItem] {
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

    private func compactHeroPillPresentation(for model: SocialViewModel) -> ShellTokens.PillLayout.CompactPresentation {
        ShellTokens.PillLayout.compactPresentation(from: model.heroHighlights, isExpanded: isHeroPillListExpanded)
    }

    var body: some View {
        let model = SocialViewModel(posts: posts)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x20) {
                    masthead(model: model)
                    heroCard(model: model)
                    circlePulseSection(model: model)

                    if let spotlight = model.spotlightPost {
                        spotlightCard(post: spotlight, model: model)
                    } else {
                        emptyStateCard(model: model)
                    }

                    feedSection(model: model)
                }
                .padding(.horizontal, ShellTokens.Spacing.x20)
                .padding(.top, ShellTokens.Spacing.x20)
                .padding(.bottom, ShellTokens.Spacing.x32 + AppChromeMetrics.bottomContentInset)
            }
            .background(background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedPost) { post in
                switch post.destinationKind {
                case .analysis:
                    HomeRoundAnalysisDetailView(summary: post.roundSummary)
                case .scorecard:
                    SocialScorecardDetailView(post: post, palette: palette)
                }
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

    private func masthead(model: SocialViewModel) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
            HStack(alignment: .center) {
                Text(model.heroEyebrow)
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

            Text("Social")
                .font(ShellTokens.Typography.mastheadTitle)
                .foregroundStyle(palette.primaryText)

            Text("Catch up on friend rounds at a glance.")
                .font(ShellTokens.Typography.lead)
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
        }
    }

    private func heroCard(model: SocialViewModel) -> some View {
        let pillPresentation = compactHeroPillPresentation(for: model)

        return cardContainer(tint: palette.cardStrongTint, padding: 24) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x18) {
                if usesCompactHeroLayout {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CIRCLE STATUS")
                                .font(ShellTokens.Typography.microEyebrow)
                                .tracking(1.2)
                                .foregroundStyle(palette.tertiaryText)

                            Text(model.heroTitle)
                                .font(ShellTokens.Typography.sectionTitle)
                                .foregroundStyle(palette.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text(posts.isEmpty ? "Build circle" : "Live circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(palette.quietFill, in: Capsule())
                    }
                } else {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CIRCLE STATUS")
                                .font(ShellTokens.Typography.microEyebrow)
                                .tracking(1.2)
                                .foregroundStyle(palette.tertiaryText)

                            Text(model.heroTitle)
                                .font(ShellTokens.Typography.sectionTitle)
                                .foregroundStyle(palette.primaryText)
                        }

                        Spacer()

                        Text(posts.isEmpty ? "Build circle" : "Live circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(palette.quietFill, in: Capsule())
                    }
                }

                Text(model.heroSubtitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Text(model.heroDeck)
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)

                if usesCompactHeroLayout {
                    ShellCompactPillFlow(spacing: ShellTokens.Spacing.x8) {
                        ForEach(pillPresentation.visibleTexts, id: \.self) { text in
                            heroPill(text)
                        }
                        if pillPresentation.showsCollapseControl {
                            heroOverflowPill("Less") {
                                isHeroPillListExpanded = false
                            }
                        } else if pillPresentation.overflowCount > 0 {
                            heroOverflowPill("+\(pillPresentation.overflowCount)") {
                                isHeroPillListExpanded = true
                            }
                        }
                    }
                } else {
                    HStack(spacing: ShellTokens.Spacing.x8) {
                        ForEach(model.heroHighlights, id: \.self) { highlight in
                            heroPill(highlight)
                        }
                    }
                }

                if usesCompactHeroLayout {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Spotlight")
                                .font(ShellTokens.Typography.microEyebrow)
                                .tracking(1.0)
                                .foregroundStyle(palette.tertiaryText)

                            Text(posts.first?.scoreSummary ?? "--")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(palette.primaryText)
                                .monospacedDigit()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Feed tone")
                                .font(ShellTokens.Typography.microEyebrow)
                                .tracking(1.0)
                                .foregroundStyle(palette.tertiaryText)

                            Text(posts.isEmpty ? "Quiet" : "Active")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)
                        }
                    }
                } else {
                    HStack(spacing: ShellTokens.Spacing.x12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Spotlight")
                                .font(ShellTokens.Typography.microEyebrow)
                                .tracking(1.0)
                                .foregroundStyle(palette.tertiaryText)

                            Text(posts.first?.scoreSummary ?? "--")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(palette.primaryText)
                                .monospacedDigit()
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Feed tone")
                                .font(ShellTokens.Typography.microEyebrow)
                                .tracking(1.0)
                                .foregroundStyle(palette.tertiaryText)

                            Text(posts.isEmpty ? "Quiet" : "Active")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)
                        }
                    }
                }
            }
        }
    }

    private func circlePulseSection(model: SocialViewModel) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            sectionHeader(
                eyebrow: "CIRCLE PULSE",
                title: "Fast social signals you can scan",
                subtitle: "Who’s played recently, where, and what’s worth opening."
            )

            LazyVGrid(columns: pulseColumns, spacing: ShellTokens.Spacing.x12) {
                ForEach(model.pulseStats, id: \.title) { stat in
                    pulseCard(stat)
                }
            }
        }
    }

    private func spotlightCard(post: SocialPost, model: SocialViewModel) -> some View {
        Button {
            selectedPost = post
        } label: {
            cardContainer(tint: palette.cardTint, padding: 22) {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                    HStack(alignment: .top, spacing: ShellTokens.Spacing.x12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.spotlightEyebrow.uppercased())
                                .font(ShellTokens.Typography.microEyebrow)
                                .foregroundStyle(palette.tertiaryText)

                            HStack(spacing: 6) {
                                Image(systemName: post.symbolName)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(palette.accent)

                                Text(post.kindLabel.uppercased())
                                    .font(ShellTokens.Typography.microEyebrow)
                                    .tracking(1.0)
                                    .foregroundStyle(palette.tertiaryText)
                            }

                            Text(post.title)
                                .font(ShellTokens.Typography.cardTitle)
                                .foregroundStyle(palette.primaryText)
                        }

                        Spacer()

                        Text(post.scoreSummary)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(palette.accentForeground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(palette.accent, in: Capsule())
                    }

                    Text(model.spotlightDeck)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(palette.primaryText)

                    Text(post.highlight)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.accent)

                    Text(post.subtitle)
                        .font(ShellTokens.Typography.body)
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)

                    ViewThatFits(in: .vertical) {
                        HStack(spacing: ShellTokens.Spacing.x8) {
                            ForEach(post.metadataPills, id: \.self) { pill in
                                heroPill(pill)
                            }
                        }

                        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                            ForEach(post.metadataPills, id: \.self) { pill in
                                heroPill(pill)
                            }
                        }
                    }

                    HStack {
                        Text(model.spotlightActionTitle)
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
    }

    private func emptyStateCard(model: SocialViewModel) -> some View {
        cardContainer(tint: palette.cardTint, padding: 22) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
                Text("SOCIAL FEED")
                    .font(ShellTokens.Typography.microEyebrow)
                    .tracking(1.2)
                    .foregroundStyle(palette.tertiaryText)

                Text(model.emptyStateTitle)
                    .font(ShellTokens.Typography.cardTitle)
                    .foregroundStyle(palette.primaryText)

                Text(model.emptyStateSubtitle)
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
            }
        }
    }

    private func feedSection(model: SocialViewModel) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            sectionHeader(
                eyebrow: model.feedEyebrow.uppercased(),
                title: model.feedTitle,
                subtitle: "A clean place to keep up with your golf circle."
            )

            LazyVStack(spacing: ShellTokens.Spacing.x12) {
                ForEach(posts) { post in
                    SocialPostCard(post: post, palette: palette) {
                        selectedPost = post
                    }
                }
            }
        }
    }

    private func cardContainer<Content: View>(
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

    private func pulseCard(_ stat: SocialPulseStat) -> some View {
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
}

private struct SocialScorecardDetailView: View {
    let post: SocialPost
    let palette: SocialPalette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x20) {
                hero
                scoreSnapshot
                notesCard
            }
            .padding(.horizontal, ShellTokens.Spacing.x20)
            .padding(.top, ShellTokens.Spacing.x20)
            .padding(.bottom, ShellTokens.Spacing.x32 + AppChromeMetrics.bottomContentInset)
        }
        .background(background)
        .navigationTitle("Scorecard")
        .navigationBarTitleDisplayMode(.inline)
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
        }
        .ignoresSafeArea()
    }

    private var hero: some View {
        detailCard(tint: palette.cardStrongTint, padding: 24) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(post.kindLabel.uppercased())
                            .font(ShellTokens.Typography.microEyebrow)
                            .tracking(1.2)
                            .foregroundStyle(palette.tertiaryText)

                        Text(post.playerName)
                            .font(ShellTokens.Typography.sectionTitle)
                            .foregroundStyle(palette.primaryText)

                        Text(post.courseName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)
                    }

                    Spacer()

                    Text(post.scoreSummary)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(palette.accentForeground)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(palette.accent, in: Capsule())
                }

                Text(post.highlight)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Text(post.subtitle)
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)
            }
        }
    }

    private var scoreSnapshot: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            Text("Round Snapshot")
                .font(ShellTokens.Typography.sectionTitle)
                .foregroundStyle(palette.primaryText)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: ShellTokens.Spacing.x12),
                    GridItem(.flexible(), spacing: ShellTokens.Spacing.x12)
                ],
                spacing: ShellTokens.Spacing.x12
            ) {
                snapshotCard(title: "Status", value: post.roundSummary.status == .finished ? "Finished Round" : "Saved Round")
                snapshotCard(title: "Progress", value: "Hole \(post.roundSummary.holeNumber) of \(post.roundSummary.totalHoleCount)")
                snapshotCard(title: "Strokes", value: "\(post.roundSummary.totalStrokes)")
                snapshotCard(title: "Putts", value: "\(post.roundSummary.totalPutts)")
                snapshotCard(title: "Penalties", value: "\(post.roundSummary.totalPenalties)")
                snapshotCard(title: "Players", value: "\(post.roundSummary.playerCount)")
            }
        }
    }

    private var notesCard: some View {
        detailCard(tint: palette.cardTint, padding: 22) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
                Text("Clubhouse Notes")
                    .font(ShellTokens.Typography.microEyebrow)
                    .tracking(1.2)
                    .foregroundStyle(palette.tertiaryText)

                ForEach(post.metadataPills, id: \.self) { pill in
                    HStack(alignment: .top, spacing: ShellTokens.Spacing.x10) {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 7, height: 7)
                            .padding(.top, 7)

                        Text(pill)
                            .font(ShellTokens.Typography.body)
                            .foregroundStyle(palette.secondaryText)
                    }
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

    private func snapshotCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(ShellTokens.Typography.microEyebrow)
                .tracking(1.0)
                .foregroundStyle(palette.tertiaryText)

            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(palette.primaryText)
        }
        .padding(ShellTokens.Spacing.x16)
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.quietFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
    }
}
