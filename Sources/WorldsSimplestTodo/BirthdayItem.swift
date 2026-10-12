import Foundation

struct BirthdayItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let month: Int
    let day: Int
    let reminderHour: Int
    let reminderMinute: Int
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        month: Int,
        day: Int,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.month = min(max(month, 1), 12)
        self.day = min(max(day, 1), 31)
        self.reminderHour = min(max(reminderHour, 0), 23)
        self.reminderMinute = min(max(reminderMinute, 0), 59)
        self.createdAt = createdAt
    }

    func nextDate(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year], from: date)
        components.month = month
        components.day = day
        components.hour = reminderHour
        components.minute = reminderMinute
        components.second = 0
        components.timeZone = calendar.timeZone

        if let candidate = calendar.date(from: components), candidate > date {
            return candidate
        }

        components.year = (components.year ?? calendar.component(.year, from: date)) + 1
        return calendar.date(from: components)
            ?? calendar.date(byAdding: .year, value: 1, to: date)
            ?? date
    }

    func notificationComponents() -> DateComponents {
        DateComponents(
            timeZone: .current,
            month: month,
            day: day,
            hour: reminderHour,
            minute: reminderMinute
        )
    }
}
