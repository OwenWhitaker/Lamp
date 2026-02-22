import Foundation
import SwiftData

enum RepeatFrequency: String, Codable, CaseIterable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
}

@Model
final class Reminder {
    var id: UUID
    var title: String
    var scheduledTime: Date
    var repeatFrequency: RepeatFrequency
    var isEnabled: Bool
    var createdAt: Date
    var notificationID: String

    var pack: Pack?
    var verse: Verse?

    init(
        title: String,
        scheduledTime: Date,
        repeatFrequency: RepeatFrequency = .daily,
        isEnabled: Bool = true,
        id: UUID = UUID(),
        createdAt: Date = Date(),
        pack: Pack? = nil,
        verse: Verse? = nil
    ) {
        self.id = id
        self.title = title
        self.scheduledTime = scheduledTime
        self.repeatFrequency = repeatFrequency
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.notificationID = id.uuidString
        self.pack = pack
        self.verse = verse
    }
}
