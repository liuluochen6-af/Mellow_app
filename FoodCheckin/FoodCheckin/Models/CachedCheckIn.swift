import Foundation
import SwiftData

@Model
class CachedCheckIn {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var photoUrl: String
    var placeName: String
    var placeId: String?
    var address: String
    var latitude: Double
    var longitude: Double
    var country: String
    var province: String
    var city: String
    var district: String
    var category: String
    var rating: Int
    var tags: [String]
    var note: String?
    var isPublic: Bool
    var amount: Double?
    var amountType: String?
    var createdAt: Date

    init(from response: CheckInResponse) {
        self.id = response.id
        self.userId = response.userId
        self.photoUrl = response.photoUrl
        self.placeName = response.placeName
        self.placeId = response.placeId
        self.address = response.address
        self.latitude = response.latitude
        self.longitude = response.longitude
        self.country = response.country
        self.province = response.province
        self.city = response.city
        self.district = response.district
        self.category = response.category
        self.rating = response.rating
        self.tags = response.tags
        self.note = response.note
        self.isPublic = response.isPublic
        self.amount = response.amount
        self.amountType = response.amountType
        self.createdAt = DateParsing.parse(response.createdAt) ?? Date()
    }
}
