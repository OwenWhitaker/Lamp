import Foundation
import SwiftData

@Model
final class Pack {
    var id: UUID
    var title: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Verse.pack)
    var verses: [Verse] = []

    init(title: String, id: UUID = UUID(), createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}

extension Pack: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Pack, rhs: Pack) -> Bool { lhs.id == rhs.id }
}
