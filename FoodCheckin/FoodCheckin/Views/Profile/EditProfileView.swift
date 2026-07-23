import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var nickname: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var isSaving = false
    @State private var showError = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            if let avatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else if let url = authService.currentUser?.avatarUrl,
                                      !url.isEmpty,
                                      let fullURL = URL(string: APIClient.shared.baseURL + url) {
                                AsyncImage(url: fullURL) { image in
                                    image.resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle()
                                        .fill(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.3))
                                        .frame(width: 80, height: 80)
                                        .overlay(ProgressView())
                                }
                            } else {
                                Circle()
                                    .fill(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.3))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(String((authService.currentUser?.nickname ?? "用").prefix(1)))
                                            .font(.title.bold())
                                            .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                                    )
                            }
                        }
                        Text("点击更换头像")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }

            Section("昵称") {
                TextField("输入昵称", text: $nickname)
            }

            Section {
                Button {
                    Task { await saveProfile() }
                } label: {
                    HStack {
                        Spacer()
                        Text(isSaving ? "保存中..." : "保存")
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
                .listRowBackground(Color(red: 0.76, green: 0.6, blue: 0.42))
                .disabled(nickname.isEmpty || isSaving)
            }
        }
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            nickname = authService.currentUser?.nickname ?? ""
        }
        .onChange(of: selectedPhoto) { _, item in
            Task { @MainActor in
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    avatarImage = image
                }
            }
        }
        .alert("保存失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(authService.errorMessage ?? "未知错误")
        }
    }

    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }
        let success = await authService.updateProfile(nickname: nickname, avatar: avatarImage)
        if success {
            dismiss()
        } else {
            showError = true
        }
    }
}
