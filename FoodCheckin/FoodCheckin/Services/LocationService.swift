import Foundation
import CoreLocation
import MapKit

enum CityRegionNormalizer {
    /// MapKit often returns an Australian suburb as `locality`. The map's region
    /// picker is city-level, so locations in metropolitan Melbourne are grouped
    /// under Melbourne instead of suburbs such as Glen Waverley.
    static func cityName(
        country: String,
        province: String,
        locality: String,
        coordinate: CLLocationCoordinate2D
    ) -> String {
        let isInMetropolitanMelbourne =
            (-38.50 ... -37.40).contains(coordinate.latitude) &&
            (144.40 ... 145.80).contains(coordinate.longitude)

        if isInMetropolitanMelbourne {
            return "墨尔本"
        }

        return locality
    }
}

@MainActor
class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var searchResults: [MKMapItem] = []
    @Published var isSearching = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.requestLocation()
    }

    func search(query: String, near coordinate: CLLocationCoordinate2D?) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let coordinate {
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 5000,
                longitudinalMeters: 5000
            )
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> (country: String, province: String, city: String, district: String, address: String)? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            let country = placemark.country ?? ""
            let province = placemark.administrativeArea ?? ""
            let city = CityRegionNormalizer.cityName(
                country: country,
                province: province,
                locality: placemark.locality ?? "",
                coordinate: coordinate
            )
            return (
                country: country,
                province: province,
                city: city,
                district: placemark.subLocality ?? "",
                address: [placemark.country, placemark.administrativeArea, placemark.locality, placemark.subLocality, placemark.thoroughfare, placemark.subThoroughfare].compactMap { $0 }.joined()
            )
        } catch {
            return nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            currentLocation = locations.last?.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse {
                manager.requestLocation()
            }
        }
    }
}
