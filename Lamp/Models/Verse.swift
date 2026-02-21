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
    @Relationship(deleteRule: .cascade, inverse: \ReviewEvent.verse)
    var reviewEvents: [ReviewEvent] = []

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

    func reviewDays(calendar: Calendar = .current) -> Set<Date> {
        if !reviewEvents.isEmpty {
            return Set(reviewEvents.map { calendar.startOfDay(for: $0.reviewedAt) })
        }
        guard let lastReviewed else { return [] }
        return [calendar.startOfDay(for: lastReviewed)]
    }

    func logReview(at reviewedAt: Date = Date(), calendar: Calendar = .current) {
        lastReviewed = reviewedAt
        let day = calendar.startOfDay(for: reviewedAt)
        let alreadyLogged = reviewEvents.contains { calendar.isDate($0.reviewedAt, inSameDayAs: day) }
        if !alreadyLogged {
            reviewEvents.append(ReviewEvent(reviewedAt: day))
        }
    }
}

extension Verse: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Verse, rhs: Verse) -> Bool { lhs.id == rhs.id }
}

@Model
final class ReviewEvent {
    var id: UUID
    var reviewedAt: Date
    var verse: Verse?

    init(
        reviewedAt: Date,
        id: UUID = UUID(),
        verse: Verse? = nil
    ) {
        self.id = id
        self.reviewedAt = reviewedAt
        self.verse = verse
    }
}
