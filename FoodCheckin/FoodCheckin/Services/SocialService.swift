import Foundation

struct FeedItem: Codable, Identifiable {
    let id: String
    let userId: String
    let userNickname: String
    let userAvatar: String?
    let photoUrl: String
    let placeName: String
    let address: String
    let category: String
    let rating: Int
    let tags: [String]
    let note: String?
    let amount: Double?
    let amountType: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, address, category, rating, tags, note, amount
        case userId = "user_id"
        case userNickname = "user_nickname"
        case userAvatar = "user_avatar"
        case photoUrl = "photo_url"
        case placeName = "place_name"
        case amountType = "amount_type"
        case createdAt = "created_at"
    }
}

struct FeedResponse: Codable {
    let items: [FeedItem]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct FriendInfo: Codable, Identifiable {
    let id: String
    let nickname: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, nickname
        case avatarUrl = "avatar_url"
    }
}

struct FriendRequest: Codable, Identifiable {
    let id: String
    let userId: String
    let nickname: String
    let avatarUrl: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, nickname
        case userId = "user_id"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

struct CommentItem: Codable, Identifiable {
    let id: String
    let userId: String
    let userNickname: String
    let userAvatar: String?
    let content: String
    let mentionedUserIds: [String]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, content
        case userId = "user_id"
        case userNickname = "user_nickname"
        case userAvatar = "user_avatar"
        case mentionedUserIds = "mentioned_user_ids"
        case createdAt = "created_at"
    }
}

@MainActor
class SocialService: ObservableObject {
    @Published var feedItems: [FeedItem] = []
    @Published var friends: [FriendInfo] = []
    @Published var friendRequests: [FriendRequest] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var nextCursor: String?

    func loadFeed(refresh: Bool = false) async {
        if refresh { nextCursor = nil }
        isLoading = true
        defer { isLoading = false }

        var path = "/api/social/feed?limit=20"
        if let cursor = nextCursor, !refresh {
            path += "&cursor=\(cursor)"
        }

        do {
            let data = try await APIClient.shared.get(path)
            let response = try JSONDecoder().decode(FeedResponse.self, from: data)
            if refresh {
                feedItems = response.items
            } else {
                feedItems.append(contentsOf: response.items)
            }
            nextCursor = response.nextCursor
        } catch {
            errorMessage = "加载动态失败"
        }
    }

    func loadFriends() async {
        do {
            let data = try await APIClient.shared.get("/api/social/friends")
            struct Resp: Codable { let friends: [FriendInfo] }
            let response = try JSONDecoder().decode(Resp.self, from: data)
            friends = response.friends
        } catch {}
    }

    func loadFriendRequests() async {
        do {
            let data = try await APIClient.shared.get("/api/social/friend-requests")
            struct Resp: Codable { let requests: [FriendRequest] }
            let response = try JSONDecoder().decode(Resp.self, from: data)
            friendRequests = response.requests
        } catch {}
    }

    func loadUnreadCount() async {
        do {
            let data = try await APIClient.shared.get("/api/social/unread-count")
            struct Resp: Codable { let count: Int }
            let response = try JSONDecoder().decode(Resp.self, from: data)
            unreadCount = response.count
        } catch {}
    }

    func searchUsers(query: String) async -> [FriendInfo] {
        do {
            let data = try await APIClient.shared.get("/api/social/search-user?query=\(query)")
            struct Resp: Codable { let users: [FriendInfo] }
            let response = try JSONDecoder().decode(Resp.self, from: data)
            return response.users
        } catch {
            return []
        }
    }

    func sendFriendRequest(userId: String) async -> Bool {
        do {
            _ = try await APIClient.shared.post("/api/social/friend-request?friend_id=\(userId)", body: EmptyBody())
            return true
        } catch {
            errorMessage = "发送失败"
            return false
        }
    }

    func acceptFriendRequest(requestId: String) async -> Bool {
        do {
            _ = try await APIClient.shared.post("/api/social/accept-friend?request_id=\(requestId)", body: EmptyBody())
            friendRequests.removeAll { $0.id == requestId }
            await loadFriends()
            return true
        } catch {
            return false
        }
    }

    func rejectFriendRequest(requestId: String) async -> Bool {
        do {
            _ = try await APIClient.shared.post("/api/social/reject-friend?request_id=\(requestId)", body: EmptyBody())
            friendRequests.removeAll { $0.id == requestId }
            return true
        } catch {
            return false
        }
    }

    func markAllRead() async {
        do {
            _ = try await APIClient.shared.post("/api/social/mark-read", body: EmptyBody())
            unreadCount = 0
        } catch {}
    }

    func loadComments(checkinId: String) async -> [CommentItem] {
        do {
            let data = try await APIClient.shared.get("/api/social/comments/\(checkinId)")
            struct Resp: Codable { let comments: [CommentItem] }
            let response = try JSONDecoder().decode(Resp.self, from: data)
            return response.comments
        } catch {
            return []
        }
    }

    func postComment(checkinId: String, content: String, mentionedIds: [String]) async -> Bool {
        let mentionStr = mentionedIds.joined(separator: ",")
        var path = "/api/social/comments/\(checkinId)?content=\(content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? content)"
        if !mentionStr.isEmpty {
            path += "&mentioned_user_ids=\(mentionStr)"
        }
        do {
            _ = try await APIClient.shared.post(path, body: EmptyBody())
            return true
        } catch {
            return false
        }
    }
}

struct EmptyBody: Codable {}
