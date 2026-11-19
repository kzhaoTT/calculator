import AppKit
import Foundation
import Observation

public enum DateCalcOption: Int, CaseIterable, Identifiable, Sendable {
    case difference = 0
    case addSubtract = 1

    public var id: Int { rawValue }

    public var title: String {
        let res = ResourceProvider.shared
        switch self {
        case .difference: return res.string("Date_DifferenceOption.Content", fallback: "Difference between dates")
        case .addSubtract: return res.string("Date_AddSubtractOption.Content", fallback: "Add or subtract days")
        }
    }
}

@MainActor
@Observable
public final class DateCalculatorViewModel {
    public static let maxOffsetValue = 999

    private let engine = DateCalculationEngine()
    private let res: ResourceProvider

    public var selectedOption: DateCalcOption = .difference {
        didSet { recalculate() }
    }

    public var isDateDiffMode: Bool { selectedOption == .difference }

    public var fromDate: Date {
        didSet { recalculate() }
    }
    public var toDate: Date {
        didSet { recalculate() }
    }

    public var startDate: Date {
        didSet { recalculate() }
    }
    public var isAddMode: Bool = true {
        didSet { recalculate() }
    }
    public var yearsOffset: Int = 0 {
        didSet { recalculate() }
    }
    public var monthsOffset: Int = 0 {
        didSet { recalculate() }
    }
    public var daysOffset: Int = 0 {
        didSet { recalculate() }
    }

    public private(set) var strDateDiffResult: String = ""
    public private(set) var strDateDiffResultInDays: String = ""
    public private(set) var isDiffInDaysOnly: Bool = true
    public private(set) var strDateResult: String = ""

    public init(resourceProvider: ResourceProvider = .shared) {
        self.res = resourceProvider
        let today = Date()
        self.fromDate = today
        self.toDate = today
        self.startDate = today
        recalculate()
    }

    public func recalculate() {
        if isDateDiffMode {
            let totalDays = engine.totalDaysDifference(from: fromDate, to: toDate)
            if totalDays == 0 {
                isDiffInDaysOnly = true
                strDateDiffResult = res.string("Date_SameDates", fallback: "Same dates")
                strDateDiffResultInDays = ""
            } else {
                let diff = engine.dateDifference(from: fromDate, to: toDate)
                let inDaysText = "\(totalDays) \(res.string(totalDays == 1 ? "Date_Day" : "Date_Days"))"
                if diff.year == 0 && diff.month == 0 && diff.week == 0 {
                    isDiffInDaysOnly = true
                    strDateDiffResult = inDaysText
                    strDateDiffResultInDays = ""
                } else {
                    isDiffInDaysOnly = false
                    strDateDiffResult = formatDifference(diff)
                    strDateDiffResultInDays = inDaysText
                }
            }
        } else {
            let computed = isAddMode
                ? engine.addDuration(startDate: startDate, years: yearsOffset, months: monthsOffset, days: daysOffset)
                : engine.subtractDuration(startDate: startDate, years: yearsOffset, months: monthsOffset, days: daysOffset)
            if let date = computed {
                let df = DateFormatter()
                df.timeZone = TimeZone(secondsFromGMT: 0)
                df.dateStyle = .full
                df.timeStyle = .none
                strDateResult = df.string(from: date)
            } else {
                strDateResult = res.string("Date_OutOfBoundMessage", fallback: "Date out of Bound")
            }
        }
    }

    public func copyResult() {
        let text = isDateDiffMode ? strDateDiffResult : strDateResult
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    private func formatDifference(_ diff: DateDifference) -> String {
        var parts: [String] = []
        if diff.year > 0 {
            parts.append("\(diff.year) \(res.string(diff.year == 1 ? "Date_Year" : "Date_Years"))")
        }
        if diff.month > 0 {
            parts.append("\(diff.month) \(res.string(diff.month == 1 ? "Date_Month" : "Date_Months"))")
        }
        if diff.week > 0 {
            parts.append("\(diff.week) \(res.string(diff.week == 1 ? "Date_Week" : "Date_Weeks"))")
        }
        if diff.day > 0 || parts.isEmpty {
            parts.append("\(diff.day) \(res.string(diff.day == 1 ? "Date_Day" : "Date_Days"))")
        }
        return parts.joined(separator: "\(res.listSeparator) ")
    }
}
