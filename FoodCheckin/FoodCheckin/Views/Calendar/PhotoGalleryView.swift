import SwiftUI

struct PhotoGalleryView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showMonthPicker = false

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.monthCheckIns.isEmpty {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 100)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("本月暂无打卡照片")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(groupedByDay, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(dayLabel(group.day))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                                    .padding(.horizontal, 4)

                                LazyVGrid(columns: columns, spacing: 4) {
                                    ForEach(group.checkIns) { checkIn in
                                        GalleryPhotoCell(checkIn: checkIn)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(red: 0.98, green: 0.96, blue: 0.93))
            .navigationTitle("照片墙")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        showMonthPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(monthLabel)
                                .font(.headline)
                                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .confirmationDialog("选择月份", isPresented: $showMonthPicker) {
                ForEach(1...12, id: \.self) { month in
                    Button("\(viewModel.currentYear)年\(month)月") {
                        viewModel.currentMonth = month
                    }
                }
            }
        }
    }

    private var monthLabel: String {
        "\(viewModel.currentYear)年\(viewModel.currentMonth)月"
    }

    private struct DayGroup {
        let day: Int
        let checkIns: [CheckInResponse]
    }

    private var groupedByDay: [DayGroup] {
        let cal = Calendar.current
        let isoFormatter = ISO8601DateFormatter()

        var dict: [Int: [CheckInResponse]] = [:]
        for checkIn in viewModel.monthCheckIns {
            guard let date = isoFormatter.date(from: checkIn.createdAt) else { continue }
            let day = cal.component(.day, from: date)
            dict[day, default: []].append(checkIn)
        }

        return dict.keys.sorted(by: >).map { day in
            DayGroup(day: day, checkIns: dict[day]!)
        }
    }

    private func dayLabel(_ day: Int) -> String {
        var components = DateComponents()
        components.year = viewModel.currentYear
        components.month = viewModel.currentMonth
        components.day = day
        guard let date = Calendar.current.date(from: components) else { return "\(day)日" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }
}

struct GalleryPhotoCell: View {
    let checkIn: CheckInResponse

    var body: some View {
        ZStack(alignment: .topLeading) {
            AsyncImage(url: URL(string: APIClient.shared.baseURL + checkIn.photoUrl)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.1)
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .clipped()
            .cornerRadius(6)

            // Place name overlay at bottom
            VStack {
                Spacer()
                Text(checkIn.placeName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            }
            .cornerRadius(6)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct PolaroidCard: View {
    let checkIn: CheckInResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo
            AsyncImage(url: URL(string: APIClient.shared.baseURL + checkIn.photoUrl)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.1)
            }
            .frame(height: 180)
            .clipped()
            .padding(8)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(checkIn.placeName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                    .lineLimit(1)
                Text(formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private var formattedDate: String {
        let isoFormatter = ISO8601DateFormatter()
        guard let date = isoFormatter.date(from: checkIn.createdAt) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}
