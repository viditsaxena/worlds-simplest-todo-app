import Foundation

struct ParsedBirthday: Equatable {
    let name: String
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int
}

enum BirthdayParser {
    private static let monthNames: [String: Int] = [
        "january": 1, "jan": 1,
        "february": 2, "feb": 2,
        "march": 3, "mar": 3,
        "april": 4, "apr": 4,
        "may": 5,
        "june": 6, "jun": 6,
        "july": 7, "jul": 7,
        "august": 8, "aug": 8,
        "september": 9, "sep": 9, "sept": 9,
        "october": 10, "oct": 10,
        "november": 11, "nov": 11,
        "december": 12, "dec": 12
    ]

    private static let monthPattern = monthNames.keys
        .sorted { $0.count > $1.count }
        .joined(separator: "|")

    static func parse(_ rawInput: String) -> ParsedBirthday? {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }

        let patterns = [
            "\\b(\(monthPattern))\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b",
            "\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+(\(monthPattern))\\b"
        ]

        guard let dateMatch = firstMatch(in: input, patterns: patterns),
              Range(dateMatch.range, in: input) != nil else {
            return nil
        }

        let month: Int
        let day: Int
        if let monthRange = Range(dateMatch.range(at: 1), in: input),
           let monthValue = monthNames[String(input[monthRange]).lowercased()],
           let dayRange = Range(dateMatch.range(at: 2), in: input),
           let dayValue = Int(input[dayRange]) {
            month = monthValue
            day = dayValue
        } else if let dayRange = Range(dateMatch.range(at: 1), in: input),
                  let dayValue = Int(input[dayRange]),
                  let monthRange = Range(dateMatch.range(at: 2), in: input),
                  let monthValue = monthNames[String(input[monthRange]).lowercased()] {
            month = monthValue
            day = dayValue
        } else {
            return nil
        }

        guard isValid(month: month, day: day) else { return nil }

        let timeMatch = firstMatch(
            in: input,
            patterns: ["\\bat\\s+(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)\\b"]
        )
        let time = parsedTime(from: timeMatch, in: input) ?? (hour: 9, minute: 0)

        var name = input
        var ranges = [dateMatch.range]
        if let timeMatch {
            ranges.append(timeMatch.range)
        }
        for range in ranges.sorted(by: { $0.location > $1.location }) {
            guard let swiftRange = Range(range, in: name) else { continue }
            name.removeSubrange(swiftRange)
        }

        name = name.replacingOccurrences(
            of: "(?i)(?:['’]s\\s+)?birthday(?:\\s+is)?",
            with: "",
            options: .regularExpression
        )
        name = name.replacingOccurrences(
            of: "(?i)^\\s*(?:remember|remind\\s+me)(?:\\s+that|\\s+to)?\\s+",
            with: "",
            options: .regularExpression
        )
        name = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters))
        name = name.replacingOccurrences(
            of: "(?i)\\s+(?:is|on)$",
            with: "",
            options: .regularExpression
        )
        name = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters))

        guard !name.isEmpty else { return nil }
        return ParsedBirthday(
            name: name,
            month: month,
            day: day,
            hour: time.hour,
            minute: time.minute
        )
    }

    private static func firstMatch(
        in input: String,
        patterns: [String]
    ) -> NSTextCheckingResult? {
        let range = NSRange(input.startIndex..., in: input)
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else { continue }
            if let match = expression.firstMatch(in: input, range: range) {
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

        guard (1...12).contains(hour), (0...59).contains(minute) else { return nil }
        hour %= 12
        if input[meridiemRange].lowercased() == "pm" {
            hour += 12
        }
        return (hour, minute)
    }

    private static func isValid(month: Int, day: Int) -> Bool {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = 2024
        components.month = month
        components.day = day
        return components.date.map {
            Calendar(identifier: .gregorian).component(.day, from: $0) == day
        } ?? false
    }
}
