import SwiftUI

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                yearMonthPicker
                overviewCard
                categoryCard
                spendingCard
                topPlacesCard
            }
            .padding()
        }
        .background(Color(red: 0.98, green: 0.96, blue: 0.93).ignoresSafeArea())
        .navigationTitle("统计")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadAll() }
        .onChange(of: viewModel.selectedYear) { _, _ in
            Task { await viewModel.loadAll() }
        }
        .onChange(of: viewModel.selectedMonth) { _, _ in
            Task { await viewModel.loadAll() }
        }
    }

    private var yearMonthPicker: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach((2020...currentYear).reversed(), id: \.self) { year in
                    Button("\(String(year))年") {
                        viewModel.selectedYear = year
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(String(viewModel.selectedYear))年")
                        .font(.headline)
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(20)
            }

            Menu {
                ForEach(1...12, id: \.self) { month in
                    Button("\(month)月") {
                        viewModel.selectedMonth = month
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(viewModel.selectedMonth)月")
                        .font(.headline)
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(20)
            }

            Spacer()

            Button {
                viewModel.selectedMonth = 0
            } label: {
                Text("全年")
                    .font(.subheadline)
                    .foregroundColor(viewModel.selectedMonth == 0 ? .white : Color(red: 0.76, green: 0.6, blue: 0.42))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(viewModel.selectedMonth == 0 ? Color(red: 0.76, green: 0.6, blue: 0.42) : Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.15))
                    .cornerRadius(14)
            }

            Button {
                let now = Calendar.current.dateComponents([.year, .month], from: Date())
                viewModel.selectedYear = now.year ?? 2026
                viewModel.selectedMonth = now.month ?? 1
            } label: {
                Text("本月")
                    .font(.subheadline)
                    .foregroundColor(viewModel.selectedMonth != 0 ? Color(red: 0.76, green: 0.6, blue: 0.42) : Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.15))
                    .cornerRadius(14)
            }
        }
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var overviewCard: some View {
        VStack(spacing: 16) {
            Text("探索足迹")
                .font(.headline)
                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                StatItem(value: "\(viewModel.overview.totalCheckins)", label: "总打卡")
                StatItem(value: "\(viewModel.overview.uniquePlaces)", label: "家店铺")
                StatItem(value: "\(viewModel.overview.countries)", label: "个国家")
                StatItem(value: "\(viewModel.overview.provinces)", label: "个省份")
                StatItem(value: "\(viewModel.overview.cities)", label: "个城市")
                StatItem(value: "\(viewModel.overview.districts)", label: "个区县")
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("类别分布")
                .font(.headline)
                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))

            if viewModel.categories.isEmpty {
                Text("本月暂无打卡")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.categories, id: \.category) { item in
                    HStack {
                        Text(categoryIcon(item.category))
                        Text(categoryName(item.category))
                            .font(.subheadline)
                            .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                        Spacer()
                        Text("\(item.count)")
                            .font(.subheadline.bold())
                            .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))

                        let total = viewModel.categories.reduce(0) { $0 + $1.count }
                        let pct = total > 0 ? Double(item.count) / Double(total) : 0
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.3))
                                .frame(width: geo.size.width * pct)
                        }
                        .frame(width: 60, height: 8)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
    }

    private var spendingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("消费统计")
                .font(.headline)
                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))

            HStack {
                VStack(alignment: .leading) {
                    Text("总消费")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(String(format: "%.0f", viewModel.spending.total))")
                        .font(.title2.bold())
                        .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("记录笔数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.spending.count)")
                        .font(.title2.bold())
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                }
            }

            if !viewModel.spending.byCategory.isEmpty {
                Divider()
                ForEach(viewModel.spending.byCategory, id: \.category) { item in
                    HStack {
                        Text(categoryIcon(item.category))
                        Text(categoryName(item.category))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("¥\(String(format: "%.0f", item.amount))")
                            .font(.subheadline)
                            .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
    }

    private var topPlacesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最佳推荐")
                .font(.headline)
                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))

            if viewModel.topPlaces.isEmpty {
                Text("本月暂无打卡记录")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.topPlaces.indices, id: \.self) { index in
                    let place = viewModel.topPlaces[index]
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(index < 3 ? Color(red: 0.76, green: 0.6, blue: 0.42) : Color.gray)
                            .clipShape(Circle())

                        Text(categoryIcon(place.category))
                        VStack(alignment: .leading) {
                            Text(place.placeName)
                                .font(.subheadline)
                                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                            Text("去过\(place.visitCount)次")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(ratingLabel(place.bestRating))
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
    }

    private func categoryIcon(_ category: String) -> String { category.categoryIcon }
    private func categoryName(_ category: String) -> String { category.categoryDisplayName }
    private func ratingLabel(_ rating: Int) -> String { .ratingLabel(rating) }
}

struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
