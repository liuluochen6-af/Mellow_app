import SwiftUI

struct CheckInDetailView: View {
    let checkInId: String
    @State private var checkIn: CheckInResponse?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let checkIn {
                    VStack(alignment: .leading, spacing: 16) {
                        AsyncImage(url: URL(string: APIClient.shared.baseURL + checkIn.photoUrl)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipped()
                        .cornerRadius(16)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(checkIn.placeName)
                                .font(.title2.bold())
                                .foregroundColor(Color.primary)

                            if !checkIn.address.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(Color.black)
                                    Text(checkIn.address)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                            HStack(spacing: 16) {
                                Label(categoryName(checkIn.category), systemImage: "tag.fill")
                                    .font(.subheadline)
                                    .foregroundColor(Color(.systemGray))

                                Label(ratingLabel(checkIn.rating), systemImage: "star.fill")
                                    .font(.subheadline)
                                    .foregroundColor(Color(.systemGray))
                            }

                            if !checkIn.tags.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(checkIn.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(16)
                                    }
                                }
                            }

                            if let note = checkIn.note, !note.isEmpty {
                                Text(note)
                                    .font(.body)
                                    .foregroundColor(Color.primary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }

                            if let amount = checkIn.amount {
                                HStack {
                                    Image(systemName: "yensign.circle.fill")
                                        .foregroundColor(Color.black)
                                    Text(String(format: "%.0f", amount))
                                        .font(.subheadline)
                                    Text(checkIn.amountType == "per_person" ? "人均" : "总计")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                Text(formatDate(checkIn.createdAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                } else {
                    Text("加载失败")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .background(Color.white)
            .navigationTitle("打卡详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .task { await loadDetail() }
    }

    private func loadDetail() async {
        do {
            let data = try await APIClient.shared.get("/api/checkins/\(checkInId)")
            checkIn = try JSONDecoder().decode(CheckInResponse.self, from: data)
        } catch {}
        isLoading = false
    }

    private func categoryName(_ cat: String) -> String { cat.categoryDisplayName }
    private func ratingLabel(_ rating: Int) -> String { .ratingLabel(rating) }

    private func formatDate(_ iso: String) -> String {
        guard let date = DateParsing.parse(iso) else { return iso }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }
}
