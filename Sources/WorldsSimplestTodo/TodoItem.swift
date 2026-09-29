import Foundation

struct TodoItem: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let createdAt: Date
    let reminderDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        reminderDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.reminderDate = reminderDate
    }

    func isOverdue(at date: Date = Date()) -> Bool {
        guard let reminderDate else { return false }
        return reminderDate < date
    }
}
