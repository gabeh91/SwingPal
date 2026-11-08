import SwiftUI
import UIKit

// MARK: - The yardage book
//
// SwingPal's visual world is a caddie's yardage book: every hole drawn to scale
// from supplied geometry, turned tee-to-green, with measurements written beside
// the thing they measure. Paper and ink carry the interface; a single flag colour
// marks the target, the player and scores under par.

enum Book {
    // Paper and ink (asset colours, light + night book).
    static let paper = CourseStyle.ground
    static let leaf = CourseStyle.surface
    static let ink = CourseStyle.ink
    static let pencil = CourseStyle.muted
    static let rule = CourseStyle.line
    static let wash = CourseStyle.wash
    static let stamp = CourseStyle.action
    static let onStamp = CourseStyle.onAction
    static let warning = CourseStyle.warning
    static let flag = Color("BookFlag")

    // Terrain inks. Used only inside hole drawings.
    /// The ground a drawn hole sits on: rough, left plain so the hole reads first.
    static let rough = dynamic(0xE4E6D4, 0x18221D)
    static let fairway = dynamic(0xC9D8AA, 0x2C4531)
    static let fairwayEdge = dynamic(0x8BAA73, 0x4F7550)
    static let green = dynamic(0x9DC486, 0x3F6A3C)
    static let greenContour = dynamic(0x5F9150, 0x7DAA6E)
    static let sand = dynamic(0xEDE0BA, 0x6E6243)
    static let sandDot = dynamic(0xB89C5C, 0xB7A06A)
    static let water = dynamic(0xB3D2DA, 0x274B56)
    static let waterLine = dynamic(0x6798AA, 0x5F90A0)

    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(bookHex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    // MARK: Type
    //
    // Condensed SF for page furniture and figures (the voice of the book),
    // regular SF for reading. Everything scales with Dynamic Type.
    enum Typeface {
        static let folio = Font.system(size: 64, weight: .bold).width(.condensed)
        static let display = Font.system(.largeTitle, weight: .bold).width(.condensed)
        static let title = Font.system(.title, weight: .bold).width(.condensed)
        static let heading = Font.system(.title2, weight: .semibold).width(.condensed)
        static let subheading = Font.system(.title3, weight: .semibold).width(.condensed)
        static let figure = Font.system(.title, weight: .semibold).width(.condensed).monospacedDigit()
        static let smallFigure = Font.system(.headline, weight: .semibold).width(.condensed).monospacedDigit()
        /// Small-capital annotations: the pencil notes of the book.
        static let note = Font.system(.caption, weight: .semibold).width(.expanded)
        static let noteSmall = Font.system(.caption2, weight: .semibold).width(.expanded)
    }
}

extension UIColor {
    convenience init(bookHex hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
