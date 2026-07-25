import SwiftUI

struct BookmarksView: View {
    @StateObject private var socialService = SocialService()
    @State private var bookmarks: [BookmarkItem] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if bookmarks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("还没有收藏")
                        .foregroundColor(.secondary)
                    Text("在好友动态中收藏感兴趣的店铺")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(bookmarks) { item in
                    BookmarkRow(item: item)
                }
                .listStyle(.plain)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("我的收藏")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            bookmarks = await socialService.loadBookmarks()
            isLoading = false
        }
    }
}

struct BookmarkRow: View {
    let item: BookmarkItem

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: APIClient.shared.baseURL + item.photoUrl)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.1)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(item.category.categoryIcon)
                    Text(item.placeName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                Text(item.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(String.ratingLabel(item.rating))
                        .font(.caption)
                    Text("来自 \(item.userNickname)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
