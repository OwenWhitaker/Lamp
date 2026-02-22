import UserNotifications

struct NotificationManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func scheduleReminder(_ reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = "Lamp"
        content.body = reminder.title
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: reminder.scheduledTime)

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
