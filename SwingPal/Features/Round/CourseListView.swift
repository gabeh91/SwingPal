import SwiftUI

struct CourseDiscoveryViewModel {
    let heroEyebrow: String
    let heroTitle: String
    let heroSubtitle: String
    let featuredCourse: SwingPalCourse?
    let featuredDistanceLabel: String
    let featuredDeck: String
    let stageAssetName: String
    let collectionEyebrow: String
    let collectionTitle: String
    let featuredHighlights: [String]
    let stagePresentation: EditorialStagePresentation

    init(courses: [SwingPalCourse], distanceUnit: DistanceUnit) {
        heroEyebrow = "Near Brighton, VIC"
        heroTitle = "Pick your opening tee shot"
        heroSubtitle = "Choose the course that feels right today, lock the tee context, and move into the round without losing momentum."
        featuredCourse = courses.first
        featuredDistanceLabel = Self.makeFeaturedDistanceLabel(for: courses.first, distanceUnit: distanceUnit)
        featuredDeck = "Closest first, then move straight into tee and player setup."
        stageAssetName = "RoundDiscoveryStage"
        collectionEyebrow = "Ranked nearby"
        collectionTitle = "Nearby Courses"
        stagePresentation = .stackedShowcase
        if let featuredCourse = courses.first {
            featuredHighlights = [
                "\(featuredCourse.holeCount) holes",
                "Par \(featuredCourse.par)",
                featuredCourse.quality.readinessLabel
            ]
        } else {
            featuredHighlights = ["No course loaded", "Try again", "Location needed"]
        }
    }

    init(courses: [SwingPalCourse]) {
        self.init(courses: courses, distanceUnit: .meters)
    }

    private static func makeFeaturedDistanceLabel(for course: SwingPalCourse?, distanceUnit: DistanceUnit) -> String {
        guard let course else {
            return "No course loaded"
        }

        return "\(distanceUnit.travelLabel(forKilometers: course.distanceKilometers)) away"
    }
}

struct CourseListView: View {
    let courses: [SwingPalCourse]
    let distanceUnit: DistanceUnit
    let onSelect: (SwingPalCourse) -> Void

    private var model: CourseDiscoveryViewModel {
        CourseDiscoveryViewModel(courses: courses, distanceUnit: distanceUnit)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x24) {
                discoveryStage

                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                    Text(model.collectionEyebrow.uppercased())
                        .font(ShellTokens.Typography.eyebrow)
                        .tracking(1.2)
                        .foregroundStyle(ShellTokens.ColorRole.textTertiary)
                    Text(model.collectionTitle)
                        .font(ShellTokens.Typography.sectionTitle)
                        .foregroundStyle(ShellTokens.ColorRole.textPrimary)

                    ForEach(Array(courses.enumerated()), id: \.element.id) { index, course in
                        courseRow(course, isNearest: index == 0)
                    }
                }
            }
            .padding(ShellTokens.Spacing.x20)
            .padding(.bottom, AppChromeMetrics.roundScreenBottomPadding)
        }
        .background(ShellTokens.ColorRole.bgApp)
    }

    private var discoveryStage: some View {
        VStack(spacing: 0) {
            scenicCover
                .frame(height: 268)
            stageBriefing
        }
        .clipShape(RoundedRectangle(cornerRadius: ShellTokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.lg, style: .continuous)
                .stroke(ShellTokens.ColorRole.strokeDefault, lineWidth: 1)
        )
        .shadow(color: ShellTokens.Shadow.soft.opacity(0.85), radius: 14, y: 10)
    }

    private var scenicCover: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.800, green: 0.903, blue: 0.642),
                        Color(red: 0.421, green: 0.673, blue: 0.330),
                        Color(red: 0.151, green: 0.314, blue: 0.185)
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
                    .fill(Color(red: 0.700, green: 0.861, blue: 0.535).opacity(0.95))
                    .frame(width: proxy.size.width * 1.16, height: proxy.size.height * 0.22)
                    .rotationEffect(.degrees(-10))
                    .offset(x: proxy.size.width * 0.08, y: proxy.size.height * 0.14)

                Capsule()
                    .fill(Color(red: 0.886, green: 0.808, blue: 0.626).opacity(0.82))
                    .frame(width: proxy.size.width * 0.26, height: proxy.size.height * 0.06)
                    .rotationEffect(.degrees(-13))
                    .offset(x: proxy.size.width * 0.18, y: proxy.size.height * 0.06)

                Capsule()
                    .fill(Color(red: 0.231, green: 0.457, blue: 0.247).opacity(0.36))
                    .frame(width: proxy.size.width * 1.08, height: proxy.size.height * 0.16)
                    .rotationEffect(.degrees(7))
                    .offset(x: -proxy.size.width * 0.07, y: proxy.size.height * 0.30)

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
                        .foregroundStyle(.white.opacity(0.86))

                    if let featuredCourse = model.featuredCourse {
                        Text(featuredCourse.name)
                            .font(ShellTokens.Typography.stageTitle)
                            .foregroundStyle(.white)
                            .lineLimit(3)

                        Text(model.featuredDistanceLabel)
                            .font(ShellTokens.Typography.lead)
                            .foregroundStyle(.white.opacity(0.88))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(ShellTokens.Spacing.x20)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var stageBriefing: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
            Text(model.collectionEyebrow.uppercased())
                .font(ShellTokens.Typography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(ShellTokens.ColorRole.textTertiary)

            if let featuredCourse = model.featuredCourse {
                Text(model.heroTitle)
                    .font(ShellTokens.Typography.sectionTitle)
                    .foregroundStyle(ShellTokens.ColorRole.textPrimary)

                Text(model.heroSubtitle)
                    .font(ShellTokens.Typography.lead)
                    .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                    .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)

                Text(model.featuredDeck)
                    .font(ShellTokens.Typography.body)
                    .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                    .frame(maxWidth: ShellTokens.Layout.narrativeWidth, alignment: .leading)

                ViewThatFits(in: .vertical) {
                    HStack(spacing: ShellTokens.Spacing.x8) {
                        ForEach(model.featuredHighlights, id: \.self) { highlight in
                            statPill(highlight)
                        }
                    }

                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                        ForEach(model.featuredHighlights, id: \.self) { highlight in
                            statPill(highlight)
                        }
                    }
                }

                Button {
                    onSelect(featuredCourse)
                } label: {
                    HStack {
                        Text("Open course detail")
                            .font(.headline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .foregroundStyle(ShellTokens.ColorRole.pine700)
                    .padding(.top, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ShellTokens.Spacing.x24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.88))
    }

    private func courseRow(_ course: SwingPalCourse, isNearest: Bool) -> some View {
        Button {
            onSelect(course)
        } label: {
            HStack(alignment: .top, spacing: ShellTokens.Spacing.x12) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.337, green: 0.467, blue: 0.238),
                            Color(red: 0.741, green: 0.812, blue: 0.525)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text(isNearest ? "01" : String(format: "%02d", rowRank(for: course)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                }
                .frame(width: 84, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: ShellTokens.Radius.md, style: .continuous))

                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x4) {
                    HStack(spacing: 8) {
                        Text(course.name)
                            .font(.headline)
                            .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                        if isNearest {
                            Text("Nearest")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(ShellTokens.ColorRole.pine700)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ShellTokens.ColorRole.pine700.opacity(0.10), in: Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        Text("\(distanceUnit.travelLabel(forKilometers: course.distanceKilometers)) away")
                            .font(.subheadline)
                            .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                        Text("\(course.holeCount) holes")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ShellTokens.ColorRole.textTertiary)
                    }

                    Text(course.quality.readinessLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ShellTokens.ColorRole.pine700)
                        .padding(.top, 4)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(ShellTokens.ColorRole.textTertiary)
                    .padding(.top, 10)
            }
            .padding(.vertical, ShellTokens.Spacing.x12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(ShellTokens.ColorRole.strokeDefault)
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
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

    private func rowRank(for course: SwingPalCourse) -> Int {
        (courses.firstIndex(where: { $0.id == course.id }) ?? 0) + 1
    }
}
