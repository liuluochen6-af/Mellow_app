import SwiftUI

struct ShareCardView: View {
    let placeName: String
    let category: String
    let rating: String
    let photo: UIImage?
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(placeName)
                        .font(.headline)
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                    Spacer()
                    Text(rating)
                        .font(.title3)
                }

                HStack {
                    Text(category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.2))
                        .cornerRadius(8)

                    Spacer()

                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Spacer()
                    Text("— 吃喝玩乐打卡")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(red: 0.98, green: 0.96, blue: 0.93))
        }
        .frame(width: 300)
        .cornerRadius(16)
        .shadow(radius: 4)
    }
}
