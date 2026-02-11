import Foundation
import SwiftData

@Model
final class Verse {
    var id: UUID
    var reference: String
    var text: String
    var order: Int
    var lastReviewed: Date?
    var memoryHealth: Double?

    var pack: Pack?

    init(
        reference: String,
        text: String,
        order: Int,
        id: UUID = UUID(),
        lastReviewed: Date? = nil,
        memoryHealth: Double? = nil
    ) {
        self.id = id
        self.reference = reference
        self.text = text
        self.order = order
        self.lastReviewed = lastReviewed
        self.memoryHealth = memoryHealth
    }
}

extension Verse: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Verse, rhs: Verse) -> Bool { lhs.id == rhs.id }
}
