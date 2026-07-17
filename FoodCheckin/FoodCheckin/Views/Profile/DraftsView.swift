import SwiftUI

struct DraftsView: View {
    @State private var drafts: [CheckInDraft] = []
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
        .onAppear { drafts = DraftStore.loadDrafts() }
    }
}
