import SwiftUI

struct MonthStatsView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var summary: MonthSummary?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding(.top, 100)
                } else if let summary {
                    VStack(spacing: 16) {
                        summaryCards(summary)
                        dailyTable(summary)
                    }
                    .padding(16)
                } else {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 100)
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("本月暂无打卡记录")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color(red: 0.98, green: 0.96, blue: 0.93))
            .navigationTitle("\(viewModel.currentMonth)月统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("返回") { dismiss() }
                }
            }
            .task { await loadSummary() }
        }
    }

    private func summaryCards(_ summary: MonthSummary) -> some View {
        HStack(spacing: 12) {
            SummaryCard(value: "\(summary.totalCheckins)", label: "打卡次数")
            SummaryCard(value: "\(summary.uniquePlaces)", label: "店铺数")
            SummaryCard(value: "¥\(Int(summary.totalSpending))", label: "总消费")
        }
    }

    private func dailyTable(_ summary: MonthSummary) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("日期")
                    .frame(width: 60, alignment: .leading)
                Text("打卡店铺名")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("次数")
                    .frame(width: 40, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.1))

            if summary.dailyBreakdown.isEmpty {
                Text("本月暂无打卡记录")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(32)
            } else {
                ForEach(summary.dailyBreakdown, id: \.day) { entry in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(viewModel.currentMonth)/\(String(format: "%02d", entry.day))")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                            Text("(\(entry.count)次)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 60, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(entry.places, id: \.placeName) { place in
                                HStack(spacing: 4) {
                                    Text(place.emoji)
                                        .font(.caption)
                                    Text(place.placeName)
                                        .font(.subheadline)
                                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                                        .lineLimit(1)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(entry.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider().padding(.leading, 14)
                }
            }
        }
        .background(Color.white)
        .cornerRadius(12)
    }

    private func loadSummary() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await APIClient.shared.get("/api/stats/monthly-summary?year=\(viewModel.currentYear)&month=\(viewModel.currentMonth)")
            let decoded = try JSONDecoder().decode(MonthSummary.self, from: data)
            summary = decoded.totalCheckins > 0 ? decoded : nil
        } catch {
            summary = nil
        }
    }
}

private struct SummaryCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct MonthSummary: Codable {
    let totalCheckins: Int
    let uniquePlaces: Int
    let totalSpending: Double
    let dailyBreakdown: [DailyEntry]

    enum CodingKeys: String, CodingKey {
        case totalCheckins = "total_checkins"
        case uniquePlaces = "unique_places"
        case totalSpending = "total_spending"
        case dailyBreakdown = "daily_breakdown"
    }
}

struct DailyEntry: Codable {
    let day: Int
    let places: [PlaceEntry]
    let count: Int
}

struct PlaceEntry: Codable {
    let placeName: String
    let category: String
    let emoji: String

    enum CodingKeys: String, CodingKey {
        case placeName = "place_name"
        case category
        case emoji
    }
}
