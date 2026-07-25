import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var showYearPicker = false
    @State private var showMonthPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("今天")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
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
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
                }
                .foregroundColor(.black)

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
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
                }
                .foregroundColor(.black)

                Spacer()

                Button {
                    viewModel.goToToday()
                } label: {
                    Text("回到今天")
                        .font(.caption)
                        .foregroundColor(.black)
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
        }
        .background(Color.white.ignoresSafeArea())
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
        .onReceive(NotificationCenter.default.publisher(for: .checkInDidPublish)) { _ in
            Task { await viewModel.loadMonth() }
        }
    }

    private var todaySubtitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日, EEEE"
        return formatter.string(from: Date())
    }

}
