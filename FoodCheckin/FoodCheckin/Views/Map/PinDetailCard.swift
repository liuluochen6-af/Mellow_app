import SwiftUI

struct PinDetailCard: View {
    let pin: MapPin

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: URL(string: APIClient.shared.baseURL + pin.photoUrl)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color(.systemGray5)
            }
            .frame(width: 60, height: 60)
            .clipped()
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(pin.placeName)
                    .font(.subheadline.bold())
                    .foregroundColor(Color.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(categoryIcon)
                    Text(ratingLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    private var categoryIcon: String { pin.category.categoryIcon }
    private var ratingLabel: String { .ratingLabel(pin.rating) }
}
