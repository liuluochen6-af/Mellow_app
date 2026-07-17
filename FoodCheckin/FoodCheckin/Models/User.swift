import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var nickname: String
    let avatarUrl: String
    let phone: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, nickname, phone
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

struct LoginResponse: Codable {
    let token: String
    let user: UserProfile
}
