import Foundation
import UIKit

struct CheckInDraft: Codable, Identifiable {
    let id: UUID
    let data: CheckInData
    let imageFileName: String
    let createdAt: Date

    init(data: CheckInData, imageFileName: String) {
        self.id = UUID()
        self.data = data
        self.imageFileName = imageFileName
        self.createdAt = Date()
    }
}

enum DraftStore {
    private static var draftsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("drafts.json")
    }

    private static var imagesDir: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("draft_images")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func saveDraft(data: CheckInData, image: UIImage) {
        let fileName = "\(UUID().uuidString).jpg"
        let imageURL = imagesDir.appendingPathComponent(fileName)
        if let jpegData = image.jpegData(compressionQuality: 0.7) {
            try? jpegData.write(to: imageURL)
        }

        var drafts = loadDrafts()
        drafts.append(CheckInDraft(data: data, imageFileName: fileName))

        if let encoded = try? JSONEncoder().encode(drafts) {
            try? encoded.write(to: draftsURL)
        }
    }

    static func loadDrafts() -> [CheckInDraft] {
        guard let data = try? Data(contentsOf: draftsURL),
              let drafts = try? JSONDecoder().decode([CheckInDraft].self, from: data) else {
            return []
        }
        return drafts
    }

    static func getDraftImage(fileName: String) -> UIImage? {
        let url = imagesDir.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func deleteDraft(id: UUID) {
        var drafts = loadDrafts()
        if let index = drafts.firstIndex(where: { $0.id == id }) {
            let draft = drafts[index]
            let imageURL = imagesDir.appendingPathComponent(draft.imageFileName)
            try? FileManager.default.removeItem(at: imageURL)
            drafts.remove(at: index)
            if let encoded = try? JSONEncoder().encode(drafts) {
                try? encoded.write(to: draftsURL)
            }
        }
    }

    static func deleteAllDrafts() {
        let drafts = loadDrafts()
        for draft in drafts {
            let imageURL = imagesDir.appendingPathComponent(draft.imageFileName)
            try? FileManager.default.removeItem(at: imageURL)
        }
        try? FileManager.default.removeItem(at: draftsURL)
    }
}
