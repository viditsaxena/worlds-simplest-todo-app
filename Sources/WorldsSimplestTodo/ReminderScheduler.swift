import Foundation
import UserNotifications

enum ReminderNotification {
    static let category = "TODO_REMINDER"
    static let doneAction = "TODO_DONE"
    static let snoozeAction = "TODO_SNOOZE"
    static let todoIDKey = "todoID"

    static func registerActions() {
        let done = UNNotificationAction(
            identifier: doneAction,
            title: "Done",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: snoozeAction,
            title: "Snooze 10 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: category,
            actions: [done, snooze],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

actor ReminderScheduler {
    private let center = UNUserNotificationCenter.current()

    func schedule(for item: TodoItem) async {
        guard let reminderDate = item.reminderDate else {
            return
        }

        let followUpDate = reminderDate.addingTimeInterval(10 * 60)
        let now = Date()
        guard followUpDate > now else { return }

        do {
            let authorized = try await center.requestAuthorization(options: [.alert, .sound])
            guard authorized else { return }

            if reminderDate > now {
                let dueRequest = request(
                    for: item,
                    at: reminderDate,
                    title: "To-do reminder",
                    identifierSuffix: "due"
                )
                try await center.add(dueRequest)
            }

            let followUpRequest = request(
                for: item,
                at: followUpDate,
                title: "Still unfinished",
                identifierSuffix: "follow-up"
            )
            try await center.add(followUpRequest)
        } catch {
            // The task still exists even if notification permission is unavailable.
        }
    }

    func cancel(for item: TodoItem) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: item.id))
    }

    private func request(
        for item: TodoItem,
        at date: Date,
        title: String,
        identifierSuffix: String
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = item.title
        content.sound = .default
        content.categoryIdentifier = ReminderNotification.category
        content.userInfo = [ReminderNotification.todoIDKey: item.id.uuidString]

        var components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        components.timeZone = .current

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
        return UNNotificationRequest(
            identifier: "\(item.id.uuidString).\(identifierSuffix)",
            content: content,
            trigger: trigger
        )
    }

    private func identifiers(for id: UUID) -> [String] {
        [
            id.uuidString,
            "\(id.uuidString).due",
            "\(id.uuidString).follow-up"
        ]
    }
}

extension Notification.Name {
    static let completeTodoFromNotification = Notification.Name(
        "CompleteTodoFromNotification"
    )
    static let snoozeTodoFromNotification = Notification.Name(
        "SnoozeTodoFromNotification"
    )
}
