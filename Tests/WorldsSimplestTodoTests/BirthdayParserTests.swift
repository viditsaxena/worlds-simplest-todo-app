import Foundation
import Testing
@testable import WorldsSimplestTodo

@Test("Parses a natural birthday sentence")
func parsesNaturalBirthdaySentence() {
    let result = BirthdayParser.parse("Mum's birthday is March 12 at 8:30 am")

    #expect(result == ParsedBirthday(
        name: "Mum",
        month: 3,
        day: 12,
        hour: 8,
        minute: 30
    ))
}

@Test("Parses day before month")
func parsesDayBeforeMonth() {
    let result = BirthdayParser.parse("Alex 21st October")

    #expect(result?.name == "Alex")
    #expect(result?.month == 10)
    #expect(result?.day == 21)
    #expect(result?.hour == 9)
    #expect(result?.minute == 0)
}

@Test("Rejects impossible birthday dates")
func rejectsImpossibleDate() {
    #expect(BirthdayParser.parse("Alex April 31") == nil)
}

@Test("Calculates the next yearly birthday")
func calculatesNextBirthday() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let birthday = BirthdayItem(name: "Alex", month: 10, day: 21)
    let start = try #require(calendar.date(from: DateComponents(
        year: 2026,
        month: 10,
        day: 22,
        hour: 12
    )))
    let next = birthday.nextDate(after: start, calendar: calendar)
    let components = calendar.dateComponents([.year, .month, .day, .hour], from: next)

    #expect(components.year == 2027)
    #expect(components.month == 10)
    #expect(components.day == 21)
    #expect(components.hour == 9)
}

@Test("Old saved tasks default to medium priority")
func decodesLegacyTaskPriority() throws {
    let id = UUID()
    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    let legacy: [String: Any] = [
        "id": id.uuidString,
        "title": "Legacy task",
        "createdAt": createdAt.timeIntervalSinceReferenceDate,
        "isToday": true
    ]
    let data = try JSONSerialization.data(withJSONObject: legacy)
    let item = try JSONDecoder().decode(TodoItem.self, from: data)

    #expect(item.priority == .medium)
}

@Test("Priority order is high, medium, low")
func priorityOrder() {
    #expect(TodoPriority.allCases == [.high, .medium, .low])
    #expect(TodoPriority.high.rawValue > TodoPriority.medium.rawValue)
    #expect(TodoPriority.medium.rawValue > TodoPriority.low.rawValue)
}
