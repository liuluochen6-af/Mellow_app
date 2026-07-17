import Foundation

struct OverviewData {
    var totalCheckins = 0
    var uniquePlaces = 0
    var countries = 0
    var provinces = 0
    var cities = 0
    var districts = 0
}

struct CategoryCount: Codable {
    let category: String
    let count: Int
}

struct SpendingData {
    var total: Double = 0
    var count: Int = 0
    var byCategory: [CategorySpend] = []
}

struct CategorySpend: Codable {
    let category: String
    let amount: Double
}

struct TopPlace: Codable {
    let placeName: String
    let category: String
    let visitCount: Int
    let bestRating: Int

    enum CodingKeys: String, CodingKey {
        case category
        case placeName = "place_name"
        case visitCount = "visit_count"
        case bestRating = "best_rating"
    }
}

@MainActor
class StatsViewModel: ObservableObject {
    @Published var overview = OverviewData()
    @Published var categories: [CategoryCount] = []
    @Published var spending = SpendingData()
    @Published var topPlaces: [TopPlace] = []
    @Published var selectedYear: Int
    @Published var selectedMonth: Int

    init() {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        selectedYear = now.year ?? 2026
        selectedMonth = now.month ?? 1
    }

    var queryParams: String {
        "?year=\(selectedYear)&month=\(selectedMonth)"
    }

    func loadAll() async {
        async let o: () = loadOverview()
        async let c: () = loadCategories()
        async let s: () = loadSpending()
        async let t: () = loadTopPlaces()
        _ = await (o, c, s, t)
    }

    private func loadOverview() async {
        do {
            let data = try await APIClient.shared.get("/api/stats/overview\(queryParams)")
            struct Resp: Codable {
                let totalCheckins: Int
                let uniquePlaces: Int
                let countries: Int
                let provinces: Int
                let cities: Int
                let districts: Int
                enum CodingKeys: String, CodingKey {
                    case countries, provinces, cities, districts
                    case totalCheckins = "total_checkins"
                    case uniquePlaces = "unique_places"
                }
            }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            overview = OverviewData(
                totalCheckins: resp.totalCheckins,
                uniquePlaces: resp.uniquePlaces,
                countries: resp.countries,
                provinces: resp.provinces,
                cities: resp.cities,
                districts: resp.districts
            )
        } catch {}
    }

    private func loadCategories() async {
        do {
            let data = try await APIClient.shared.get("/api/stats/category-breakdown\(queryParams)")
            struct Resp: Codable { let categories: [CategoryCount] }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            categories = resp.categories.sorted { $0.count > $1.count }
        } catch {}
    }

    private func loadSpending() async {
        do {
            let data = try await APIClient.shared.get("/api/stats/spending\(queryParams)")
            struct Resp: Codable {
                let total: Double
                let count: Int
                let byCategory: [CategorySpend]
                enum CodingKeys: String, CodingKey {
                    case total, count
                    case byCategory = "by_category"
                }
            }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            spending = SpendingData(total: resp.total, count: resp.count, byCategory: resp.byCategory)
        } catch {}
    }

    private func loadTopPlaces() async {
        do {
            let data = try await APIClient.shared.get("/api/stats/top-places\(queryParams)")
            struct Resp: Codable { let places: [TopPlace] }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            topPlaces = resp.places
        } catch {}
    }
}
