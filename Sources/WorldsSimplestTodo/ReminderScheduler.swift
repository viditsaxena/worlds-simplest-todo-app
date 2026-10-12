import Foundation
import UserNotifications

protocol ReminderScheduling: Sendable {
    func schedule(for item: TodoItem) async
    func cancel(for item: TodoItem) async
    func schedule(for birthday: BirthdayItem) async
    func snooze(_ birthday: BirthdayItem, until date: Date) async
    func cancel(for birthday: BirthdayItem) async
}

enum ReminderNotification {
    static let category = "TODO_REMINDER"
    static let doneAction = "TODO_DONE"
    static let snoozeAction = "TODO_SNOOZE"
    static let todoIDKey = "todoID"
    static let birthdayCategory = "BIRTHDAY_REMINDER"
    static let birthdaySnoozeAction = "BIRTHDAY_SNOOZE"
    static let birthdayIDKey = "birthdayID"

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
        let birthdaySnooze = UNNotificationAction(
            identifier: birthdaySnoozeAction,
            title: "Snooze 10 min",
            options: []
        )
        let birthdayCategory = UNNotificationCategory(
            identifier: birthdayCategory,
            actions: [birthdaySnooze],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([
            category,
            birthdayCategory
        ])
    }
}

actor ReminderScheduler: ReminderScheduling {
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

    func cancel(for item: TodoItem) async {
        let requestIdentifiers = identifiers(for: item.id)
        center.removePendingNotificationRequests(withIdentifiers: requestIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: requestIdentifiers)
    }

    func schedule(for birthday: BirthdayItem) async {
        do {
            let authorized = try await center.requestAuthorization(options: [.alert, .sound])
            guard authorized else { return }

            let content = birthdayContent(for: birthday)
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: birthday.notificationComponents(),
                repeats: true
            )
            try await center.add(UNNotificationRequest(
                identifier: "birthday.\(birthday.id.uuidString).yearly",
                content: content,
                trigger: trigger
            ))
        } catch {
            // The birthday stays saved even if notification permission is unavailable.
        }
    }

    func snooze(_ birthday: BirthdayItem, until date: Date) async {
        guard date > Date() else { return }
        do {
            let content = birthdayContent(for: birthday)
            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            )
            components.timeZone = .current
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )
            try await center.add(UNNotificationRequest(
                identifier: "birthday.\(birthday.id.uuidString).snooze",
                content: content,
                trigger: trigger
            ))
        } catch {
            // Keep the yearly reminder even if this snooze could not be scheduled.
        }
    }

    func cancel(for birthday: BirthdayItem) async {
        let identifiers = [
            "birthday.\(birthday.id.uuidString).yearly",
            "birthday.\(birthday.id.uuidString).snooze"
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
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

    private func birthdayContent(for birthday: BirthdayItem) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Birthday reminder"
        content.body = "Wish \(birthday.name) a happy birthday."
        content.sound = .default
        content.categoryIdentifier = ReminderNotification.birthdayCategory
        content.userInfo = [
            ReminderNotification.birthdayIDKey: birthday.id.uuidString
        ]
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
    static let snoozeBirthdayFromNotification = Notification.Name(
        "SnoozeBirthdayFromNotification"
    )
}
