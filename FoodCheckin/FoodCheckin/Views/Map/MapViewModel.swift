import Foundation
import MapKit

// MARK: - Models

struct MapPin: Identifiable, Hashable {
    let id: String
    let placeName: String
    let placeId: String?
    let coordinate: CLLocationCoordinate2D
    let category: String
    let rating: Int
    let photoUrl: String
    let createdAt: String
    let city: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MapPin, rhs: MapPin) -> Bool {
        lhs.id == rhs.id
    }
}

struct MapRegionOption: Identifiable {
    let id = UUID()
    let name: String
    let pinCount: Int
    let center: CLLocationCoordinate2D?
    let span: MKCoordinateSpan?
}

struct VisitedPolygon: Identifiable {
    let id: String
    let name: String
    let coordinates: [CLLocationCoordinate2D]
}

// MARK: - Zoom Level

enum MapZoomLevel: Equatable {
    case world      // Show country-level polygon fills
    case country    // Show province-level fills (e.g., China provinces)
    case province   // Show city-level fills
}

// MARK: - ViewModel

@MainActor
class MapViewModel: ObservableObject {
    @Published var pins: [MapPin] = []
    @Published var visitedPolygons: [VisitedPolygon] = []
    @Published var visitedRegions: VisitedRegionsResponse?
    @Published var isLoading = false
    @Published var availableRegions: [MapRegionOption] = []
    @Published var selectedRegion: String = "全球"

    @Published var currentZoomLevel: MapZoomLevel = .world
    @Published var visibleRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
        span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
    )

    private let geoService = GeoJSONService.shared

    // MARK: - Public

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        async let pinsTask: () = loadPins()
        async let regionsTask: () = loadVisitedRegions()
        _ = await (pinsTask, regionsTask)
    }

    /// Called when the map camera changes. Determines whether the zoom level
    /// has changed and reloads the appropriate GeoJSON overlay set.
    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        visibleRegion = region
        updateZoomLevel()
    }

    func updateZoomLevel() {
        let span = visibleRegion.span.latitudeDelta
        let newLevel: MapZoomLevel

        if span > 60 {
            newLevel = .world
        } else if span > 5 {
            newLevel = .country
        } else {
            newLevel = .province
        }

        if newLevel != currentZoomLevel {
            currentZoomLevel = newLevel
            loadRegionsForLevel(newLevel)
        }
    }

    func buildRegionOptions() {
        var options: [MapRegionOption] = [
            MapRegionOption(name: "全球", pinCount: pins.count, center: nil, span: nil)
        ]

        // Group pins by city
        let cityGroups = Dictionary(grouping: pins.filter { !$0.city.isEmpty }) { $0.city }

        for (city, cityPins) in cityGroups.sorted(by: { $0.value.count > $1.value.count }) {
            // Calculate center of city pins
            let avgLat = cityPins.map(\.coordinate.latitude).reduce(0, +) / Double(cityPins.count)
            let avgLon = cityPins.map(\.coordinate.longitude).reduce(0, +) / Double(cityPins.count)
            let center = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)

            options.append(MapRegionOption(
                name: city,
                pinCount: cityPins.count,
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
            ))
        }

        availableRegions = options
    }

    // MARK: - Private: Data Loading

    private func loadPins() async {
        do {
            let data = try await APIClient.shared.get("/api/checkins/map-pins")
            let response = try JSONDecoder().decode(MapPinsResponse.self, from: data)
            pins = response.pins.map { pin in
                let coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
                return MapPin(
                    id: pin.id,
                    placeName: pin.placeName,
                    placeId: pin.placeId,
                    coordinate: coordinate,
                    category: pin.category,
                    rating: pin.rating,
                    photoUrl: pin.photoUrl,
                    createdAt: pin.createdAt,
                    city: CityRegionNormalizer.cityName(
                        country: "",
                        province: "",
                        locality: pin.city ?? "",
                        coordinate: coordinate
                    )
                )
            }
            buildRegionOptions()
        } catch {
            pins = []
        }
    }

    private func loadVisitedRegions() async {
        do {
            let data = try await APIClient.shared.get("/api/checkins/visited-regions")
            let response = try JSONDecoder().decode(VisitedRegionsResponse.self, from: data)
            visitedRegions = response
            loadRegionsForLevel(currentZoomLevel)
        } catch {
            visitedRegions = nil
        }
    }

    // MARK: - Private: Region Overlay Loading

    /// Load the appropriate GeoJSON polygons based on the current zoom level
    /// and the user's visited regions data.
    private func loadRegionsForLevel(_ level: MapZoomLevel) {
        guard let regions = visitedRegions else {
            visitedPolygons = []
            return
        }

        var polygons: [VisitedPolygon] = []

        switch level {
        case .world:
            let allCountries = geoService.loadRegions(from: "countries")
            let visitedSet = Set(regions.countries)
            let visited = geoService.filterVisited(regions: allCountries, visitedNames: visitedSet)
            polygons = buildPolygons(from: visited)

        case .country:
            let allProvinces = geoService.loadRegions(from: "china-provinces")
            let visitedSet = Set(regions.provinces)
            let visited = geoService.filterVisited(regions: allProvinces, visitedNames: visitedSet)
            polygons = buildPolygons(from: visited)

        case .province:
            let allCities = geoService.loadRegions(from: "china-cities")
            if allCities.isEmpty {
                let allProvinces = geoService.loadRegions(from: "china-provinces")
                let visitedSet = Set(regions.provinces)
                let visited = geoService.filterVisited(regions: allProvinces, visitedNames: visitedSet)
                polygons = buildPolygons(from: visited)
            } else {
                let visitedSet = Set(regions.cities)
                let visited = geoService.filterVisited(regions: allCities, visitedNames: visitedSet)
                polygons = buildPolygons(from: visited)
            }

        }

        visitedPolygons = polygons
    }

    /// Convert GeoRegion array to VisitedPolygon array (one polygon per coordinate ring).
    private func buildPolygons(from geoRegions: [GeoRegion]) -> [VisitedPolygon] {
        var result: [VisitedPolygon] = []
        for region in geoRegions {
            for (index, ring) in region.coordinates.enumerated() {
                result.append(VisitedPolygon(
                    id: "\(region.name)-\(index)",
                    name: region.name,
                    coordinates: ring
                ))
            }
        }
        return result
    }
}

// MARK: - API Response Models

struct MapPinData: Codable {
    let id: String
    let placeName: String
    let placeId: String?
    let latitude: Double
    let longitude: Double
    let category: String
    let rating: Int
    let photoUrl: String
    let createdAt: String
    let city: String?

    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, category, rating, city
        case placeName = "place_name"
        case placeId = "place_id"
        case photoUrl = "photo_url"
        case createdAt = "created_at"
    }
}

struct MapPinsResponse: Codable {
    let pins: [MapPinData]
}

struct VisitedRegionsResponse: Codable {
    let countries: [String]
    let provinces: [String]
    let cities: [String]
    let districts: [String]
}
