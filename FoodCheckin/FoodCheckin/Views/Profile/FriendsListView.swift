import SwiftUI

struct FriendsListView: View {
    @StateObject private var socialService = SocialService()

    var body: some View {
        List {
            if socialService.friends.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("还没有好友")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(socialService.friends) { friend in
                    HStack {
                        Circle()
                            .fill(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.3))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String(friend.nickname.prefix(1)))
                                    .font(.caption.bold())
                                    .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                            )
                        Text(friend.nickname)
                            .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                    }
                }
            }
        }
        .navigationTitle("好友管理")
        .navigationBarTitleDisplayMode(.inline)
        .task { await socialService.loadFriends() }
    }
}
