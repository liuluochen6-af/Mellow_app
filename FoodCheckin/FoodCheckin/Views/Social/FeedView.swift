import SwiftUI

struct FeedView: View {
    @StateObject private var socialService = SocialService()
    @State private var showAddFriend = false

    var body: some View {
        NavigationStack {
            Group {
                if socialService.friends.isEmpty && socialService.feedItems.isEmpty && !socialService.isLoading {
                    emptyStateView
                } else {
                    feedList
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("动态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        NavigationLink(destination: FriendRequestsView(socialService: socialService)) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell")
                                if socialService.unreadCount > 0 {
                                    Text("\(socialService.unreadCount)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(3)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                        Button { showAddFriend = true } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView(socialService: socialService)
            }
            .task {
                await socialService.loadFriends()
                await socialService.loadFeed(refresh: true)
                await socialService.loadUnreadCount()
                _ = await socialService.loadBookmarks()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(.systemGray3))

            Text("还没有好友")
                .font(.title3)
                .foregroundColor(.primary)

            Text("添加好友，看看他们的探店记录吧")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                showAddFriend = true
            } label: {
                Text("添加好友")
                    .font(.body.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .cornerRadius(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(socialService.feedItems) { item in
                    FeedCardView(item: item, socialService: socialService)
                }

                if socialService.isLoading {
                    ProgressView().padding()
                }
            }
            .padding()
        }
        .refreshable {
            await socialService.loadFeed(refresh: true)
        }
    }
}
