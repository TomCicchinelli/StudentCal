//
//  StudyLog.swift
//  StudyPlanner
//

import Foundation

struct StudyLog: Identifiable, Codable, Hashable {
    let id: UUID
    let examID: UUID
    let date: Date
    let amount: Double
    let unit: StudyUnit

    init(id: UUID = UUID(), examID: UUID, date: Date, amount: Double, unit: StudyUnit) {
        self.id     = id
        self.examID = examID
        // Normalise to noon so timezone edge cases don't flip the day.
        self.date   = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        self.amount = amount
        self.unit   = unit
    }
}

/// Auto-generated calendar event (exam day marker). Not persisted.
struct CalendarEvent: Identifiable, Hashable {
    enum Kind: Hashable {
        case study(examID: UUID, examName: String)
        case exam(examID: UUID, examName: String)
    }

    let id: String
    let kind: Kind
    let startDate: Date
    let endDate: Date

    var title: String {
        switch kind {
        case .study(_, let name): return "Study · \(name)"
        case .exam(_, let name):  return "Exam · \(name)"
        }
    }
}
