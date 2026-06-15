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

    /// When this exam/study plan was created. Used to bound how far back
    /// the user can browse/log past study days — they shouldn't be able to
    /// log sessions for dates before the plan existed.
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        date: Date,
        studyInterval: StudyInterval = .default,
        unit: StudyUnit = .pages,
        totalAmount: Double,
        pagesPerHour: Double = 5,
        completedAmount: Double = 0,
        studyDays: Set<Weekday> = [.monday, .tuesday, .thursday, .friday],
        createdAt: Date = Date()
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
        self.createdAt = createdAt
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, name, date, studyInterval, unit, totalAmount, pagesPerHour,
             completedAmount, studyDays, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self, forKey: .id)
        name            = try c.decode(String.self, forKey: .name)
        date            = try c.decode(Date.self, forKey: .date)
        studyInterval   = try c.decode(StudyInterval.self, forKey: .studyInterval)
        unit            = try c.decode(StudyUnit.self, forKey: .unit)
        totalAmount     = try c.decode(Double.self, forKey: .totalAmount)
        pagesPerHour    = try c.decode(Double.self, forKey: .pagesPerHour)
        completedAmount = try c.decode(Double.self, forKey: .completedAmount)
        studyDays       = try c.decode(Set<Weekday>.self, forKey: .studyDays)
        // Existing persisted exams predate this field — fall back to a
        // reasonable default (30 days back, matching the old carousel
        // fallback) rather than failing to decode.
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
            ?? Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    }
}
