import SwiftUI

struct PinMarkerView: View {
    let pin: MapPin
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Photo thumbnail with category badge
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: URL(string: APIClient.shared.baseURL + pin.photoUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color(.systemGray5)
                        .overlay(
                            Text(categoryIcon)
                                .font(.system(size: isSelected ? 16 : 12))
                        )
                }
                .frame(width: isSelected ? 44 : 32, height: isSelected ? 44 : 32)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            isSelected ? Color.black : Color.white,
                            lineWidth: isSelected ? 3 : 2
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)

                // Category badge
                Text(categoryIcon)
                    .font(.system(size: 10))
                    .padding(2)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 1)
                    .offset(x: 2, y: 2)
            }

            // Pin triangle
            Image(systemName: "triangle.fill")
                .font(.system(size: 6))
                .foregroundColor(isSelected ? Color.black : .white)
                .rotationEffect(.degrees(180))
                .offset(y: -2)
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }

    private var categoryIcon: String { pin.category.categoryIcon }
}
