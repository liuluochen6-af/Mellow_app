import SwiftUI

struct MonthView: View {
    @ObservedObject var viewModel: CalendarViewModel
    private let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 10) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<viewModel.firstWeekday, id: \.self) { i in
                    Color.clear.frame(height: 44)
                        .id("blank_\(i)")
                }

                ForEach(1...viewModel.daysInMonth, id: \.self) { day in
                    DayCellView(
                        day: day,
                        checkIns: viewModel.checkInsForDay(day),
                        isToday: isToday(day),
                        isSelected: viewModel.selectedDay == day,
                        stickerImage: viewModel.stickerForDay(day)
                    )
                    .onTapGesture {
                        if !viewModel.checkInsForDay(day).isEmpty {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.selectedDay = viewModel.selectedDay == day ? nil : day
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        withAnimation { viewModel.nextMonth() }
                    } else if value.translation.width > 50 {
                        withAnimation { viewModel.previousMonth() }
                    }
                }
        )
    }

    private func isToday(_ day: Int) -> Bool {
        let now = Date()
        let cal = Calendar.current
        return cal.component(.year, from: now) == viewModel.currentYear
            && cal.component(.month, from: now) == viewModel.currentMonth
            && cal.component(.day, from: now) == day
    }
}
