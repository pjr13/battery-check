import Foundation

public struct RefreshScheduler: Sendable {
    public var dailyHour: Int
    public var dailyMinute: Int
    public var catchUpInterval: TimeInterval
    public var calendar: Calendar

    public init(
        dailyHour: Int = 9,
        dailyMinute: Int = 30,
        catchUpInterval: TimeInterval = 30 * 60,
        calendar: Calendar = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone.current
            return cal
        }()
    ) {
        self.dailyHour = dailyHour
        self.dailyMinute = dailyMinute
        self.catchUpInterval = catchUpInterval
        self.calendar = calendar
    }

    /// Whether a successful refresh already covers today's daily window.
    public func hasCompletedToday(lastSuccess: Date?, now: Date) -> Bool {
        guard let lastSuccess else { return false }
        guard let window = dailyWindowStart(onSameDayAs: now) else { return false }
        return lastSuccess >= window && calendar.isDate(lastSuccess, inSameDayAs: now)
    }

    public func dailyWindowStart(onSameDayAs date: Date) -> Date? {
        calendar.date(bySettingHour: dailyHour, minute: dailyMinute, second: 0, of: date)
    }

    public func nextDailyWindow(after date: Date) -> Date? {
        guard let todayWindow = dailyWindowStart(onSameDayAs: date) else { return nil }
        if date < todayWindow {
            return todayWindow
        }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
        return dailyWindowStart(onSameDayAs: tomorrow)
    }

    /// Next date when a refresh should be attempted.
    public func nextRefreshDate(lastSuccess: Date?, now: Date) -> Date {
        if hasCompletedToday(lastSuccess: lastSuccess, now: now) {
            return nextDailyWindow(after: now) ?? now.addingTimeInterval(catchUpInterval)
        }

        guard let todayWindow = dailyWindowStart(onSameDayAs: now) else {
            return now.addingTimeInterval(catchUpInterval)
        }

        // Before today's window — wait until 09:30.
        if now < todayWindow {
            return todayWindow
        }

        // Missed or due for today's check — catch up every 30 minutes.
        if let lastSuccess, lastSuccess >= todayWindow, calendar.isDate(lastSuccess, inSameDayAs: now) {
            return nextDailyWindow(after: now) ?? now.addingTimeInterval(catchUpInterval)
        }

        // Due now (or ASAP after wake). Caller may clamp "now" to immediate fire.
        return now
    }

    public func shouldRefreshNow(lastSuccess: Date?, now: Date, grace: TimeInterval = 1) -> Bool {
        let next = nextRefreshDate(lastSuccess: lastSuccess, now: now)
        return next <= now.addingTimeInterval(grace)
    }
}
