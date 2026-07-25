import SwiftUI

struct FriendRequestsView: View {
    @ObservedObject var socialService: SocialService

    var body: some View {
        List {
            if socialService.friendRequests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("没有待处理的请求")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(socialService.friendRequests) { request in
                    HStack {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(request.nickname.prefix(1)))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            )

                        Text(request.nickname)
                            .foregroundColor(.primary)

                        Spacer()

                        Button("接受") {
                            Task { await socialService.acceptFriendRequest(requestId: request.id) }
                        }
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black)
                        .cornerRadius(12)

                        Button("拒绝") {
                            Task { await socialService.rejectFriendRequest(requestId: request.id) }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("好友请求")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await socialService.loadFriendRequests()
            await socialService.markAllRead()
        }
    }
}
