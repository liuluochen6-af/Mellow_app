import Foundation
import UIKit

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var currentYear: Int
    @Published var currentMonth: Int
    @Published var monthCheckIns: [CheckInResponse] = []
    @Published var yearSummary: [Int: Int] = [:]
    @Published var isLoading = false
    @Published var selectedDay: Int? = nil
    @Published var stickers: [UUID: UIImage] = [:]
    private var stickerTask: Task<Void, Never>?

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        return cal
    }

    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        var components = DateComponents()
        components.year = currentYear
        components.month = currentMonth
        let date = calendar.date(from: components) ?? Date()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    var daysInMonth: Int {
        var components = DateComponents()
        components.year = currentYear
        components.month = currentMonth
        let date = calendar.date(from: components) ?? Date()
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    var firstWeekday: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Force Sunday = first day
        var components = DateComponents()
        components.year = currentYear
        components.month = currentMonth
        components.day = 1
        guard let date = cal.date(from: components) else { return 0 }
        // .weekday: 1=Sun, 2=Mon, ..., 7=Sat
        let weekday = cal.component(.weekday, from: date)
        return weekday - 1 // 0=Sun, 1=Mon, ..., 6=Sat -> number of blank cells
    }

    var monthStats: (count: Int, places: Int) {
        let count = monthCheckIns.count
        let places = Set(monthCheckIns.compactMap { $0.placeId ?? $0.placeName }).count
        return (count, places)
    }

    init() {
        let now = Date()
        self.currentYear = Calendar.current.component(.year, from: now)
        self.currentMonth = Calendar.current.component(.month, from: now)
    }

    func loadMonth() async {
        let year = currentYear
        let month = currentMonth
        let path = "/api/checkins/calendar?year=\(year)&month=\(month)"
        stickerTask?.cancel()

        var showedCache = false
        if let cached = await APIClient.shared.cachedData(for: path),
           let response = try? JSONDecoder().decode(CheckInListResponse.self, from: cached),
           year == currentYear, month == currentMonth {
            monthCheckIns = response.items
            showedCache = true
            scheduleStickerLoad(for: response.items)
        }

        isLoading = !showedCache
        defer { isLoading = false }

        do {
            let data = try await APIClient.shared.get(path)
            let response = try JSONDecoder().decode(CheckInListResponse.self, from: data)
            guard year == currentYear, month == currentMonth else { return }
            monthCheckIns = response.items
            await APIClient.shared.cache(data, for: path)
            scheduleStickerLoad(for: response.items)
        } catch {
            if !showedCache {
                monthCheckIns = []
            }
        }
    }

    private func scheduleStickerLoad(for checkIns: [CheckInResponse]) {
        guard #available(iOS 17.0, *) else { return }

        // Group by day, take first check-in per day to avoid redundant processing
        var seenDays: Set<Int> = []
        var toProcess: [CheckInResponse] = []
        for checkIn in checkIns {
            guard let date = DateParsing.parse(checkIn.createdAt) else { continue }
            let day = calendar.component(.day, from: date)
            if !seenDays.contains(day) && stickers[checkIn.id] == nil {
                seenDays.insert(day)
                toProcess.append(checkIn)
            }
        }

        let baseURL = APIClient.shared.baseURL
        stickerTask = Task(priority: .utility) { [weak self] in
            // Process serially to avoid several full Vision pipelines peaking
            // in memory at the same time. Cached stickers return immediately.
            for checkIn in toProcess {
                guard !Task.isCancelled,
                      let url = URL(string: baseURL + checkIn.photoUrl) else { return }
                let image = await StickerService.shared.sticker(
                    from: url,
                    cacheKey: checkIn.photoUrl
                )
                guard !Task.isCancelled else { return }
                if let image {
                    self?.stickers[checkIn.id] = image
                }
            }
        }
    }

    func loadYearSummary() async {
        do {
            let data = try await APIClient.shared.get("/api/checkins/year-summary?year=\(currentYear)")
            struct YearResp: Codable { let year: Int; let months: [String: Int] }
            let response = try JSONDecoder().decode(YearResp.self, from: data)
            yearSummary = Dictionary(uniqueKeysWithValues: response.months.compactMap { k, v in
                Int(k).map { ($0, v) }
            })
        } catch {
            yearSummary = [:]
        }
    }

    func checkInsForDay(_ day: Int) -> [CheckInResponse] {
        monthCheckIns.filter { checkIn in
            guard let date = DateParsing.parse(checkIn.createdAt) else { return false }
            return calendar.component(.day, from: date) == day
        }
    }

    func stickerForDay(_ day: Int) -> UIImage? {
        let dayCheckIns = checkInsForDay(day)
        for checkIn in dayCheckIns {
            if let sticker = stickers[checkIn.id] {
                return sticker
            }
        }
        return nil
    }

    func goToToday() {
        let now = Date()
        currentYear = calendar.component(.year, from: now)
        currentMonth = calendar.component(.month, from: now)
        selectedDay = nil
    }

    func previousMonth() {
        if currentMonth == 1 {
            currentMonth = 12
            currentYear -= 1
        } else {
            currentMonth -= 1
        }
        selectedDay = nil
    }

    func nextMonth() {
        if currentMonth == 12 {
            currentMonth = 1
            currentYear += 1
        } else {
            currentMonth += 1
        }
        selectedDay = nil
    }
}
