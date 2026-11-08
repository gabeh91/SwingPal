import SwiftUI

/// The day's conditions as the book notes them: wind first, then what else
/// changes how the ball flies, and where the GPS thinks you are.
struct FreshLiveRoundConditionsSheet: View {
    @ObservedObject var state: LiveRoundState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    wind

                    BookGroup("On the course", ruleInset: 50) {
                        conditionRow(
                            symbol: "thermometer.medium",
                            title: "Temperature",
                            value: state.weatherSnapshot != nil ? state.temperatureSummaryText : "Not loaded",
                            note: state.weatherSnapshot != nil && state.playsLikeTemperatureDeltaMeters != 0
                                ? playsLikeDeltaText(meters: state.playsLikeTemperatureDeltaMeters, suffix: " from temperature")
                                : nil
                        )
                        conditionRow(symbol: state.weatherSnapshot?.symbolName ?? "cloud", title: "Sky", value: state.weatherConditionText, note: nil)
                        conditionRow(symbol: "location", title: "GPS", value: state.playerLocationStatusText, note: nil)
                    }

                    if let attribution = state.weatherAttributionText {
                        Text(attribution)
                            .font(.footnote)
                            .foregroundStyle(Book.pencil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .bookSheetChrome()
            .navigationTitle("Conditions")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Book.paper)
    }

    // MARK: Wind

    private var wind: some View {
        let hasWeather = state.weatherSnapshot != nil
        let isCalm = !state.hasUsableWindReading
        let breakdown = hasWeather ? state.windComponentBreakdownText : nil
        let playsLike = hasWeather && state.playsLikeWindDeltaMeters != 0 ? playsLikeDeltaText(meters: state.playsLikeWindDeltaMeters) : nil

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 18) {
                dial(diameter: 92, isCalm: !hasWeather || isCalm)
                VStack(alignment: .leading, spacing: 2) {
                    BookNote(hasWeather ? "Wind" : "Wind unavailable")
                    if let weather = state.weatherSnapshot {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(weather.windSpeedKilometersPerHour)")
                                .font(.system(size: 48, weight: .bold).width(.condensed))
                                .monospacedDigit()
                            Text("km/h").font(.subheadline.weight(.semibold)).foregroundStyle(Book.pencil)
                        }
                        Text(isCalm ? "Calm" : state.windRelativeCategory.label).font(Book.Typeface.subheading)
                    } else {
                        Text("Live conditions haven't loaded yet.")
                            .font(.subheadline)
                            .foregroundStyle(Book.pencil)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            if breakdown != nil || playsLike != nil {
                BookGroup(ruleInset: 50) {
                    if let breakdown {
                        conditionRow(symbol: "scope", title: "Along and across your line", value: breakdown, note: nil)
                    }
                    if let playsLike {
                        conditionRow(symbol: "ruler", title: "Plays like", value: playsLike, note: nil)
                    }
                }
            }
        }
    }

    /// A compass rose drawn in pencil, the arrow showing where the wind
    /// carries the ball relative to your line (up = straight down it).
    private func dial(diameter: CGFloat, isCalm: Bool) -> some View {
        let rotation = state.windRelativeMotionDegrees ?? 0
        return ZStack {
            Circle().fill(Book.leaf)
            Circle().strokeBorder(Book.rule, lineWidth: 1)
            ForEach(0..<12, id: \.self) { index in
                Rectangle()
                    .fill(index % 3 == 0 ? Book.ink.opacity(0.7) : Book.rule)
                    .frame(width: index % 3 == 0 ? 1.5 : 1, height: index % 3 == 0 ? 8 : 5)
                    .offset(y: -(diameter / 2) + (index % 3 == 0 ? 6 : 5))
                    .rotationEffect(.degrees(Double(index) * 30))
            }
            if isCalm {
                Circle().stroke(Book.pencil, style: StrokeStyle(lineWidth: 1.5, dash: [2, 3])).frame(width: diameter * 0.3)
            } else {
                Image(systemName: "arrow.up")
                    .font(.system(size: diameter * 0.4, weight: .bold))
                    .foregroundStyle(Book.ink)
                    .rotationEffect(.degrees(rotation))
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(.easeInOut(duration: 0.3), value: rotation)
        .accessibilityHidden(true)
    }

    private func conditionRow(symbol: String, title: String, value: String, note: String?) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(Book.pencil)
                .frame(width: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(Book.pencil)
                Text(value).font(.body.weight(.medium))
                if let note {
                    Text(note).font(.caption.weight(.medium)).foregroundStyle(Book.stamp)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func playsLikeDeltaText(meters: Int, suffix: String = "") -> String {
        let scalar = state.distanceUnit.scalarValue(fromMeters: abs(meters))
        let unitSuffix = state.distanceUnit.shortSuffix
        if meters > 0 {
            return "+\(scalar)\(unitSuffix) to plays-like\(suffix)"
        } else if meters < 0 {
            return "-\(scalar)\(unitSuffix) to plays-like\(suffix)"
        } else {
            return "No effect on plays-like\(suffix)"
        }
    }
}
