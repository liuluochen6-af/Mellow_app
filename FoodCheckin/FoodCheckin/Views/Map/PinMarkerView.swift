import SwiftUI

struct PinMarkerView: View {
    let pin: MapPin
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text(categoryIcon)
                .font(.system(size: isSelected ? 28 : 20))
                .padding(6)
                .background(
                    Circle()
                        .fill(isSelected ? Color(red: 0.76, green: 0.6, blue: 0.42) : Color.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                )

            Image(systemName: "triangle.fill")
                .font(.system(size: 8))
                .foregroundColor(isSelected ? Color(red: 0.76, green: 0.6, blue: 0.42) : .white)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }

    private var categoryIcon: String {
        switch pin.category {
        case "food": return "🍽️"
        case "drink": return "☕"
        case "entertainment": return "🎮"
        case "shopping": return "🛍️"
        case "scenic": return "🏖️"
        default: return "📌"
        }
    }
}
