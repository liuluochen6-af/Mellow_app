import SwiftUI

struct FeedCardView: View {
    let item: FeedItem
    @ObservedObject var socialService: SocialService
    @State private var showComments = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.3))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(item.userNickname.prefix(1)))
                            .font(.caption.bold())
                            .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.userNickname)
                        .font(.subheadline.bold())
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                    Text(formatDate(item.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(categoryIcon(item.category))
                    .font(.title3)
            }

            AsyncImage(url: URL(string: APIClient.shared.baseURL + item.photoUrl)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipped()
            .cornerRadius(12)

            HStack {
                Text(item.placeName)
                    .font(.subheadline.bold())
                    .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                Spacer()
                Text(ratingLabel(item.rating))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ratingColor(item.rating).opacity(0.2))
                    .cornerRadius(8)
            }

            if let note = item.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if !item.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(item.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }

            if let amount = item.amount {
                HStack(spacing: 4) {
                    Image(systemName: "yensign.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f", amount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.amountType == "per_person" ? "人均" : "总计")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Button { showComments = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.caption)
                    Text("评论")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .sheet(isPresented: $showComments) {
            CommentsView(checkinId: item.id, socialService: socialService)
        }
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "food": return "\u{1F37D}\u{FE0F}"
        case "drink": return "\u{2615}"
        case "entertainment": return "\u{1F3AE}"
        case "shopping": return "\u{1F6CD}\u{FE0F}"
        case "scenic": return "\u{1F3D6}\u{FE0F}"
        default: return "\u{1F4CC}"
        }
    }

    private func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 4: return "夯\u{1F525}"
        case 3: return "不错\u{1F44D}"
        case 2: return "一般\u{1F610}"
        case 1: return "拉\u{1F4A9}"
        default: return ""
        }
    }

    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 4: return .red
        case 3: return .green
        case 2: return .orange
        case 1: return .gray
        default: return .gray
        }
    }

    private func formatDate(_ iso: String) -> String {
        guard let date = DateParsing.parse(iso) else { return iso }
        let rel = RelativeDateTimeFormatter()
        rel.locale = Locale(identifier: "zh_CN")
        return rel.localizedString(for: date, relativeTo: Date())
    }
}
