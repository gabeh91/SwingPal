import SwiftUI

// The yardage book on the wrist. The Watch is always dark, so it uses the
// phone's night-book values (docs/design/YARDAGE_BOOK.md) directly: paper and
// ink carry everything, the stamp is the one committed action and the flag
// colour marks the target, the player and scores under par.

enum WatchBook {
    static let paper = Color(bookHex: 0x101714)
    static let leaf = Color(bookHex: 0x18211D)
    static let wash = Color(bookHex: 0x1F2A25)
    static let rule = Color(bookHex: 0x2C3631)
    static let ink = Color(bookHex: 0xECE7DA)
    static let pencil = Color(bookHex: 0xA4AAA0)
    static let stamp = Color(bookHex: 0xCFE3C4)
    static let onStamp = Color(bookHex: 0x13241C)
    static let flag = Color(bookHex: 0xFF7452)
    static let warning = Color(bookHex: 0xFF9F80)

    // Terrain inks, used only inside the hole drawing.
    static let fairway = Color(bookHex: 0x2C4531)
    static let fairwayEdge = Color(bookHex: 0x4F7550)
    static let green = Color(bookHex: 0x3F6A3C)
    static let greenContour = Color(bookHex: 0x7DAA6E)
    static let sand = Color(bookHex: 0x6E6243)
    static let sandDot = Color(bookHex: 0xB7A06A)
    static let water = Color(bookHex: 0x274B56)
    static let waterLine = Color(bookHex: 0x5F90A0)

    enum Typeface {
        /// The hole number, fixed like the phone's folio.
        static let folio = Font.system(size: 34, weight: .bold).width(.condensed).monospacedDigit()
        static let figure = Font.system(size: 46, weight: .bold).width(.condensed).monospacedDigit()
        static let clubCode = Font.system(size: 30, weight: .bold).width(.condensed)
        static let heading = Font.system(.headline, weight: .semibold).width(.condensed)
        static let smallFigure = Font.system(.body, weight: .semibold).width(.condensed).monospacedDigit()
        static let note = Font.system(.caption2, weight: .semibold).width(.expanded)
    }
}

extension Color {
    init(bookHex hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
