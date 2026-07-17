import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var showPhotoGallery = false
    @State private var showMonthStats = false
    @State private var showYearPicker = false
    @State private var showMonthPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("今天")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                Text(todaySubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Year/Month Picker
            HStack(spacing: 8) {
                Button {
                    showYearPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text("\(String(viewModel.currentYear))年")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.76, green: 0.6, blue: 0.42), lineWidth: 1.5))
                }
                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))

                Button {
                    showMonthPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text("\(viewModel.currentMonth)月")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.76, green: 0.6, blue: 0.42), lineWidth: 1.5))
                }
                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))

                Spacer()

                Button {
                    viewModel.goToToday()
                } label: {
                    Text("回到今天")
                        .font(.caption)
                        .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Calendar card
            MonthView(viewModel: viewModel)
                .padding(.horizontal, 16)

            // Day detail (shown between calendar and stats when a day is selected)
            if let selectedDay = viewModel.selectedDay {
                let dayCheckIns = viewModel.checkInsForDay(selectedDay)
                if !dayCheckIns.isEmpty {
                    DayDetailView(day: selectedDay, month: viewModel.currentMonth, checkIns: dayCheckIns)
                        .padding(.top, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            Spacer()

            // Stats + Photo gallery
            HStack(spacing: 12) {
                // Stats card (tappable to open monthly stats)
                Button { showMonthStats = true } label: {
                    statsCard
                }
                .buttonStyle(.plain)

                // Photo preview stack (tappable to open gallery)
                Button { showPhotoGallery = true } label: {
                    photoPreview
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(red: 0.98, green: 0.96, blue: 0.93).ignoresSafeArea())
        .sheet(isPresented: $showPhotoGallery) {
            PhotoGalleryView(viewModel: viewModel)
        }
        .sheet(isPresented: $showMonthStats) {
            MonthStatsView(viewModel: viewModel)
        }
        .confirmationDialog("选择年份", isPresented: $showYearPicker) {
            ForEach((2020...Calendar.current.component(.year, from: Date())), id: \.self) { year in
                Button("\(String(year))年") {
                    viewModel.currentYear = year
                }
            }
        }
        .confirmationDialog("选择月份", isPresented: $showMonthPicker) {
            ForEach(1...12, id: \.self) { month in
                Button("\(month)月") {
                    viewModel.currentMonth = month
                }
            }
        }
        .task { await viewModel.loadMonth() }
        .onChange(of: viewModel.currentMonth) { _, _ in
            Task { await viewModel.loadMonth() }
        }
        .onChange(of: viewModel.currentYear) { _, _ in
            Task { await viewModel.loadMonth() }
        }
    }

    private var todaySubtitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日, EEEE"
        return formatter.string(from: Date())
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("本月")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(viewModel.monthStats.count)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                Text("次打卡")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("\(viewModel.monthStats.places) 店铺")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
    }

    private var photoPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .frame(height: 100)

            if viewModel.monthCheckIns.isEmpty {
                Text("暂无照片")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ZStack {
                    ForEach(Array(viewModel.monthCheckIns.prefix(3).enumerated()), id: \.element.id) { index, checkIn in
                        AsyncImage(url: URL(string: APIClient.shared.baseURL + checkIn.photoUrl)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 54, height: 66)
                        .clipped()
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                        .rotationEffect(.degrees(Double(index - 1) * 8))
                        .offset(x: CGFloat(index - 1) * 18)
                    }
                }

                // Photo count badge
                VStack {
                    HStack {
                        Spacer()
                        Text("\(viewModel.monthCheckIns.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.76, green: 0.6, blue: 0.42))
                            .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 100)
    }
}
