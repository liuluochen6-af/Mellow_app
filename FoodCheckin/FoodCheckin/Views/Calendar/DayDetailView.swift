import SwiftUI

struct DayDetailView: View {
    let day: Int
    let month: Int
    let checkIns: [CheckInResponse]
    @State private var selectedCheckIn: CheckInResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(month)月\(day)日 · \(checkIns.count)次打卡")
                .font(.subheadline.bold())
                .foregroundColor(.primary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(checkIns) { checkIn in
                        VStack(alignment: .leading, spacing: 4) {
                            CachedAsyncImage(url: URL(string: APIClient.shared.baseURL + checkIn.photoUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 100, height: 80)
                            .clipped()
                            .cornerRadius(8)

                            Text(checkIn.placeName)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundColor(.primary)

                            HStack(spacing: 2) {
                                Text(categoryIcon(checkIn.category))
                                    .font(.caption2)
                                Text(ratingLabel(checkIn.rating))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 100)
                        .onTapGesture {
                            selectedCheckIn = checkIn
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
        .padding(.horizontal)
        .sheet(item: $selectedCheckIn) { checkIn in
            CheckInDetailSheet(checkIn: checkIn)
        }
    }

    private func categoryIcon(_ category: String) -> String { category.categoryIcon }
    private func ratingLabel(_ rating: Int) -> String { .ratingLabel(rating) }
}

struct CheckInDetailSheet: View {
    let checkIn: CheckInResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CachedAsyncImage(url: URL(string: APIClient.shared.baseURL + checkIn.photoUrl)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                            .frame(height: 250)
                    }
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(checkIn.placeName)
                            .font(.title2.bold())
                            .foregroundColor(.primary)

                        if !checkIn.address.isEmpty {
                            Label(checkIn.address, systemImage: "mappin.circle")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 8) {
                            Text(categoryIcon(checkIn.category))
                            Text(ratingLabel(checkIn.rating))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if !checkIn.tags.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(checkIn.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                            }
                        }

                        if let note = checkIn.note, !note.isEmpty {
                            Text(note)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(.top, 4)
                        }

                        if let amount = checkIn.amount {
                            let typeLabel = checkIn.amountType == "per_person" ? "/人" : "总计"
                            Text("¥\(String(format: "%.0f", amount)) \(typeLabel)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("打卡详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func categoryIcon(_ category: String) -> String { category.categoryIcon }
    private func ratingLabel(_ rating: Int) -> String { .ratingLabel(rating) }
}
