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
    var notes: String
    var urlString: String
    var scheduledTime: Date
    var repeatFrequency: RepeatFrequency
    var isEnabled: Bool
    var isDateEnabled: Bool
    var isTimeEnabled: Bool
    var isUrgent: Bool
    var createdAt: Date
    var notificationID: String

    var pack: Pack?
    var verse: Verse?

    init(
        title: String,
        notes: String = "",
        urlString: String = "",
        scheduledTime: Date,
        repeatFrequency: RepeatFrequency = .daily,
        isEnabled: Bool = true,
        isDateEnabled: Bool = true,
        isTimeEnabled: Bool = true,
        isUrgent: Bool = false,
        id: UUID = UUID(),
        createdAt: Date = Date(),
        pack: Pack? = nil,
        verse: Verse? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.urlString = urlString
        self.scheduledTime = scheduledTime
        self.repeatFrequency = repeatFrequency
        self.isEnabled = isEnabled
        self.isDateEnabled = isDateEnabled
        self.isTimeEnabled = isTimeEnabled
        self.isUrgent = isUrgent
        self.createdAt = createdAt
        self.notificationID = id.uuidString
        self.pack = pack
        self.verse = verse
    }
}
