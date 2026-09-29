import Foundation
import UserNotifications

actor ReminderScheduler {
    private let center = UNUserNotificationCenter.current()

    func schedule(for item: TodoItem) async {
        guard let reminderDate = item.reminderDate,
              reminderDate > Date() else {
            return
        }

        do {
            let authorized = try await center.requestAuthorization(options: [.alert, .sound])
            guard authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "To-do reminder"
            content.body = item.title
            content.sound = .default

            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )
            components.timeZone = .current

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: item.id.uuidString,
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        } catch {
            // The task still exists even if notification permission is unavailable.
        }
    }

    func cancel(for item: TodoItem) {
        center.removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])
    }
}
