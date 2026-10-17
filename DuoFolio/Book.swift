import Foundation
import SwiftUI

/// 书架里的一本书(元数据持久化到 Documents/duofolio.json)
struct Book: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var author: String
    var fileName: String
    var coverData: Data?
    var addedAt: Date
    var lastReadAt: Date?
    var position: FolioPosition?
    var spineCount: Int = 0

    var hasProgress: Bool { position != nil }

    static func == (lhs: Book, rhs: Book) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
