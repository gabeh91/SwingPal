import Foundation
import CoreLocation
import WeatherKit

struct AppleWeatherKitLoader: RoundWeatherLoading {
    private let locationProvider: DeviceLocationProviding?
    private let weatherService: WeatherService

    init(
        locationProvider: DeviceLocationProviding? = nil,
        weatherService: WeatherService = WeatherService()
    ) {
        self.locationProvider = locationProvider
        self.weatherService = weatherService
    }

    func fetchCurrentWeather() async throws -> RoundWeatherSnapshot {
        let location = try await currentLocation()
        let weather = try await weatherService.weather(for: location)
        let attribution = try await weatherService.attribution
        let current = weather.currentWeather

        return RoundWeatherSnapshot(
            temperatureCelsius: Int(current.temperature.converted(to: .celsius).value.rounded()),
            apparentTemperatureCelsius: Int(current.apparentTemperature.converted(to: .celsius).value.rounded()),
            conditionDescription: current.condition.description,
            symbolName: current.symbolName,
            windSpeedKilometersPerHour: Int(current.wind.speed.converted(to: .kilometersPerHour).value.rounded()),
            windCompassDirection: current.wind.compassDirection.description.uppercased(),
            windDirectionDegrees: current.wind.direction.converted(to: .degrees).value,
            attributionText: attribution.legalAttributionText
        )
    }

    @MainActor
    private func currentLocation() async throws -> CLLocation {
        let provider = locationProvider ?? DeviceLocationProvider()
        return try await provider.currentLocation()
    }
}

protocol DeviceLocationProviding {
    func currentLocation() async throws -> CLLocation
}

enum DeviceLocationError: Error {
    case unauthorized
    case unavailable
}

@MainActor
final class DeviceLocationProvider: NSObject, @preconcurrency CLLocationManagerDelegate, DeviceLocationProviding {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func currentLocation() async throws -> CLLocation {
        try await ensureAuthorization()

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    private func ensureAuthorization() async throws {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return
        case .notDetermined:
            try await withCheckedThrowingContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        default:
            throw DeviceLocationError.unauthorized
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let authorizationContinuation else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            self.authorizationContinuation = nil
            authorizationContinuation.resume()
        case .denied, .restricted:
            self.authorizationContinuation = nil
            authorizationContinuation.resume(throwing: DeviceLocationError.unauthorized)
        case .notDetermined:
            break
        @unknown default:
            self.authorizationContinuation = nil
            authorizationContinuation.resume(throwing: DeviceLocationError.unavailable)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil

        if let location = locations.first {
            continuation.resume(returning: location)
        } else {
            continuation.resume(throwing: DeviceLocationError.unavailable)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(throwing: error)
    }
}
