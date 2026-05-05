import SwiftUI

enum ShellTokens {
    enum Layout {
        static let narrativeWidth: CGFloat = 460
        static let compactGridColumns = [
            GridItem(.flexible(), spacing: Spacing.x12),
            GridItem(.flexible(), spacing: Spacing.x12)
        ]
    }

    enum ColorRole {
        static let bgApp = Color(red: 0.969, green: 0.980, blue: 0.976)          // mist.050
        static let bgGrouped = Color(red: 0.933, green: 0.949, blue: 0.941)
        static let bgHeroTop = Color(red: 0.862, green: 0.928, blue: 0.876)
        static let bgHeroBottom = Color(red: 0.953, green: 0.945, blue: 0.901)
        static let surfacePrimary = Color.white
        static let surfaceSecondary = Color(red: 0.953, green: 0.922, blue: 0.867) // sand.100
        static let surfaceHUD = Color.white.opacity(0.90)
        static let surfacePremium = Color(red: 1.0, green: 0.969, blue: 0.890)
        static let surfaceTinted = Color(red: 0.942, green: 0.970, blue: 0.952)
        static let surfaceOverlay = Color.white.opacity(0.72)

        static let textPrimary = Color(red: 0.063, green: 0.137, blue: 0.102)
        static let textSecondary = Color(red: 0.251, green: 0.341, blue: 0.294)
        static let textTertiary = Color(red: 0.416, green: 0.490, blue: 0.455)
        static let textInverse = Color(red: 0.973, green: 0.984, blue: 0.980)

        static let pine700 = Color(red: 0.122, green: 0.302, blue: 0.227)
        static let pine500 = Color(red: 0.184, green: 0.427, blue: 0.322)
        static let pine300 = Color(red: 0.620, green: 0.765, blue: 0.668)
        static let sun400 = Color(red: 0.812, green: 0.686, blue: 0.322)
        static let instrumentTop = Color(red: 0.072, green: 0.102, blue: 0.135)
        static let instrumentBottom = Color(red: 0.048, green: 0.071, blue: 0.092)
        static let instrumentRaised = Color.white.opacity(0.10)
        static let instrumentStroke = Color.white.opacity(0.12)
        static let instrumentStrokeSoft = Color.white.opacity(0.07)
        static let instrumentSky = Color(red: 0.337, green: 0.624, blue: 0.949)

        static let strokeDefault = Color(red: 0.847, green: 0.878, blue: 0.863)
        static let strokePremium = Color(red: 0.835, green: 0.745, blue: 0.482)
    }

    enum Spacing {
        static let x4: CGFloat = 4
        static let x6: CGFloat = 6
        static let x8: CGFloat = 8
        static let x10: CGFloat = 10
        static let x12: CGFloat = 12
        static let x14: CGFloat = 14
        static let x16: CGFloat = 16
        static let x18: CGFloat = 18
        static let x20: CGFloat = 20
        static let x24: CGFloat = 24
        static let x32: CGFloat = 32
        static let x40: CGFloat = 40
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    enum Typography {
        static let mastheadTitle = Font.system(size: 44, weight: .semibold, design: .serif)
        static let stageTitle = Font.system(size: 30, weight: .semibold, design: .serif)
        static let cardTitle = Font.system(size: 26, weight: .semibold, design: .serif)
        static let sectionTitle = Font.system(size: 28, weight: .semibold, design: .serif)
        static let lead = Font.title3.weight(.medium)
        static let body = Font.subheadline
        static let eyebrow = Font.caption.weight(.semibold)
        static let microEyebrow = Font.caption2.weight(.semibold)
    }

    enum Shadow {
        static let soft = Color.black.opacity(0.06)
        static let floating = Color.black.opacity(0.12)
    }

    enum PillLayout {
        struct CompactPresentation: Equatable {
            let visibleTexts: [String]
            let overflowCount: Int
            let showsCollapseControl: Bool
        }

        static func compactPresentation(
            from texts: [String],
            isExpanded: Bool,
            visibleLimit: Int = 3
        ) -> CompactPresentation {
            let overflowCount = overflowCount(for: texts, visibleLimit: visibleLimit)

            return CompactPresentation(
                visibleTexts: compactVisibleTexts(from: texts, isExpanded: isExpanded, visibleLimit: visibleLimit),
                overflowCount: overflowCount,
                showsCollapseControl: isExpanded && overflowCount > 0
            )
        }

        static func compactDisplayTexts(
            from texts: [String],
            visibleLimit: Int = 3
        ) -> [String] {
            compactVisibleTexts(from: texts, isExpanded: false, visibleLimit: visibleLimit)
        }

        static func compactVisibleTexts(
            from texts: [String],
            isExpanded: Bool,
            visibleLimit: Int = 3
        ) -> [String] {
            guard !isExpanded else { return texts }
            return Array(texts.prefix(visibleLimit))
        }

        static func overflowCount(
            for texts: [String],
            visibleLimit: Int = 3
        ) -> Int {
            max(0, texts.count - visibleLimit)
        }
    }
}

struct ShellCompactPillFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
