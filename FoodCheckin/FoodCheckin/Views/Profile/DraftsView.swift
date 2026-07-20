import SwiftUI

struct DraftsView: View {
    @State private var drafts: [CheckInDraft] = []
    @State private var showClearConfirm = false
    @State private var publishingIds: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var showError = false
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var checkInService: CheckInService

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

                        Button {
                            Task { await publishDraft(draft) }
                        } label: {
                            if publishingIds.contains(draft.id) {
                                ProgressView()
                                    .frame(width: 60)
                            } else {
                                Text("发布")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(red: 0.76, green: 0.6, blue: 0.42))
                                    .cornerRadius(14)
                            }
                        }
                        .disabled(publishingIds.contains(draft.id))
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
        .alert("发布失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "网络错误，请稍后重试")
        }
        .onAppear { drafts = DraftStore.loadDrafts() }
    }

    private func publishDraft(_ draft: CheckInDraft) async {
        guard let image = DraftStore.getDraftImage(fileName: draft.imageFileName) else {
            errorMessage = "草稿图片丢失"
            showError = true
            return
        }
        publishingIds.insert(draft.id)
        let success = await checkInService.publish(data: draft.data, image: image)
        publishingIds.remove(draft.id)
        if success {
            DraftStore.deleteDraft(id: draft.id)
            drafts = DraftStore.loadDrafts()
        } else {
            errorMessage = checkInService.errorMessage
            showError = true
        }
    }
}
