import Foundation
import SwiftData

@Model
final class Pack {
    var id: UUID
    var title: String
    var createdAt: Date
    var lastAccessedAt: Date?
    var accentIndex: Int?

    @Relationship(deleteRule: .cascade, inverse: \Verse.pack)
    var verses: [Verse] = []

    init(
        title: String,
        id: UUID = UUID(),
        createdAt: Date = Date(),
        lastAccessedAt: Date? = nil,
        accentIndex: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.accentIndex = accentIndex
    }
}

extension Pack: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Pack, rhs: Pack) -> Bool { lhs.id == rhs.id }
}
