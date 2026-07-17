import SwiftUI
import PhotosUI

struct NewCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var checkInService: CheckInService

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var data = CheckInData()
    @State private var selectedPlace: SelectedPlace?
    @State private var showLocationSearch = false
    @State private var tagInput = ""
    @State private var amountText = ""
    @State private var isPublishing = false
    @State private var showShareAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    photoSection
                    locationSection

                    VStack(alignment: .leading, spacing: 8) {
                        Text("类别").font(.headline)
                        CategoryPickerView(selected: $data.category)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("评分").font(.headline)
                        RatingView(rating: $data.rating)
                    }

                    tagsSection

                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注").font(.headline)
                        TextField("写点什么...", text: Binding(
                            get: { data.note ?? "" },
                            set: { data.note = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    amountSection

                    Toggle("公开（好友可见）", isOn: $data.isPublic)
                        .tint(Color(red: 0.76, green: 0.6, blue: 0.42))
                }
                .padding()
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentMargins(.bottom, 20, for: .scrollContent)
            .background(Color(red: 0.98, green: 0.96, blue: 0.93))
            .navigationTitle("打卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") { publish() }
                        .disabled(!canPublish || isPublishing)
                }
            }
            .sheet(isPresented: $showLocationSearch) {
                LocationSearchView(selectedPlace: $selectedPlace)
            }
            .onChange(of: selectedPlace) { _, place in
                if let place {
                    data.placeName = place.name
                    data.placeId = place.placeId
                    data.address = place.address
                    data.latitude = place.latitude
                    data.longitude = place.longitude
                    data.country = place.country
                    data.province = place.province
                    data.city = place.city
                    data.district = place.district
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let photoData = try? await item?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: photoData) {
                        image = uiImage
                    }
                }
            }
            .alert("打卡成功！是否分享？", isPresented: $showShareAlert) {
                Button("分享") {
                    shareCheckIn()
                }
                Button("不了", role: .cancel) {
                    dismiss()
                }
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("照片").font(.headline)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(12)
                    .onTapGesture { selectedPhoto = nil; self.image = nil }
            } else {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                            .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                        Text("选择照片")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("地点").font(.headline)
            Button {
                showLocationSearch = true
            } label: {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                    if data.placeName.isEmpty {
                        Text("选择地点")
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading) {
                            Text(data.placeName)
                                .foregroundColor(.primary)
                            Text(data.address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签").font(.headline)
            HStack {
                TextField("添加标签", text: $tagInput)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .onSubmit { addTag() }

                Button("添加") { addTag() }
                    .disabled(tagInput.isEmpty)
            }
            if !data.tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(data.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.caption)
                                .onTapGesture {
                                    tagInput = tag
                                    data.tags.removeAll { $0 == tag }
                                }
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    data.tags.removeAll { $0 == tag }
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(Color(red: 0.76, green: 0.6, blue: 0.42))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.76, green: 0.6, blue: 0.42).opacity(0.2))
                        .cornerRadius(16)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: data.tags)
            }
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("消费金额（可选）").font(.headline)
            HStack {
                TextField("¥", text: $amountText)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .onChange(of: amountText) { _, val in
                        data.amount = Double(val)
                    }

                Picker("", selection: Binding(
                    get: { data.amountType ?? .perPerson },
                    set: { data.amountType = $0 }
                )) {
                    Text("人均").tag(AmountType.perPerson)
                    Text("总计").tag(AmountType.total)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
    }

    private var canPublish: Bool {
        image != nil && !data.placeName.isEmpty && data.rating > 0
    }

    private func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces)
        if !tag.isEmpty && !data.tags.contains(tag) {
            data.tags.append(tag)
        }
        tagInput = ""
    }

    private func publish() {
        guard let image else { return }
        isPublishing = true
        Task {
            let success = await checkInService.publish(data: data, image: image)
            isPublishing = false
            if success {
                showShareAlert = true
            } else {
                DraftStore.saveDraft(data: data, image: image)
            }
        }
    }

    private func shareCheckIn() {
        let ratingText = String(repeating: "⭐️", count: data.rating)
        let cardImage = ShareHelper.renderShareCard(
            placeName: data.placeName,
            category: data.category.displayName,
            rating: ratingText,
            photo: image,
            date: Date()
        )
        if let cardImage {
            ShareHelper.shareImage(cardImage)
        }
        dismiss()
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
