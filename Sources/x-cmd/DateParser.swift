import Foundation

struct DateParser {
    static func parse(_ input: String) -> Date? {
        let input = input.lowercased().trimmingCharacters(in: .whitespaces)
        let calendar = Calendar.current
        let now = Date()
        
        switch input {
        case "today":
            return calendar.startOfDay(for: now)
        case "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        case "yesterday":
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        case "next week", "nextweek":
            return calendar.date(byAdding: .weekOfYear, value: 1, to: calendar.startOfDay(for: now))
        case "next month", "nextmonth":
            return calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: now))
        case "eod", "end of day":
            return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)
        default:
            break
        }
        
        if input.hasPrefix("+") {
            let rest = String(input.dropFirst())
            if let days = Int(rest) {
                return calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now))
            }
        }
        
        if input.hasPrefix("-") {
            let rest = String(input.dropFirst())
            if let days = Int(rest) {
                return calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now))
            }
        }
        
        return ISO8601DateFormatter().date(from: input)
    }
    
    static func endOfDay(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
    }
    
    static func startOfDay(_ date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }
}
