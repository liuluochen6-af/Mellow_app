import SwiftUI
import UIKit

struct DayCellView: View {
    let day: Int
    let checkIns: [CheckInResponse]
    let isToday: Bool
    let isSelected: Bool
    var stickerImage: UIImage? = nil

    var body: some View {
        ZStack {
            if let sticker = stickerImage {
                Image(uiImage: sticker)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    .opacity(0.8)
            }

            Text("\(day)")
                .font(.system(size: 15, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? .white : Color(red: 0.35, green: 0.25, blue: 0.15))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cellBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color(red: 0.76, green: 0.6, blue: 0.42) : .clear, lineWidth: 2)
        )
    }

    private var cellBackground: Color {
        if isToday {
            return Color(red: 0.76, green: 0.6, blue: 0.42)
        } else if !checkIns.isEmpty {
            return Color(.systemGray5)
        } else {
            return Color(.systemGray6)
        }
    }
}
