import SwiftUI

struct YearView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var showYearView: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
    private let monthNames = ["1月", "2月", "3月", "4月", "5月", "6月",
                              "7月", "8月", "9月", "10月", "11月", "12月"]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button { viewModel.currentYear -= 1 } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text("\(String(viewModel.currentYear))年")
                    .font(.headline)
                Spacer()
                Button { viewModel.currentYear += 1 } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(1...12, id: \.self) { month in
                    Button {
                        viewModel.currentMonth = month
                        withAnimation { showYearView = false }
                    } label: {
                        VStack(spacing: 6) {
                            Text(monthNames[month - 1])
                                .font(.subheadline.bold())
                                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))

                            let count = viewModel.yearSummary[month] ?? 0
                            RoundedRectangle(cornerRadius: 8)
                                .fill(intensityColor(count: count))
                                .frame(height: 60)
                                .overlay(
                                    count > 0
                                        ? Text("\(count)")
                                            .font(.title3.bold())
                                            .foregroundColor(.white)
                                        : nil
                                )
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.6))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        viewModel.currentYear += 1
                    } else if value.translation.width > 50 {
                        viewModel.currentYear -= 1
                    }
                }
        )
        .task { await viewModel.loadYearSummary() }
        .onChange(of: viewModel.currentYear) { _, _ in
            Task { await viewModel.loadYearSummary() }
        }
    }

    private func intensityColor(count: Int) -> Color {
        let base = Color(red: 0.76, green: 0.6, blue: 0.42)
        if count == 0 { return Color(.systemGray5) }
        let opacity = min(Double(count) / 15.0, 1.0) * 0.7 + 0.3
        return base.opacity(opacity)
    }
}
