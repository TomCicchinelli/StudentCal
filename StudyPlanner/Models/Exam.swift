//
//  Exam.swift
//  StudyPlanner
//
//  Core domain model. `Codable` so the repository can serialize it to
//  UserDefaults today and to a remote backend tomorrow without changes here.
//

import Foundation

/// How the user prefers to measure study progress.
enum StudyUnit: String, Codable, CaseIterable, Identifiable {
    case pages
    case hours

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pages: return "Pages"
        case .hours: return "Total hours"
        }
    }

    /// The unit shown next to a quantity (e.g. "120 pages", "30 hours").
    var unitNoun: String {
        switch self {
        case .pages: return "pages"
        case .hours: return "hours"
        }
    }
}

/// A day-of-week selection used by the study plan.
/// Sunday = 1 to match `Calendar.component(.weekday, ...)`.
enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case monday = 2, tuesday, wednesday, thursday, friday, saturday, sunday = 1

    var id: Int { rawValue }

    /// Display order: Mon → Sun (European layout, matches the mockups).
    static let displayOrder: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
    ]

    var shortLabel: String {
        switch self {
        case .monday:    return "M"
        case .tuesday:   return "Tu"
        case .wednesday: return "W"
        case .thursday:  return "Th"
        case .friday:    return "F"
        case .saturday:  return "Sa"
        case .sunday:    return "Su"
        }
    }
}

/// A study interval expressed as start/end hour-of-day, 24h format.
/// e.g. start 9, end 17 → "9–17".
struct StudyInterval: Codable, Hashable {
    var startHour: Int
    var endHour: Int

    var hoursPerDay: Int { max(0, endHour - startHour) }
    var displayLabel: String { "\(startHour)–\(endHour)" }

    static let `default` = StudyInterval(startHour: 9, endHour: 17)
}

/// A single exam the user is preparing for.
struct Exam: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var date: Date
    var studyInterval: StudyInterval
    var unit: StudyUnit

    /// Pages mode: total pages to study. Hours mode: total hours.
    var totalAmount: Double

    /// Pages mode: pages-per-hour reading rate. Ignored in hours mode.
    var pagesPerHour: Double

    /// Pages mode: pages already studied. Hours mode: hours already studied.
    var completedAmount: Double

    /// Days of the week the user wants to study.
    var studyDays: Set<Weekday>

    init(
        id: UUID = UUID(),
        name: String,
        date: Date,
        studyInterval: StudyInterval = .default,
        unit: StudyUnit = .pages,
        totalAmount: Double,
        pagesPerHour: Double = 5,
        completedAmount: Double = 0,
        studyDays: Set<Weekday> = [.monday, .tuesday, .thursday, .friday]
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.studyInterval = studyInterval
        self.unit = unit
        self.totalAmount = totalAmount
        self.pagesPerHour = pagesPerHour
        self.completedAmount = completedAmount
        self.studyDays = studyDays
    }
}
