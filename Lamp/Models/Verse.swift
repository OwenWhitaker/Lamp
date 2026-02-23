import Foundation
import SwiftData

@Model
final class Verse {
    var id: UUID
    var reference: String
    var text: String
    var order: Int
    var createdAt: Date = Date()
    var lastReviewed: Date?
    var memoryHealth: Double?
    // Legacy per-verse history retained for backward compatibility and migration fallback.
    @Relationship(deleteRule: .cascade, inverse: \ReviewEvent.verse)
    var reviewEvents: [ReviewEvent] = []

    var pack: Pack?

    init(
        reference: String,
        text: String,
        order: Int,
        id: UUID = UUID(),
        createdAt: Date = Date(),
        lastReviewed: Date? = nil,
        memoryHealth: Double? = nil
    ) {
        self.id = id
        self.reference = reference
        self.text = text
        self.order = order
        self.createdAt = createdAt
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

    func logReview(at reviewedAt: Date = Date(), calendar: Calendar = .current, in context: ModelContext? = nil) {
        lastReviewed = reviewedAt
        let day = calendar.startOfDay(for: reviewedAt)
        let alreadyLogged = reviewEvents.contains { calendar.isDate($0.reviewedAt, inSameDayAs: day) }
        if !alreadyLogged {
            reviewEvents.append(ReviewEvent(reviewedAt: day))
        }
        if let context {
            ReviewLocalStore.logReviewRecord(for: self, at: reviewedAt, calendar: calendar, in: context)
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

@Model
final class ReviewRecord {
    var id: UUID
    var reviewedAt: Date
    var reviewDay: Date
    var verseID: UUID
    var verseReference: String
    var verseCreatedAt: Date
    var packID: UUID?
    var packTitle: String?
    var packCreatedAt: Date?

    init(
        reviewedAt: Date,
        reviewDay: Date,
        verseID: UUID,
        verseReference: String,
        verseCreatedAt: Date,
        packID: UUID?,
        packTitle: String?,
        packCreatedAt: Date?,
        id: UUID = UUID()
    ) {
        self.id = id
        self.reviewedAt = reviewedAt
        self.reviewDay = reviewDay
        self.verseID = verseID
        self.verseReference = verseReference
        self.verseCreatedAt = verseCreatedAt
        self.packID = packID
        self.packTitle = packTitle
        self.packCreatedAt = packCreatedAt
    }
}

enum ReviewLocalStore {
    static func logReviewRecord(for verse: Verse, at reviewedAt: Date = Date(), calendar: Calendar = .current, in context: ModelContext) {
        let day = calendar.startOfDay(for: reviewedAt)
        let record = ReviewRecord(
            reviewedAt: reviewedAt,
            reviewDay: day,
            verseID: verse.id,
            verseReference: verse.reference,
            verseCreatedAt: verse.createdAt,
            packID: verse.pack?.id,
            packTitle: verse.pack?.title,
            packCreatedAt: verse.pack?.createdAt
        )
        context.insert(record)
    }
}
