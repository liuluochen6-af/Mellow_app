import SwiftUI

struct ShareHelper {
    @MainActor
    static func shareImage(_ image: UIImage) {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        // Find the topmost presented controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        activityVC.popoverPresentationController?.sourceView = topVC.view
        topVC.present(activityVC, animated: true)
    }

    @MainActor
    static func renderShareCard(placeName: String, category: String, rating: String, photo: UIImage?, date: Date) -> UIImage? {
        let view = ShareCardView(placeName: placeName, category: category, rating: rating, photo: photo, date: date)
        let controller = UIHostingController(rootView: view)
        let size = controller.sizeThatFits(in: CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude))
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}
