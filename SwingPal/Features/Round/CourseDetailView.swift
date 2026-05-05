import SwiftUI

struct CourseDetailViewModel {
    let heroEyebrow: String
    let heroTitle: String
    let heroDistanceLabel: String
    let heroSubtitle: String
    let stageAssetName: String
    let briefingEyebrow: String
    let selectionDeck: String
    let teeBadgeText: String
    let expectationHighlights: [String]
    let dataDisclosureTitle: String
    let reportActionTitle: String
    let expectations: [String]
    let stagePresentation: EditorialStagePresentation

    init(course: SwingPalCourse, selectedTee: SwingPalCourse.Tee?, distanceUnit: DistanceUnit) {
        heroEyebrow = "Course Lock"
        heroTitle = course.name
        heroDistanceLabel = "\(distanceUnit.travelLabel(forKilometers: course.distanceKilometers)) away"
        heroSubtitle = "Lock the tee context, take one clean read on the course, and move into players with confidence."
        stageAssetName = "CourseDetailStage"
        briefingEyebrow = "Course briefing"
        selectionDeck = "Pick the tee that matches today’s round and move straight into players."
        stagePresentation = .stackedShowcase
        if let selectedTee {
            switch distanceUnit {
            case .meters:
                let meters = Int((Double(selectedTee.yards) * 0.9144).rounded())
                teeBadgeText = "\(selectedTee.name) • \(meters)m"
            case .yards:
                teeBadgeText = "\(selectedTee.name) • \(selectedTee.yards)yd"
            }
        } else {
            teeBadgeText = "Select a tee"
        }
        expectationHighlights = [
            "Par \(course.par)",
            "\(course.holeCount) holes",
            course.quality.readinessLabel
        ]
        dataDisclosureTitle = "Course data and community"
        reportActionTitle = "Report course data"
        expectations = [
            "Yardages ready for live-round targeting",
            "Bag-based club recommendation available mid-hole",
            "Guest players and attestation in the next step"
        ]
    }

    init(course: SwingPalCourse, selectedTee: SwingPalCourse.Tee?) {
        self.init(course: course, selectedTee: selectedTee, distanceUnit: .meters)
    }
}

struct CourseDetailView: View {
    @ObservedObject var setupState: RoundSetupState
    @ObservedObject var correctionCenter: CourseCorrectionCenter
    let course: SwingPalCourse
    let distanceUnit: DistanceUnit
    let onContinue: () -> Void
    @State private var isShowingCorrectionSheet = false

    private var moderationSummary: CourseCorrectionModerationSummary {
        correctionCenter.moderationSummary(for: course.id)
    }

    private var recentCorrectionActivity: [CourseCorrectionActivityItem] {
        correctionCenter.recentActivity(for: course.id)
    }

    private var selectedTee: SwingPalCourse.Tee? {
        course.tees.first(where: { $0.name == setupState.selectedTeeName })
    }

    private var model: CourseDetailViewModel {
        CourseDetailViewModel(course: course, selectedTee: selectedTee, distanceUnit: distanceUnit)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x24) {
                detailStage

                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                    Text("Tee Selection")
                        .font(ShellTokens.Typography.cardTitle)
                        .foregroundStyle(ShellTokens.ColorRole.textPrimary)

                    ForEach(course.tees) { tee in
                        teeCard(tee)
                    }
                }

                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                    Text("What to Expect")
                        .font(ShellTokens.Typography.cardTitle)
                        .foregroundStyle(ShellTokens.ColorRole.textPrimary)

                    ForEach(model.expectations, id: \.self) { item in
                        expectationRow(item)
                    }
                }
                .padding(ShellTokens.Spacing.x16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                )

                dataDisclosureCard

                Button(action: onContinue) {
                    HStack {
                        Text("Continue to Players")
                            .font(.headline)
                        Spacer()
                        Text(selectedTeeLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ShellTokens.ColorRole.textInverse.opacity(0.82))
                    }
                    .padding(.horizontal, ShellTokens.Spacing.x16)
                    .padding(.vertical, ShellTokens.Spacing.x16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ShellTokens.ColorRole.textInverse)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            ShellTokens.ColorRole.pine700,
                            ShellTokens.ColorRole.pine500
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                )
                .shadow(color: ShellTokens.Shadow.floating, radius: 12, y: 6)
            }
            .padding(ShellTokens.Spacing.x20)
            .padding(.bottom, AppChromeMetrics.roundScreenBottomPadding)
        }
        .background(ShellTokens.ColorRole.bgApp)
        .onAppear {
            setupState.selectCourse(course)
            if setupState.selectedTeeName == nil, let firstTee = course.tees.first {
                setupState.selectTee(firstTee)
            }
        }
        .sheet(isPresented: $isShowingCorrectionSheet) {
            CourseCorrectionSheet(
                course: course,
                existingSubmissionCount: correctionCenter.corrections(for: course.id).count
            ) { draft in
                correctionCenter.submit(draft)
            }
        }
    }

    private var detailStage: some View {
        VStack(spacing: 0) {
            scenicCover
                .frame(height: 268)
            detailBriefing
        }
        .clipShape(RoundedRectangle(cornerRadius: ShellTokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.lg, style: .continuous)
                .stroke(ShellTokens.ColorRole.strokeDefault, lineWidth: 1)
        )
        .shadow(color: ShellTokens.Shadow.soft.opacity(0.85), radius: 14, y: 10)
    }

    private var detailBriefing: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
            Text(model.briefingEyebrow.uppercased())
                .font(ShellTokens.Typography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(ShellTokens.ColorRole.textTertiary)

            Text(model.heroTitle)
                .font(ShellTokens.Typography.sectionTitle)
                .foregroundStyle(ShellTokens.ColorRole.textPrimary)

            Text(model.heroSubtitle)
                .font(ShellTokens.Typography.lead)
                .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)

            Text(model.selectionDeck)
                .font(ShellTokens.Typography.body)
                .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)

            ViewThatFits(in: .vertical) {
                HStack(spacing: ShellTokens.Spacing.x8) {
                    ForEach(model.expectationHighlights, id: \.self) { item in
                        statPill(item)
                    }
                }

                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                    ForEach(model.expectationHighlights, id: \.self) { item in
                        statPill(item)
                    }
                }
            }

            HStack {
                Text(model.heroDistanceLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                Spacer()
                Text(model.teeBadgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ShellTokens.ColorRole.textPrimary)
            }
        }
        .padding(ShellTokens.Spacing.x24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.88))
    }

    private var scenicCover: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.808, green: 0.905, blue: 0.650),
                        Color(red: 0.470, green: 0.702, blue: 0.350),
                        Color(red: 0.157, green: 0.318, blue: 0.192)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.white.opacity(0.24))
                    .frame(width: 170, height: 170)
                    .blur(radius: 18)
                    .offset(x: proxy.size.width * 0.30, y: -proxy.size.height * 0.22)

                Capsule()
                    .fill(Color(red: 0.703, green: 0.865, blue: 0.540).opacity(0.95))
                    .frame(width: proxy.size.width * 1.18, height: proxy.size.height * 0.22)
                    .rotationEffect(.degrees(-11))
                    .offset(x: proxy.size.width * 0.08, y: proxy.size.height * 0.14)

                Capsule()
                    .fill(Color(red: 0.885, green: 0.812, blue: 0.628).opacity(0.82))
                    .frame(width: proxy.size.width * 0.25, height: proxy.size.height * 0.06)
                    .rotationEffect(.degrees(-14))
                    .offset(x: proxy.size.width * 0.19, y: proxy.size.height * 0.07)

                Capsule()
                    .fill(Color(red: 0.219, green: 0.451, blue: 0.241).opacity(0.36))
                    .frame(width: proxy.size.width * 1.08, height: proxy.size.height * 0.16)
                    .rotationEffect(.degrees(8))
                    .offset(x: -proxy.size.width * 0.06, y: proxy.size.height * 0.30)

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.32)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                    Text(model.heroEyebrow.uppercased())
                        .font(ShellTokens.Typography.eyebrow)
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.84))

                    Text(model.heroTitle)
                        .font(ShellTokens.Typography.stageTitle)
                        .foregroundStyle(.white)
                        .lineLimit(3)

                    Text(model.heroDistanceLabel)
                        .font(ShellTokens.Typography.lead)
                        .foregroundStyle(.white.opacity(0.88))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(ShellTokens.Spacing.x20)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dataDisclosureCard: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x4) {
                    Text(model.dataDisclosureTitle)
                        .font(.headline)
                        .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                    Text("Course details can improve over time. If something looks off, you can submit a correction.")
                        .font(.subheadline)
                        .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                }
                Spacer()
                Text(course.community.access.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ShellTokens.ColorRole.pine700)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ShellTokens.ColorRole.surfaceTinted, in: Capsule())
            }

            HStack(spacing: ShellTokens.Spacing.x12) {
                readinessMetric(title: "Readiness", value: course.quality.readinessLabel)
                readinessMetric(title: "Community", value: course.community.summaryLabel)
            }

            HStack(spacing: ShellTokens.Spacing.x8) {
                ForEach(course.sourceReferences) { source in
                    miniBadge(source.kind.label)
                }
            }

            if !recentCorrectionActivity.isEmpty {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                    Text("Recent activity")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ShellTokens.ColorRole.textTertiary)

                    ForEach(recentCorrectionActivity) { item in
                        correctionActivityRow(item)
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x4) {
                    Text("Local reports")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ShellTokens.ColorRole.textTertiary)
                    Text(localCorrectionSummary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                }
                Spacer()

                Button {
                    isShowingCorrectionSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                        Text(model.reportActionTitle)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(ShellTokens.ColorRole.pine700)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(ShellTokens.ColorRole.surfaceTinted, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ShellTokens.Spacing.x16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShellTokens.ColorRole.surfacePrimary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                .stroke(ShellTokens.ColorRole.strokeDefault, lineWidth: 1)
        )
    }

    private func teeCard(_ tee: SwingPalCourse.Tee) -> some View {
        let isSelected = setupState.selectedTeeName == tee.name

        return Button {
            setupState.selectTee(tee)
        } label: {
            HStack(spacing: ShellTokens.Spacing.x12) {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x4) {
                    Text(tee.name)
                        .font(.headline)
                        .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                    Text("\(tee.yards) yds")
                        .font(.subheadline)
                        .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? ShellTokens.ColorRole.pine700 : ShellTokens.ColorRole.textTertiary)
                    .font(.title3)
            }
            .padding(ShellTokens.Spacing.x16)
            .background(
                isSelected ? ShellTokens.ColorRole.surfaceSecondary : ShellTokens.ColorRole.surfacePrimary,
                in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                    .stroke(
                        isSelected ? ShellTokens.ColorRole.pine500 : ShellTokens.ColorRole.strokeDefault,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func expectationRow(_ text: String) -> some View {
        HStack(spacing: ShellTokens.Spacing.x8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ShellTokens.ColorRole.pine500)
            Text(text)
                .foregroundStyle(ShellTokens.ColorRole.textSecondary)
        }
    }

    private func statPill(_ text: String, inverse: Bool = false) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(inverse ? ShellTokens.ColorRole.textInverse : ShellTokens.ColorRole.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                inverse ? Color.white.opacity(0.14) : ShellTokens.ColorRole.surfaceHUD,
                in: Capsule()
            )
    }

    private func miniBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(ShellTokens.ColorRole.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ShellTokens.ColorRole.surfaceHUD, in: Capsule())
    }

    private func readinessMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(ShellTokens.ColorRole.textTertiary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ShellTokens.Spacing.x12)
        .background(ShellTokens.ColorRole.surfaceSecondary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.sm))
    }

    private func correctionActivityRow(_ item: CourseCorrectionActivityItem) -> some View {
        HStack(alignment: .top, spacing: ShellTokens.Spacing.x12) {
            Circle()
                .fill(ShellTokens.ColorRole.pine500)
                .frame(width: 8, height: 8)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x4) {
                HStack(alignment: .firstTextBaseline, spacing: ShellTokens.Spacing.x8) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Text(item.statusLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ShellTokens.ColorRole.pine700)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ShellTokens.ColorRole.surfaceTinted, in: Capsule())
                }

                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(ShellTokens.Spacing.x12)
        .background(ShellTokens.ColorRole.surfaceSecondary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.sm))
    }

    private var selectedTeeLabel: String {
        setupState.selectedTeeName ?? "Select tee"
    }

    private var localCorrectionSummary: String {
        let count = moderationSummary.totalCount
        switch count {
        case 0:
            return "No local reports yet"
        case 1:
            return "1 local report captured"
        default:
            return "\(count) local reports captured"
        }
    }
}
