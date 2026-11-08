import SwiftUI

/// The bag as a caddie's club chart: one ruled line per club, longest first,
/// each carry drawn to a common scale so the gaps between clubs are visible.
struct CarryLadder: View {
    let clubs: [Club]
    let distanceUnit: DistanceUnit

    private var ordered: [Club] {
        clubs.filter { !$0.isPutter && $0.typicalDistanceMeters > 0 }.sorted { $0.typicalDistanceMeters > $1.typicalDistanceMeters }
    }

    var body: some View {
        let longest = Double(ordered.first?.typicalDistanceMeters ?? 1)
        VStack(alignment: .leading, spacing: 7) {
            ForEach(ordered.prefix(14)) { club in
                HStack(spacing: 10) {
                    Text(club.name)
                        .font(.system(.subheadline, weight: .bold).width(.condensed))
                        .lineLimit(1)
                        .frame(width: 58, alignment: .leading)
                    GeometryReader { g in
                        let w = max(g.size.width * CGFloat(Double(club.typicalDistanceMeters) / longest), 6)
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Book.rule).frame(height: 1)
                            Capsule().fill(Book.fairway).frame(width: w, height: 10)
                                .overlay(alignment: .trailing) {
                                    Circle().fill(Book.ink).frame(width: 6, height: 6).padding(.trailing, 2)
                                }
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(height: 14)
                    Text("\(distanceUnit.scalarValue(fromMeters: club.typicalDistanceMeters))")
                        .font(.system(.subheadline, weight: .semibold).width(.condensed))
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(club.name), \(distanceUnit.shortLabel(forMeters: club.typicalDistanceMeters)) carry")
            }
            if ordered.count > 14 {
                BookNote("+\(ordered.count - 14) more")
            }
            HStack {
                Spacer()
                BookNote("Carry, \(distanceUnit == .meters ? "metres" : "yards")")
            }
        }
    }
}
