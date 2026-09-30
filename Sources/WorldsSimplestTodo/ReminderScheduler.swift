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

        let now = Date()

        do {
            let authorized = try await center.requestAuthorization(options: [.alert, .sound])
            guard authorized else { return }

            if let recurrence = item.recurrence {
                try await center.add(repeatingRequest(
                    for: item,
                    components: recurrence.dueComponents(),
                    title: "To-do reminder",
                    identifierSuffix: "recurring.due"
                ))
                try await center.add(repeatingRequest(
                    for: item,
                    components: recurrence.followUpComponents(),
                    title: "Still unfinished",
                    identifierSuffix: "recurring.follow-up"
                ))

                if reminderDate > now,
                   !recurrence.matchesScheduledTime(reminderDate) {
                    try await addOneOffPair(
                        for: item,
                        at: reminderDate,
                        identifierPrefix: "override"
                    )
                }
                return
            }

            let followUpDate = reminderDate.addingTimeInterval(10 * 60)
            guard followUpDate > now else { return }
            try await addOneOffPair(for: item, at: reminderDate, identifierPrefix: nil)
        } catch {
            // The task still exists even if notification permission is unavailable.
        }
    }

    func cancel(for item: TodoItem) {
        let requestIdentifiers = identifiers(for: item.id)
        center.removePendingNotificationRequests(withIdentifiers: requestIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: requestIdentifiers)
    }

    private func addOneOffPair(
        for item: TodoItem,
        at reminderDate: Date,
        identifierPrefix: String?
    ) async throws {
        let now = Date()
        let prefix = identifierPrefix.map { "\($0)." } ?? ""

        if reminderDate > now {
            try await center.add(request(
                for: item,
                at: reminderDate,
                title: "To-do reminder",
                identifierSuffix: "\(prefix)due"
            ))
        }

        let followUpDate = reminderDate.addingTimeInterval(10 * 60)
        if followUpDate > now {
            try await center.add(request(
                for: item,
                at: followUpDate,
                title: "Still unfinished",
                identifierSuffix: "\(prefix)follow-up"
            ))
        }
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

    private func repeatingRequest(
        for item: TodoItem,
        components: DateComponents,
        title: String,
        identifierSuffix: String
    ) -> UNNotificationRequest {
        let content = notificationContent(for: item, title: title)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        return UNNotificationRequest(
            identifier: "\(item.id.uuidString).\(identifierSuffix)",
            content: content,
            trigger: trigger
        )
    }

    private func notificationContent(
        for item: TodoItem,
        title: String
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = item.title
        content.sound = .default
        content.categoryIdentifier = ReminderNotification.category
        content.userInfo = [ReminderNotification.todoIDKey: item.id.uuidString]
        return content
    }

    private func identifiers(for id: UUID) -> [String] {
        [
            id.uuidString,
            "\(id.uuidString).due",
            "\(id.uuidString).follow-up",
            "\(id.uuidString).recurring.due",
            "\(id.uuidString).recurring.follow-up",
            "\(id.uuidString).override.due",
            "\(id.uuidString).override.follow-up"
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
