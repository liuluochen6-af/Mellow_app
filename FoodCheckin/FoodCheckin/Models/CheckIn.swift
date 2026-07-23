import Foundation

enum CheckInCategory: String, CaseIterable, Codable {
    case food
    case drink
    case entertainment
    case shopping
    case scenic
    case other

    var displayName: String {
        switch self {
        case .food: return "餐饮"
        case .drink: return "饮品"
        case .entertainment: return "娱乐"
        case .shopping: return "购物"
        case .scenic: return "景点"
        case .other: return "其他"
        }
    }

    var icon: String {
        switch self {
        case .food: return "🍽️"
        case .drink: return "☕"
        case .entertainment: return "🎮"
        case .shopping: return "🛍️"
        case .scenic: return "🏖️"
        case .other: return "📌"
        }
    }
}

extension String {
    var categoryIcon: String {
        CheckInCategory(rawValue: self)?.icon ?? "📌"
    }

    var categoryDisplayName: String {
        CheckInCategory(rawValue: self)?.displayName ?? "其他"
    }

    static func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 4: return "夯🔥"
        case 3: return "不错👍"
        case 2: return "一般😐"
        case 1: return "拉💩"
        default: return ""
        }
    }
}

enum AmountType: String, Codable {
    case perPerson = "per_person"
    case total = "total"
}

struct CheckInData: Codable {
    var placeName: String = ""
    var placeId: String?
    var address: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var country: String = ""
    var province: String = ""
    var city: String = ""
    var district: String = ""
    var category: CheckInCategory = .food
    var rating: Int = 0
    var tags: [String] = []
    var note: String?
    var isPublic: Bool = true
    var amount: Double?
    var amountType: AmountType?
    var createdAt: Date?

    var serverJSON: [String: Any] {
        var dict: [String: Any] = [
            "place_name": placeName,
            "address": address,
            "latitude": latitude,
            "longitude": longitude,
            "country": country,
            "province": province,
            "city": city,
            "district": district,
            "category": category.rawValue,
            "rating": rating,
            "tags": tags,
            "is_public": isPublic,
        ]
        if let placeId { dict["place_id"] = placeId }
        if let note { dict["note"] = note }
        if let amount { dict["amount"] = amount }
        if let amountType { dict["amount_type"] = amountType.rawValue }
        if let createdAt {
            let formatter = ISO8601DateFormatter()
            dict["created_at"] = formatter.string(from: createdAt)
        }
        return dict
    }
}

struct CheckInResponse: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let photoUrl: String
    let placeName: String
    let placeId: String?
    let address: String
    let latitude: Double
    let longitude: Double
    let country: String
    let province: String
    let city: String
    let district: String
    let category: String
    let rating: Int
    let tags: [String]
    let note: String?
    let isPublic: Bool
    let amount: Double?
    let amountType: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, address, latitude, longitude, country, province, city, district, category, rating, tags, note, amount
        case userId = "user_id"
        case photoUrl = "photo_url"
        case placeName = "place_name"
        case placeId = "place_id"
        case isPublic = "is_public"
        case amountType = "amount_type"
        case createdAt = "created_at"
    }
}

struct CheckInListResponse: Codable {
    let items: [CheckInResponse]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct CheckInUpdateBody: Codable {
    var rating: Int?
    var tags: [String]?
    var note: String?
    var isPublic: Bool?

    enum CodingKeys: String, CodingKey {
        case rating, tags, note
        case isPublic = "is_public"
    }
}
