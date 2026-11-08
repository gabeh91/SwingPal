import Foundation

struct RoundWeatherSnapshot: Equatable, Sendable {
    let temperatureCelsius: Int
    let apparentTemperatureCelsius: Int
    let conditionDescription: String
    let symbolName: String
    let windSpeedKilometersPerHour: Int
    let windCompassDirection: String
    /// Bearing the wind is blowing *from*, in degrees (0° = N, 90° = E). Optional
    /// because not every loader / preview populates it; consumers (e.g. the
    /// plays-like calculator) fall back to the compass string when absent.
    let windDirectionDegrees: Double?
    let attributionText: String?

    init(
        temperatureCelsius: Int,
        apparentTemperatureCelsius: Int,
        conditionDescription: String,
        symbolName: String,
        windSpeedKilometersPerHour: Int,
        windCompassDirection: String,
        windDirectionDegrees: Double? = nil,
        attributionText: String?
    ) {
        self.temperatureCelsius = temperatureCelsius
        self.apparentTemperatureCelsius = apparentTemperatureCelsius
        self.conditionDescription = conditionDescription
        self.symbolName = symbolName
        self.windSpeedKilometersPerHour = windSpeedKilometersPerHour
        self.windCompassDirection = windCompassDirection
        self.windDirectionDegrees = windDirectionDegrees
        self.attributionText = attributionText
    }

    static let preview = RoundWeatherSnapshot(
        temperatureCelsius: 22,
        apparentTemperatureCelsius: 24,
        conditionDescription: "Partly cloudy",
        symbolName: "cloud.sun.fill",
        windSpeedKilometersPerHour: 7,
        windCompassDirection: "NW",
        windDirectionDegrees: 315,
        attributionText: nil
    )
}
