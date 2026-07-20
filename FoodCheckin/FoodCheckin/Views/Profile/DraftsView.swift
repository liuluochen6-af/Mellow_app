import SwiftUI

struct DraftsView: View {
    @State private var drafts: [CheckInDraft] = []
    @State private var showClearConfirm = false
    @EnvironmentObject var authService: AuthService

    var body: some View {
        List {
            if drafts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("没有草稿")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(drafts) { draft in
                    HStack {
                        if let image = DraftStore.getDraftImage(fileName: draft.imageFileName) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipped()
                                .cornerRadius(8)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.data.placeName)
                                .font(.subheadline)
                                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                            Text(draft.createdAt, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        DraftStore.deleteDraft(id: drafts[index].id)
                    }
                    drafts = DraftStore.loadDrafts()
                }
            }
        }
        .navigationTitle("草稿箱")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !drafts.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清空") {
                        showClearConfirm = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .alert("清空草稿箱", isPresented: $showClearConfirm) {
            Button("清空", role: .destructive) {
                DraftStore.deleteAllDrafts()
                drafts = []
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除所有草稿吗？此操作不可恢复。")
        }
        .onAppear { drafts = DraftStore.loadDrafts() }
    }
}
