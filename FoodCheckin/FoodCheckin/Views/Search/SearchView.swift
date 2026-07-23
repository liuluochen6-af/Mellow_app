import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [CheckInResponse] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索店铺、地点、标签...", text: $query)
                        .autocorrectionDisabled()
                        .onSubmit { doSearch() }
                    if !query.isEmpty {
                        Button { query = ""; results = []; hasSearched = false; errorMessage = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    Button { doSearch() } label: {
                        Text("搜索")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.76, green: 0.6, blue: 0.42))
                            .cornerRadius(8)
                    }
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)

                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange.opacity(0.7))
                        Text(error)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    Spacer()
                } else if results.isEmpty && hasSearched {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("没有找到相关记录")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if !results.isEmpty {
                    List(results) { checkIn in
                        SearchResultRow(checkIn: checkIn)
                    }
                    .listStyle(.plain)
                } else {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.3))
                        Text("搜索店名、地址、标签、备注")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    Spacer()
                }
            }
            .background(Color(red: 0.98, green: 0.96, blue: 0.93).ignoresSafeArea())
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func doSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task { await search() }
    }

    private func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        errorMessage = nil
        hasSearched = true
        defer { isLoading = false }
        do {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let data = try await APIClient.shared.get("/api/checkins/search?q=\(encoded)")
            let response = try JSONDecoder().decode(CheckInListResponse.self, from: data)
            results = response.items
        } catch {
            results = []
            errorMessage = "搜索失败: \(error.localizedDescription)"
        }
    }
}

struct SearchResultRow: View {
    let checkIn: CheckInResponse

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: APIClient.shared.baseURL + checkIn.photoUrl)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.1)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(checkIn.category.categoryIcon)
                    Text(checkIn.placeName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                        .lineLimit(1)
                }
                Text(checkIn.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(String.ratingLabel(checkIn.rating))
                        .font(.caption)
                    if !checkIn.tags.isEmpty {
                        Text(checkIn.tags.joined(separator: " "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
