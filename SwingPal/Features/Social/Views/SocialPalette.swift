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

    static func forColorScheme(_ colorScheme: ColorScheme) -> SocialPalette {
        .init(
            backgroundBase: CourseStyle.ground,
            backgroundTopGlow: CourseStyle.ground,
            backgroundBottomGlow: CourseStyle.ground,
            cardTint: CourseStyle.surface,
            cardStrongTint: CourseStyle.wash,
            cardMutedTint: CourseStyle.surface,
            border: CourseStyle.line,
            primaryText: CourseStyle.ink,
            secondaryText: CourseStyle.muted,
            tertiaryText: CourseStyle.muted,
            accent: CourseStyle.action,
            accentForeground: CourseStyle.onAction,
            quietFill: CourseStyle.wash,
            shadow: Color.clear
        )
    }
}
