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
                                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                            Text(authService.currentUser?.phone ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    NavigationLink(destination: EditProfileView()) {
                        Label("编辑资料", systemImage: "pencil")
                    }
                    NavigationLink(destination: FeedView()) {
                        Label("好友动态", systemImage: "bubble.left.and.bubble.right")
                    }
                    NavigationLink(destination: BookmarksView()) {
                        Label("我的收藏", systemImage: "bookmark")
                    }
                    NavigationLink(destination: SearchView()) {
                        Label("搜索记录", systemImage: "magnifyingglass")
                    }
                    NavigationLink(destination: FriendsListView()) {
                        Label("好友管理", systemImage: "person.2")
                    }
                    NavigationLink(destination: DraftsView()) {
                        Label("草稿箱", systemImage: "doc")
                    }
                }

                Section {
                    NavigationLink(destination: AboutView()) {
                        Label("关于", systemImage: "info.circle")
                    }
                }

                Section {
                    Button("退出登录") {
                        authService.logout()
                    }
                    .foregroundColor(.orange)

                    Button("删除账号") {
                        showDeleteConfirm = true
                    }
                    .foregroundColor(.red)
                }
            }
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
            .fill(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.3))
            .overlay(
                Text(String((authService.currentUser?.nickname ?? "用").prefix(1)))
                    .font(.title2.bold())
                    .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
            )
    }
}
