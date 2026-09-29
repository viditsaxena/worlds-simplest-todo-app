import Foundation

struct ParsedTodo: Equatable {
    let title: String
    let reminderDate: Date?
}

enum ReminderParser {
    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    static func parse(_ rawInput: String) -> ParsedTodo {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            return ParsedTodo(title: "", reminderDate: nil)
        }

        guard let detector,
              let match = detector.matches(
                  in: input,
                  range: NSRange(input.startIndex..., in: input)
              ).first(where: { $0.date != nil }),
              let reminderDate = match.date,
              let matchRange = Range(match.range, in: input) else {
            return ParsedTodo(title: stripReminderPrefix(from: input), reminderDate: nil)
        }

        var title = input
        title.removeSubrange(matchRange)
        title = stripReminderPrefix(from: title)
        title = stripTrailingConnector(from: title)

        if title.isEmpty {
            title = "Reminder"
        }

        return ParsedTodo(title: title, reminderDate: reminderDate)
    }

    private static func stripReminderPrefix(from input: String) -> String {
        var title = input.trimmingCharacters(in: separatorCharacters)
        let prefixes = ["remind me to ", "remind me ", "remember to "]

        if let prefix = prefixes.first(where: { title.lowercased().hasPrefix($0) }) {
            title.removeFirst(prefix.count)
        }

        return title.trimmingCharacters(in: separatorCharacters)
    }

    private static func stripTrailingConnector(from input: String) -> String {
        let connectors = [" on", " at", " by", " for"]
        var title = input

        if let connector = connectors.first(where: { title.lowercased().hasSuffix($0) }) {
            title.removeLast(connector.count)
        }

        return title.trimmingCharacters(in: separatorCharacters)
    }

    private static let separatorCharacters = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters)
}
