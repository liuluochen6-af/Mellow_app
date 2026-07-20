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
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await APIClient.shared.get("/api/checkins/calendar?year=\(currentYear)&month=\(currentMonth)")
            let response = try JSONDecoder().decode(CheckInListResponse.self, from: data)
            monthCheckIns = response.items
            await loadStickers(for: response.items)
        } catch {
            monthCheckIns = []
        }
    }

    func loadStickers(for checkIns: [CheckInResponse]) async {
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

        await withTaskGroup(of: (UUID, UIImage?).self) { group in
            for checkIn in toProcess {
                let checkInId = checkIn.id
                let photoUrl = checkIn.photoUrl
                group.addTask {
                    let urlString = baseURL + photoUrl
                    guard let url = URL(string: urlString),
                          let (data, _) = try? await URLSession.shared.data(from: url),
                          let image = UIImage(data: data) else {
                        return (checkInId, nil)
                    }

                    let sticker = await StickerService.shared.extractSubject(from: image, cacheKey: photoUrl)
                    return (checkInId, sticker)
                }
            }

            for await (id, image) in group {
                if let image {
                    stickers[id] = image
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
