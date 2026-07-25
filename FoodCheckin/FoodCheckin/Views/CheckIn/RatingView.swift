import SwiftUI

struct RatingView: View {
    @Binding var rating: Int

    private let levels = [
        (value: 4, label: "夯", icon: "🔥"),
        (value: 3, label: "不错", icon: "👍"),
        (value: 2, label: "一般", icon: "😐"),
        (value: 1, label: "拉", icon: "💩"),
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(levels, id: \.value) { level in
                Button {
                    rating = level.value
                } label: {
                    VStack(spacing: 4) {
                        Text(level.icon)
                            .font(.title2)
                        Text(level.label)
                            .font(.caption)
                            .foregroundColor(rating == level.value ? .white : Color.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        rating == level.value
                            ? Color.black
                            : Color(.systemGray6)
                    )
                    .cornerRadius(12)
                }
            }
        }
    }
}
