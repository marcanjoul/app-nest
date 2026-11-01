import Foundation

/// Date-chip shortcuts for DateAppliedSection. Past ones for applications already sent,
/// future ones for To Apply.
enum QuickDate: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case twoDaysAgo = "2 days ago"
    case tomorrow = "Tomorrow"
    case nextWeek = "Next week"

    /// Three each way; the section's fourth chip opens the calendar.
    static let past: [QuickDate] = [.today, .yesterday, .twoDaysAgo]
    static let future: [QuickDate] = [.today, .tomorrow, .nextWeek]

    /// Keeps the current time of day; only the day matters to the picker.
    func date(now: Date = Date(), calendar cal: Calendar = .current) -> Date {
        let day: (Int) -> Date = { cal.date(byAdding: .day, value: $0, to: now) ?? now }
        let weekday = cal.component(.weekday, from: now)   // 1 = Sunday … 7 = Saturday
        /// Days until the next `target` weekday, strictly after today (1…7).
        let daysUntil: (Int) -> Int = { target in (target - weekday + 6) % 7 + 1 }
        switch self {
        case .today:       return now
        case .yesterday:   return day(-1)
        case .twoDaysAgo:  return day(-2)
        case .tomorrow:    return day(1)
        case .nextWeek:    return day(daysUntil(2))   // the coming Monday, never today
        }
    }
}
