import SwiftUI

struct AddFriendView: View {
    @ObservedObject var socialService: SocialService
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [FriendInfo] = []
    @State private var isSearching = false
    @State private var sentRequests: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索手机号或昵称", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { Task { await search() } }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .padding()

                if isSearching {
                    ProgressView().padding()
                }

                List(searchResults) { user in
                    HStack {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(user.nickname.prefix(1)))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            )

                        Text(user.nickname)
                            .foregroundColor(.primary)

                        Spacer()

                        if sentRequests.contains(user.id) {
                            Text("已发送")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if socialService.friends.contains(where: { $0.id == user.id }) {
                            Text("已是好友")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Button("添加") {
                                Task {
                                    if await socialService.sendFriendRequest(userId: user.id) {
                                        sentRequests.insert(user.id)
                                    }
                                }
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black)
                            .cornerRadius(16)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("添加好友")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func search() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        searchResults = await socialService.searchUsers(query: searchText)
        isSearching = false
    }
}
