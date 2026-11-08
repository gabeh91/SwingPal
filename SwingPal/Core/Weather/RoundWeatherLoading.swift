import Foundation

protocol RoundWeatherLoading {
    func fetchCurrentWeather() async throws -> RoundWeatherSnapshot
}
