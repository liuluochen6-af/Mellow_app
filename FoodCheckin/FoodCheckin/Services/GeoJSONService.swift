import Foundation
import MapKit

struct GeoRegion: Identifiable {
    let id = UUID()
    let name: String
    let coordinates: [[CLLocationCoordinate2D]]
    var isVisited: Bool = false
}

class GeoJSONService {
    static let shared = GeoJSONService()

    private var cache: [String: [GeoRegion]] = [:]

    /// Load GeoJSON regions from a bundled file.
    ///
    /// Expected file format: standard GeoJSON FeatureCollection with `properties.name`
    /// for each Feature.
    ///
    /// GeoJSON data files to place in the bundle:
    /// - `countries.json`         — world countries (FeatureCollection)
    /// - `china-provinces.json`   — China province boundaries (FeatureCollection)
    /// - `china-cities.json`      — China city boundaries (FeatureCollection)
    ///
    /// NOTE: Real high-fidelity boundary files (Natural Earth, DataV, etc.) should replace
    /// the placeholder rectangles currently in `china-provinces.json`. Download simplified
    /// GeoJSON from sources like:
    ///   - https://geojson.cn
    ///   - https://datav.aliyun.com/portal/school/atlas/area_selector
    ///   - Natural Earth (naturalearthdata.com) for world countries
    func loadRegions(from filename: String) -> [GeoRegion] {
        if let cached = cache[filename] {
            return cached
        }

        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else {
            return []
        }

        let regions = features.compactMap { feature -> GeoRegion? in
            guard let properties = feature["properties"] as? [String: Any],
                  let name = properties["name"] as? String,
                  let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String else { return nil }

            var polygons: [[CLLocationCoordinate2D]] = []

            if type == "Polygon", let coords = geometry["coordinates"] as? [[[Double]]] {
                for ring in coords {
                    let coordinates = ring.map {
                        CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
                    }
                    polygons.append(coordinates)
                }
            } else if type == "MultiPolygon", let multiCoords = geometry["coordinates"] as? [[[[Double]]]] {
                for polygon in multiCoords {
                    for ring in polygon {
                        let coordinates = ring.map {
                            CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
                        }
                        polygons.append(coordinates)
                    }
                }
            }

            guard !polygons.isEmpty else { return nil }
            return GeoRegion(name: name, coordinates: polygons)
        }

        cache[filename] = regions
        return regions
    }

    /// Filter regions to only those whose name is in the visited set.
    func filterVisited(regions: [GeoRegion], visitedNames: Set<String>) -> [GeoRegion] {
        return regions.map { region in
            var r = region
            r.isVisited = visitedNames.contains(region.name)
            return r
        }.filter { $0.isVisited }
    }

    func clearCache() {
        cache.removeAll()
    }
}
