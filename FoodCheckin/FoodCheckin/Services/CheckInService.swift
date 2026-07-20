import Foundation
import SwiftUI
import UIKit

extension Notification.Name {
    static let checkInDidPublish = Notification.Name("checkInDidPublish")
}

@MainActor
class CheckInService: ObservableObject {
    @Published var myCheckIns: [CheckInResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func publish(data: CheckInData, image: UIImage) async -> Bool {
        guard let photoData = image.jpegData(compressionQuality: 0.7) else {
            errorMessage = "图片处理失败"
            return false
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data.serverJSON) else {
            errorMessage = "数据序列化失败"
            return false
        }

        do {
            let responseData = try await APIClient.shared.uploadCheckIn(photoData: photoData, jsonData: jsonData)
            let response = try JSONDecoder().decode(CheckInResponse.self, from: responseData)
            myCheckIns.insert(response, at: 0)
            NotificationCenter.default.post(name: .checkInDidPublish, object: nil)
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "发布失败，请重试"
            return false
        }
    }

    func loadMyCheckIns(cursor: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        var path = "/api/checkins/mine?limit=20"
        if let cursor { path += "&cursor=\(cursor)" }

        do {
            let data = try await APIClient.shared.get(path)
            let response = try JSONDecoder().decode(CheckInListResponse.self, from: data)
            if cursor == nil {
                myCheckIns = response.items
            } else {
                myCheckIns.append(contentsOf: response.items)
            }
        } catch {
            errorMessage = "加载失败"
        }
    }

    func delete(id: UUID) async -> Bool {
        do {
            _ = try await APIClient.shared.delete("/api/checkins/\(id.uuidString)")
            myCheckIns.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = "删除失败"
            return false
        }
    }
}
