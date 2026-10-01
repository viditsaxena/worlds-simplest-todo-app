import Foundation

struct TodoItem: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let createdAt: Date
    let reminderDate: Date?
    let recurrence: RecurrenceRule?
    let hiddenUntil: Date?

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        reminderDate: Date? = nil,
        recurrence: RecurrenceRule? = nil,
        hiddenUntil: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.reminderDate = reminderDate
        self.recurrence = recurrence
        self.hiddenUntil = hiddenUntil
    }

    func isOverdue(at date: Date = Date()) -> Bool {
        guard let reminderDate else { return false }
        return reminderDate < date
    }

    var isRecurring: Bool {
        recurrence != nil
    }

    func isVisible(at date: Date = Date()) -> Bool {
        if isRecurring {
            return true
        }
        guard let hiddenUntil else { return true }
        return hiddenUntil <= date
    }
}
