import Foundation
import UIKit

struct ScanDocument: Identifiable, Codable {
    let id: UUID
    var name: String
    let dateCreated: Date
    var pageCount: Int
    var fileURLs: [URL]
    var thumbnailURL: URL?

    init(id: UUID = UUID(), name: String, dateCreated: Date = Date(), pageCount: Int, fileURLs: [URL], thumbnailURL: URL? = nil) {
        self.id = id
        self.name = name
        self.dateCreated = dateCreated
        self.pageCount = pageCount
        self.fileURLs = fileURLs
        self.thumbnailURL = thumbnailURL
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: dateCreated)
    }
}
