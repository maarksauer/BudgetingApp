import Foundation

nonisolated enum RecurringSchedule {
    static let frequencies = ["Weekly", "Monthly", "Every 3 Months", "Every 6 Months", "Yearly"]

    static func nextDate(frequency: String, from date: Date, calendar: Calendar = .current) -> Date? {
        let component: Calendar.Component
        let count: Int
        switch frequency {
        case "Weekly": component = .weekOfYear; count = 1
        case "Monthly": component = .month; count = 1
        case "Every 3 Months": component = .month; count = 3
        case "Every 6 Months": component = .month; count = 6
        case "Yearly": component = .year; count = 1
        default: return nil
        }
        return calendar.date(byAdding: component, value: count, to: date)
    }
}
