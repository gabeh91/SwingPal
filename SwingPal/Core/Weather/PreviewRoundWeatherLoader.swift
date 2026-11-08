import Foundation

struct PreviewRoundWeatherLoader: RoundWeatherLoading {
    func fetchCurrentWeather() async throws -> RoundWeatherSnapshot {
        .preview
    }
}
