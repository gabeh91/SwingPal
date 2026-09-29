import SwiftUI

enum ShellTokens {
    enum Layout {
        static let narrativeWidth: CGFloat = 460
    }

    enum ColorRole {
        static let bgApp = CourseStyle.ground
        static let surfacePrimary = CourseStyle.surface
        static let surfaceTinted = CourseStyle.wash
        static let surfaceOverlay = CourseStyle.surface

        static let textPrimary = CourseStyle.ink
        static let textSecondary = CourseStyle.muted
        static let textTertiary = CourseStyle.muted
        static let textInverse = CourseStyle.onAction

        static let pine700 = CourseStyle.action
        static let pine500 = CourseStyle.action
        static let pine300 = Color(red: 0.620, green: 0.765, blue: 0.668)

        static let strokeDefault = CourseStyle.line
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
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let pill: CGFloat = 999
    }

    enum Typography {
        static let sectionTitle = Font.title2.weight(.bold)
        static let body = Font.subheadline
        static let eyebrow = Font.caption.weight(.semibold)
        static let microEyebrow = Font.caption2.weight(.semibold)
    }

    enum Shadow {
        static let floating = Color.black.opacity(0.12)
    }

}

/// Semantic surfaces shared by the course, score and equipment compositions.
enum CourseStyle {
    enum Typography {
        static let courseName = Font.system(.largeTitle, weight: .bold).width(.condensed)
        static let title = Font.system(.title, weight: .bold).width(.condensed)
        static let number = Font.system(.title2, weight: .bold).width(.condensed)

    }

    static let ground = Color("CourseGround")
    static let surface = Color("CourseSurface")
    static let ink = Color("CourseInk")
    static let muted = Color("CourseMuted")
    static let action = Color("CourseAction")
    static let onAction = Color("CourseOnAction")
    static let line = Color("CourseLine")
    static let wash = Color("CourseWash")
    static let warning = Color("CourseWarning")
}
