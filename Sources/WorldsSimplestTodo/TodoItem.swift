import Foundation

struct TodoItem: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let createdAt: Date
    let reminderDate: Date?
    let recurrence: RecurrenceRule?
    let hiddenUntil: Date?
    let isToday: Bool

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        reminderDate: Date? = nil,
        recurrence: RecurrenceRule? = nil,
        hiddenUntil: Date? = nil,
        isToday: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.reminderDate = reminderDate
        self.recurrence = recurrence
        self.hiddenUntil = hiddenUntil
        self.isToday = isToday
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt
        case reminderDate
        case recurrence
        case hiddenUntil
        case isToday
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        reminderDate = try container.decodeIfPresent(Date.self, forKey: .reminderDate)
        recurrence = try container.decodeIfPresent(RecurrenceRule.self, forKey: .recurrence)
        hiddenUntil = try container.decodeIfPresent(Date.self, forKey: .hiddenUntil)
        isToday = try container.decodeIfPresent(Bool.self, forKey: .isToday) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(reminderDate, forKey: .reminderDate)
        try container.encodeIfPresent(recurrence, forKey: .recurrence)
        try container.encodeIfPresent(hiddenUntil, forKey: .hiddenUntil)
        try container.encode(isToday, forKey: .isToday)
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
