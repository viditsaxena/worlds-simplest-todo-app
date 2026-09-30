import Foundation

struct ParsedTodo: Equatable {
    let title: String
    let reminderDate: Date?
    let recurrence: RecurrenceRule?
}

enum ReminderParser {
    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    static func parse(_ rawInput: String) -> ParsedTodo {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            return ParsedTodo(title: "", reminderDate: nil, recurrence: nil)
        }

        if let recurring = parseMonthlyRecurrence(input) {
            return recurring
        }

        guard let detector,
              let match = detector.matches(
                  in: input,
                  range: NSRange(input.startIndex..., in: input)
              ).first(where: { $0.date != nil }),
              let reminderDate = match.date,
              let matchRange = Range(match.range, in: input) else {
            return ParsedTodo(
                title: stripReminderPrefix(from: input),
                reminderDate: nil,
                recurrence: nil
            )
        }

        var title = input
        title.removeSubrange(matchRange)
        title = stripReminderPrefix(from: title)
        title = stripTrailingConnector(from: title)

        if title.isEmpty {
            title = "Reminder"
        }

        return ParsedTodo(title: title, reminderDate: reminderDate, recurrence: nil)
    }

    private static func parseMonthlyRecurrence(_ input: String) -> ParsedTodo? {
        let ordinal = "(first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth|eleventh|twelfth|thirteenth|fourteenth|fifteenth|sixteenth|seventeenth|eighteenth|nineteenth|twentieth|twenty[- ]first|twenty[- ]second|twenty[- ]third|twenty[- ]fourth|twenty[- ]fifth|twenty[- ]sixth|twenty[- ]seventh|twenty[- ]eighth|(?:2[0-8]|1[0-9]|[1-9])(?:st|nd|rd|th)?\\b)"
        let patterns = [
            "(?:on\\s+|at\\s+)?(?:the\\s+)?\(ordinal)\\s+(?:day\\s+)?of\\s+every\\s+month",
            "every\\s+month(?:\\s+on)?\\s+(?:the\\s+)?\(ordinal)"
        ]

        guard let recurrenceMatch = firstMatch(in: input, patterns: patterns),
              recurrenceMatch.numberOfRanges > 1,
              let ordinalRange = Range(recurrenceMatch.range(at: 1), in: input),
              let day = ordinalDay(String(input[ordinalRange])) else {
            return nil
        }

        let timeMatch = firstMatch(
            in: input,
            patterns: ["\\bat\\s+(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)\\b"]
        )
        let time = parsedTime(from: timeMatch, in: input) ?? (hour: 9, minute: 0)
        let recurrence = RecurrenceRule.monthly(
            day: day,
            hour: time.hour,
            minute: time.minute
        )

        var removalRanges = [recurrenceMatch.range]
        if let timeMatch {
            removalRanges.append(timeMatch.range)
        }
        var title = removing(ranges: removalRanges, from: input)
        title = stripReminderPrefix(from: title)
        title = stripTrailingConnector(from: title)
        if title.isEmpty {
            title = "Recurring reminder"
        }

        return ParsedTodo(
            title: title,
            reminderDate: recurrence.nextDate(after: Date()),
            recurrence: recurrence
        )
    }

    private static func firstMatch(
        in input: String,
        patterns: [String]
    ) -> NSTextCheckingResult? {
        let fullRange = NSRange(input.startIndex..., in: input)
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else { continue }
            if let match = expression.firstMatch(in: input, range: fullRange) {
                return match
            }
        }
        return nil
    }

    private static func parsedTime(
        from match: NSTextCheckingResult?,
        in input: String
    ) -> (hour: Int, minute: Int)? {
        guard let match,
              match.numberOfRanges > 3,
              let hourRange = Range(match.range(at: 1), in: input),
              let meridiemRange = Range(match.range(at: 3), in: input),
              var hour = Int(input[hourRange]) else {
            return nil
        }

        let minute: Int
        if match.range(at: 2).location != NSNotFound,
           let minuteRange = Range(match.range(at: 2), in: input) {
            minute = Int(input[minuteRange]) ?? 0
        } else {
            minute = 0
        }

        let meridiem = input[meridiemRange].lowercased()
        hour %= 12
        if meridiem == "pm" {
            hour += 12
        }
        return (hour, minute)
    }

    private static func ordinalDay(_ rawValue: String) -> Int? {
        let normalized = rawValue
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
        let words = [
            "first", "second", "third", "fourth", "fifth", "sixth", "seventh",
            "eighth", "ninth", "tenth", "eleventh", "twelfth", "thirteenth",
            "fourteenth", "fifteenth", "sixteenth", "seventeenth", "eighteenth",
            "nineteenth", "twentieth", "twenty first", "twenty second",
            "twenty third", "twenty fourth", "twenty fifth", "twenty sixth",
            "twenty seventh", "twenty eighth"
        ]
        if let index = words.firstIndex(of: normalized) {
            return index + 1
        }

        let digits = normalized.prefix { $0.isNumber }
        guard let day = Int(digits), (1...28).contains(day) else { return nil }
        return day
    }

    private static func removing(ranges: [NSRange], from input: String) -> String {
        var result = input
        for nsRange in ranges.sorted(by: { $0.location > $1.location }) {
            guard let range = Range(nsRange, in: result) else { continue }
            result.removeSubrange(range)
        }
        return result
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
