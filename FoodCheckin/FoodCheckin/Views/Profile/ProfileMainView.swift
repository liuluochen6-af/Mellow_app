import SwiftUI

struct ProfileMainView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        avatarView
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authService.currentUser?.nickname ?? "用户")
                                .font(.headline)
                                .foregroundColor(.black)
                            Text(authService.currentUser?.phone ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    NavigationLink(destination: EditProfileView()) {
                        profileNavigationLabel("编辑资料", systemImage: "pencil")
                    }
                    .tint(.black)
                    NavigationLink(destination: FeedView()) {
                        profileNavigationLabel("好友动态", systemImage: "bubble.left.and.bubble.right")
                    }
                    .tint(.black)
                    NavigationLink(destination: BookmarksView()) {
                        profileNavigationLabel("我的收藏", systemImage: "bookmark")
                    }
                    .tint(.black)
                    NavigationLink(destination: SearchView()) {
                        profileNavigationLabel("搜索记录", systemImage: "magnifyingglass")
                    }
                    .tint(.black)
                    NavigationLink(destination: FriendsListView()) {
                        profileNavigationLabel("好友管理", systemImage: "person.2")
                    }
                    .tint(.black)
                    NavigationLink(destination: DraftsView()) {
                        profileNavigationLabel("草稿箱", systemImage: "doc")
                    }
                    .tint(.black)
                }

                Section {
                    NavigationLink(destination: AboutView()) {
                        profileNavigationLabel("关于", systemImage: "info.circle")
                    }
                    .tint(.black)
                }

                Section {
                    Button("删除账号") {
                        showDeleteConfirm = true
                    }
                    .foregroundColor(.red)
                }
            }
            .tint(.black)
            .accentColor(.black)
            .navigationTitle("我的")
            .task { await authService.loadProfile() }
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("删除", role: .destructive) {
                    Task { await authService.deleteAccount() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后所有数据将无法恢复，确定要删除账号吗？")
            }
        }
        .tint(.black)
        .accentColor(.black)
    }

    private func profileNavigationLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.black)
                .frame(width: 28)
            Text(title)
                .foregroundStyle(Color.black)
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let url = authService.currentUser?.avatarUrl,
           !url.isEmpty,
           let fullURL = URL(string: APIClient.shared.baseURL + url) {
            AsyncImage(url: fullURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                avatarPlaceholder
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color(.systemGray4))
            .overlay(
                Text(String((authService.currentUser?.nickname ?? "用").prefix(1)))
                    .font(.title2.bold())
                    .foregroundColor(.white)
            )
    }
}
