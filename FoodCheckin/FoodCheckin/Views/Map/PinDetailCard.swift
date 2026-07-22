import SwiftUI

struct PinDetailCard: View {
    let pin: MapPin

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: APIClient.shared.baseURL + pin.photoUrl)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.3)
            }
            .frame(width: 60, height: 60)
            .clipped()
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(pin.placeName)
                    .font(.subheadline.bold())
                    .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
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
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private var categoryIcon: String { pin.category.categoryIcon }
    private var ratingLabel: String { .ratingLabel(pin.rating) }
}
