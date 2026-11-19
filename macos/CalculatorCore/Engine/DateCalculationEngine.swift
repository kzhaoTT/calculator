import Foundation

public struct DateDifference: Equatable, Sendable {
    public var year: Int
    public var month: Int
    public var week: Int
    public var day: Int

    public init(year: Int = 0, month: Int = 0, week: Int = 0, day: Int = 0) {
        self.year = year
        self.month = month
        self.week = week
        self.day = day
    }
}

/// Faithful port of `src/Calculator.ViewModels/Common/DateCalculator.cs` (`DateCalculationEngine`).
public final class DateCalculationEngine: Sendable {
    private let calendar: Calendar
    private static let minSupportedDate: Date = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(from: DateComponents(year: 1601, month: 1, day: 1))!
    }()
    private static let maxSupportedDate: Date = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(from: DateComponents(year: 9999, month: 12, day: 31))!
    }()

    public init() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = cal
    }

    public func clipTime(_ date: Date) -> Date {
        let localCal = Calendar.current
        let comps = localCal.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: comps.day)) ?? date
    }

    public func addDuration(startDate: Date, years: Int, months: Int, days: Int) -> Date? {
        let clipped = clipTime(startDate)
        var current = clipped
        if years != 0 {
            guard let next = calendar.date(byAdding: .year, value: years, to: current) else { return nil }
            current = next
        }
        if months != 0 {
            guard let next = calendar.date(byAdding: .month, value: months, to: current) else { return nil }
            current = next
        }
        if days != 0 {
            guard let next = calendar.date(byAdding: .day, value: days, to: current) else { return nil }
            current = next
        }
        guard current >= Self.minSupportedDate, current <= Self.maxSupportedDate else { return nil }
        return current
    }

    /// Exact Windows Calculator subtraction order: smaller units first (days -> months -> years).
    public func subtractDuration(startDate: Date, years: Int, months: Int, days: Int) -> Date? {
        let clipped = clipTime(startDate)
        var current = clipped
        if days != 0 {
            guard let next = calendar.date(byAdding: .day, value: -days, to: current) else { return nil }
            current = next
        }
        if months != 0 {
            guard let next = calendar.date(byAdding: .month, value: -months, to: current) else { return nil }
            current = next
        }
        if years != 0 {
            guard let next = calendar.date(byAdding: .year, value: -years, to: current) else { return nil }
            current = next
        }
        guard current >= Self.minSupportedDate, current <= Self.maxSupportedDate else { return nil }
        return current
    }

    public func totalDaysDifference(from date1: Date, to date2: Date) -> Int {
        let d1 = clipTime(date1)
        let d2 = clipTime(date2)
        let start = min(d1, d2)
        let end = max(d1, d2)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Exact Windows Calculator date difference decomposition: Years, Months, Weeks, Days.
    public func dateDifference(from date1: Date, to date2: Date) -> DateDifference {
        let d1 = clipTime(date1)
        let d2 = clipTime(date2)
        let start = min(d1, d2)
        let end = max(d1, d2)

        var pivot = start

        // Years
        var years = 0
        while let candidate = calendar.date(byAdding: .year, value: years + 1, to: pivot), candidate <= end {
            years += 1
        }
        if years > 0, let advanced = calendar.date(byAdding: .year, value: years, to: pivot) {
            pivot = advanced
        }

        // Months
        var months = 0
        while let candidate = calendar.date(byAdding: .month, value: months + 1, to: pivot), candidate <= end {
            months += 1
        }
        if months > 0, let advanced = calendar.date(byAdding: .month, value: months, to: pivot) {
            pivot = advanced
        }

        // Remaining days -> Weeks + Days
        let remainingDays = max(0, calendar.dateComponents([.day], from: pivot, to: end).day ?? 0)
        let weeks = remainingDays / 7
        let days = remainingDays % 7

        return DateDifference(year: years, month: months, week: weeks, day: days)
    }
}
