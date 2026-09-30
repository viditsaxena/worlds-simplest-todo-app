import Foundation

struct RecurrenceRule: Codable, Equatable, Sendable {
    enum Frequency: String, Codable, Sendable {
        case monthly
    }

    let frequency: Frequency
    let dayOfMonth: Int
    let hour: Int
    let minute: Int

    static func monthly(day: Int, hour: Int = 9, minute: Int = 0) -> RecurrenceRule {
        RecurrenceRule(
            frequency: .monthly,
            dayOfMonth: min(max(day, 1), 28),
            hour: min(max(hour, 0), 23),
            minute: min(max(minute, 0), 59)
        )
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = dayOfMonth
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = calendar.timeZone

        if let candidate = calendar.date(from: components), candidate > date {
            return candidate
        }

        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else {
            return date.addingTimeInterval(31 * 24 * 60 * 60)
        }
        components = calendar.dateComponents([.year, .month], from: nextMonth)
        components.day = dayOfMonth
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = calendar.timeZone
        return calendar.date(from: components) ?? nextMonth
    }

    func dueComponents() -> DateComponents {
        DateComponents(
            timeZone: .current,
            day: dayOfMonth,
            hour: hour,
            minute: minute
        )
    }

    func followUpComponents(calendar: Calendar = .current) -> DateComponents {
        var reference = DateComponents()
        reference.calendar = calendar
        reference.timeZone = calendar.timeZone
        reference.year = 2026
        reference.month = 1
        reference.day = dayOfMonth
        reference.hour = hour
        reference.minute = minute

        guard let due = calendar.date(from: reference),
              let followUp = calendar.date(byAdding: .minute, value: 10, to: due) else {
            return dueComponents()
        }
        var components = calendar.dateComponents([.day, .hour, .minute], from: followUp)
        components.timeZone = calendar.timeZone
        return components
    }

    func matchesScheduledTime(_ date: Date, calendar: Calendar = .current) -> Bool {
        let dateComponents = calendar.dateComponents([.day, .hour, .minute], from: date)
        let schedules = [dueComponents(), followUpComponents(calendar: calendar)]
        return schedules.contains { components in
            components.day == dateComponents.day
                && components.hour == dateComponents.hour
                && components.minute == dateComponents.minute
        }
    }

    func scheduleDescription(locale: Locale = .current) -> String {
        let ordinal = NumberFormatter.localizedString(
            from: NSNumber(value: dayOfMonth),
            number: .ordinal
        )
        var components = DateComponents()
        components.calendar = .current
        components.year = 2026
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        let time = components.date?.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)
        ) ?? ""
        return "Every month on the \(ordinal) at \(time)"
    }
}
