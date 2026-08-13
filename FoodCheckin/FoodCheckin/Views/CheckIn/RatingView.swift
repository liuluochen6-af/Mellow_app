import SwiftUI
import UIKit

struct RatingView: View {
    @Binding var rating: Int

    private let levels = [
        (value: 4, label: "夯", icon: "rating-hang"),
        (value: 3, label: "不错", icon: "rating-good"),
        (value: 2, label: "一般", icon: "rating-average"),
        (value: 1, label: "拉", icon: "rating-bad"),
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(levels, id: \.value) { level in
                Button {
                    rating = level.value
                } label: {
                    VStack(spacing: 6) {
                        ratingImage(named: level.icon)
                        Text(level.label)
                            .font(.caption)
                            .foregroundColor(rating == level.value ? .white : Color.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
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

    @ViewBuilder
    private func ratingImage(named name: String) -> some View {
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 13))
        } else {
            // Keep the layout stable if a resource is accidentally omitted.
            RoundedRectangle(cornerRadius: 13)
                .fill(Color(.systemGray5))
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: "photo").foregroundColor(.secondary))
        }
    }
}
