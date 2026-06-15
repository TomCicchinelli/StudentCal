//
//  StudyPlanCalculator.swift
//  StudyPlanner
//
//  Pure functions that derive plan-level information from an `Exam`:
//   - progress fraction
//   - expected completion date (given study days + hours/day + work rate)
//   - calendar events (recurring study blocks + the exam day itself)
//
//  Kept separate from view models so unit tests can hit it directly later.
//

import Foundation

enum StudyPlanCalculator {

    /// 0...1 progress, clamped.
    static func progress(for exam: Exam) -> Double {
        guard exam.totalAmount > 0 else { return 0 }
        return min(1, max(0, exam.completedAmount / exam.totalAmount))
    }

    /// How much "work" the user does on a single study day, in the exam's own unit.
    /// - Pages mode: hoursPerDay × pagesPerHour
    /// - Hours mode: hoursPerDay
    static func dailyOutput(for exam: Exam) -> Double {
        let hoursPerDay = Double(exam.studyInterval.hoursPerDay)
        switch exam.unit {
        case .pages: return hoursPerDay * exam.pagesPerHour
        case .hours: return hoursPerDay
        }
    }

    /// First date on/after `from` on which the user will have finished, given
    /// their selected study weekdays. Returns nil if no study days are picked
    /// or daily output is zero.
    static func expectedCompletionDate(
        for exam: Exam,
        from: Date = Date()
    ) -> Date? {
        guard !exam.studyDays.isEmpty else { return nil }
        let daily = dailyOutput(for: exam)
        guard daily > 0 else { return nil }

        let remaining = max(0, exam.totalAmount - exam.completedAmount)
        if remaining == 0 { return from.startOfDay }

        // Ceiling division of remaining / daily, then walk forward day by day
        // skipping non-study weekdays.
        let neededDays = Int((remaining / daily).rounded(.up))

        var cursor = from.startOfDay
        var counted = 0
        // Hard cap to avoid runaway loop in pathological data.
        for _ in 0..<(365 * 5) {
            if let wd = cursor.weekday, exam.studyDays.contains(wd) {
                counted += 1
                if counted >= neededDays { return cursor }
            }
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400)
        }
        return nil
    }

    /// Calendar events for a given visible day: study blocks for every exam
    /// whose study-days include that weekday and whose date is in the future,
    /// plus a marker for the exam itself.
    static func events(
        on day: Date,
        exams: [Exam]
    ) -> [CalendarEvent] {
        let dayStart = day.startOfDay
        guard let weekday = dayStart.weekday else { return [] }

        var events: [CalendarEvent] = []

        for exam in exams {
            let examDay = exam.date.startOfDay

            // Exam day itself — single all-interval block.
            if Calendar.current.isDate(dayStart, inSameDayAs: examDay) {
                events.append(
                    CalendarEvent(
                        id: "exam-\(exam.id.uuidString)-\(dayStart.timeIntervalSince1970)",
                        kind: .exam(examID: exam.id, examName: exam.name),
                        startDate: dayStart.setting(hour: exam.studyInterval.startHour),
                        endDate: dayStart.setting(hour: exam.studyInterval.endHour)
                    )
                )
                continue
            }

            // Study block — only on selected weekdays and only before the exam.
            guard exam.studyDays.contains(weekday) else { continue }
            guard dayStart < examDay else { continue }

            events.append(
                CalendarEvent(
                    id: "study-\(exam.id.uuidString)-\(dayStart.timeIntervalSince1970)",
                    kind: .study(examID: exam.id, examName: exam.name),
                    startDate: dayStart.setting(hour: exam.studyInterval.startHour),
                    endDate: dayStart.setting(hour: exam.studyInterval.endHour)
                )
            )
        }

        return events.sorted { $0.startDate < $1.startDate }
    }
}
