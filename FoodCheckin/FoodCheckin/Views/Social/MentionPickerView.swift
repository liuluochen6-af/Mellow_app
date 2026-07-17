import SwiftUI

struct MentionPickerView: View {
    let friends: [FriendInfo]
    @Binding var selectedIds: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(friends) { friend in
                HStack {
                    Circle()
                        .fill(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(friend.nickname.prefix(1)))
                                .font(.caption2.bold())
                                .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                        )
                    Text(friend.nickname)
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                    Spacer()
                    if selectedIds.contains(friend.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedIds.contains(friend.id) {
                        selectedIds.removeAll { $0 == friend.id }
                    } else {
                        selectedIds.append(friend.id)
                    }
                }
            }
            .navigationTitle("@好友")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
