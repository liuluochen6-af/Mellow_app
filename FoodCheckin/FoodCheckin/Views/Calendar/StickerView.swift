import SwiftUI

struct StickerView: View {
    let image: UIImage
    var size: CGFloat = 60

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.15), radius: 2, x: 1, y: 1)
    }
}
