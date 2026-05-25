//
//  DateHelpers.swift
//  StudyPlanner
//

import Foundation

extension Date {
    /// Beginning of this day (local time).
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    /// Returns the same wall-clock day with the given hour applied.
    func setting(hour: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour, minute: 0, second: 0, of: self
        ) ?? self
    }

    /// Iterate days inclusively from `self` to `end`.
    func daysThrough(_ end: Date) -> [Date] {
        var result: [Date] = []
        var cursor = startOfDay
        let last = end.startOfDay
        while cursor <= last {
            result.append(cursor)
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400)
        }
        return result
    }

    var weekday: Weekday? {
        let raw = Calendar.current.component(.weekday, from: self)
        return Weekday(rawValue: raw)
    }
}

enum DateFormatters {
    /// dd/MM — matches the mockups (17/01, 13/01, ...).
    static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM"
        return f
    }()

    /// dd/MM/yyyy — for edit screen.
    static let fullDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    /// "May", "June", ... — month picker.
    static let monthName: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL"
        return f
    }()
}
