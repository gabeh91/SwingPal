import SwiftUI

/// Inks for the mark. `.tile` is the Home Screen icon (stamp-green ground);
/// `.page` sits on paper and follows the day/night book.
struct HoleMarkColorway {
    var ground: Color?
    var rings: Color
    var ringOpacity: Double
    var fadesRings: Bool
    var fairway: Color
    var fairwayEdge: Color
    var stripe: Color
    var green: Color
    var contour: Color
    var tee: Color
    var pole: Color
    var pin: Color
    var flag: Color

    static let tile = HoleMarkColorway(
        ground: Color(uiColor: UIColor(bookHex: 0x1E3B2F)),
        rings: Color(uiColor: UIColor(bookHex: 0xF2EFE6)),
        ringOpacity: 0.16,
        fadesRings: false,
        fairway: Color(uiColor: UIColor(bookHex: 0xC9D8AA)),
        fairwayEdge: Color(uiColor: UIColor(bookHex: 0x8BAA73)),
        stripe: Color.white.opacity(0.18),
        green: Color(uiColor: UIColor(bookHex: 0xA3CA8B)),
        contour: Color(uiColor: UIColor(bookHex: 0x5F9150)),
        tee: Color(uiColor: UIColor(bookHex: 0xF2EFE6)),
        pole: Color(uiColor: UIColor(bookHex: 0xF2EFE6)),
        pin: Color(uiColor: UIColor(bookHex: 0x17261F)),
        flag: Color(uiColor: UIColor(bookHex: 0xD4462A))
    )

    static let page = HoleMarkColorway(
        ground: nil,
        rings: Book.pencil,
        ringOpacity: 0.28,
        fadesRings: true,
        fairway: Book.dynamic(0xB9CE92, 0x3F6243),
        fairwayEdge: Book.dynamic(0x6F9160, 0x6C9867),
        stripe: Color(uiColor: UIColor { traits in
            UIColor(white: 1, alpha: traits.userInterfaceStyle == .dark ? 0.07 : 0.22)
        }),
        green: Book.dynamic(0x8FBF74, 0x5A8C52),
        contour: Book.dynamic(0x4F7F44, 0x9CC98C),
        tee: Book.stamp,
        pole: Book.ink,
        pin: Book.dynamic(0x17261F, 0x101714),
        flag: Book.flag
    )
}
