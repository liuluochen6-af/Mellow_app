import SwiftUI

struct ProfileMainView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.3))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(String((authService.currentUser?.nickname ?? "用").prefix(1)))
                                    .font(.title2.bold())
                                    .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                            )

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
                        Task { await authService.deleteAccount() }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("我的")
        }
    }
}
