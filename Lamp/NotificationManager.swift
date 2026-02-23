import UserNotifications

struct NotificationManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func scheduleReminder(_ reminder: Reminder) {
        guard reminder.isEnabled, reminder.isDateEnabled else {
            cancelReminder(reminder)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Lamp"
        content.body = reminder.title
        if !reminder.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content.subtitle = reminder.notes
        }
        if reminder.isUrgent {
            content.interruptionLevel = .timeSensitive
        }
        content.sound = .default

        var components = Calendar.current.dateComponents([.hour, .minute], from: reminder.scheduledTime)
        if !reminder.isTimeEnabled {
            components.hour = 9
            components.minute = 0
        }

        let trigger: UNNotificationTrigger
        switch reminder.repeatFrequency {
        case .daily:
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case .weekly:
            var weeklyComponents = components
            weeklyComponents.weekday = Calendar.current.component(.weekday, from: reminder.scheduledTime)
            trigger = UNCalendarNotificationTrigger(dateMatching: weeklyComponents, repeats: true)
        case .none:
            let fullComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.scheduledTime)
            trigger = UNCalendarNotificationTrigger(dateMatching: fullComponents, repeats: false)
        }

        let request = UNNotificationRequest(identifier: reminder.notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelReminder(_ reminder: Reminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.notificationID])
    }
}
