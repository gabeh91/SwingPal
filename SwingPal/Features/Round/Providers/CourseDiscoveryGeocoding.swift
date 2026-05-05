import Foundation
import CoreLocation

/// Resolves a coarse country code (ISO 3166-1 alpha-2) for a given GPS
/// location. Used by round-setup discovery to scope name searches to the
/// user's country, per the plan.
protocol CountryCodeGeocoding {
    func countryCode(for location: CLLocation) async throws -> String?
}

struct AppleCountryCodeGeocoder: CountryCodeGeocoding {
    private let geocoder: CLGeocoder

    init(geocoder: CLGeocoder = CLGeocoder()) {
        self.geocoder = geocoder
    }

    func countryCode(for location: CLLocation) async throws -> String? {
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        return placemarks.first?.isoCountryCode?.uppercased()
    }
}
