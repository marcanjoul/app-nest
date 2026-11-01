import Foundation
import Testing
@testable import AppNest

/// Fixed Gregorian calendar and dates, so the weekday maths doesn't depend on when tests run.
private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()
private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: 15))!
}

@Test("next week is the coming Monday, never today", arguments: [
    // (today, next week) — Nov 2 2026 is a Monday
    (date(2026, 11, 2), date(2026, 11, 9)),   // Monday → the following Monday
    (date(2026, 11, 6), date(2026, 11, 9)),   // Friday
    (date(2026, 11, 8), date(2026, 11, 9)),   // Sunday → tomorrow
])
func quickNextWeek(today: Date, nextWeek: Date) {
    #expect(cal.isDate(QuickDate.nextWeek.date(now: today, calendar: cal), inSameDayAs: nextWeek))
}

@Test("past chips count back calendar days")
func quickPastDates() {
    let today = date(2026, 11, 2)
    #expect(cal.isDate(QuickDate.yesterday.date(now: today, calendar: cal), inSameDayAs: date(2026, 11, 1)))
    #expect(cal.isDate(QuickDate.twoDaysAgo.date(now: today, calendar: cal), inSameDayAs: date(2026, 10, 31)))
}
