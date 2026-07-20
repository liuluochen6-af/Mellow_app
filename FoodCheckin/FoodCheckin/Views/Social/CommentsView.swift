import SwiftUI

struct CommentsView: View {
    let checkinId: String
    @ObservedObject var socialService: SocialService
    @State private var comments: [CommentItem] = []
    @State private var newComment = ""
    @State private var mentionedIds: [String] = []
    @State private var showMentionPicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if comments.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("还没有评论")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(comments) { comment in
                                CommentRow(comment: comment)
                            }
                        }
                        .padding()
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    Button { showMentionPicker = true } label: {
                        Image(systemName: "at")
                            .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                    }

                    TextField("写评论...", text: $newComment)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)

                    Button {
                        Task { await sendComment() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(
                                newComment.isEmpty ? .secondary : Color(red: 0.76, green: 0.6, blue: 0.42)
                            )
                    }
                    .disabled(newComment.isEmpty)
                }
                .padding()
            }
            .navigationTitle("评论")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showMentionPicker) {
                MentionPickerView(friends: socialService.friends, selectedIds: $mentionedIds)
            }
            .task {
                comments = await socialService.loadComments(checkinId: checkinId)
            }
        }
    }

    private func sendComment() async {
        let content = newComment
        newComment = ""
        let success = await socialService.postComment(checkinId: checkinId, content: content, mentionedIds: mentionedIds)
        if success {
            mentionedIds = []
            comments = await socialService.loadComments(checkinId: checkinId)
        }
    }
}

struct CommentRow: View {
    let comment: CommentItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.3))
                .frame(width: 30, height: 30)
                .overlay(
                    Text(String(comment.userNickname.prefix(1)))
                        .font(.caption2.bold())
                        .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.userNickname)
                        .font(.caption.bold())
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                    Spacer()
                    Text(formatDate(comment.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(comment.content)
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
            }
        }
    }

    private func formatDate(_ iso: String) -> String {
        guard let date = DateParsing.parse(iso) else { return "" }
        let rel = RelativeDateTimeFormatter()
        rel.locale = Locale(identifier: "zh_CN")
        return rel.localizedString(for: date, relativeTo: Date())
    }
}
