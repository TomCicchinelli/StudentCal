//
//  PreviewRepository.swift
//  StudyPlanner
//
//  Swap in fake data for manual testing by setting USE_PREVIEW_DATA = 1
//  in the scheme's environment variables, or just temporarily changing
//  StudyPlannerApp to use PreviewRepository() instead of LocalExamRepository().
//
//  To enable: in StudyPlannerApp.swift replace:
//    AppStore(repository: LocalExamRepository())
//  with:
//    AppStore(repository: PreviewRepository())
//

import Foundation

final class PreviewRepository: ExamRepository {

    // Backed by an isolated in-memory UserDefaults suite so it never
    // touches the real app data on disk.
    private let inner: LocalExamRepository

    init() {
        let suite = UserDefaults(suiteName: "preview.\(UUID().uuidString)")!
        inner = LocalExamRepository(defaults: suite)
        seed()
    }

    // MARK: - Forwarding

    func loadExams()                          -> [Exam]       { inner.loadExams() }
    func saveExam(_ exam: Exam)                               { inner.saveExam(exam) }
    func deleteExam(id: UUID)                                 { inner.deleteExam(id: id) }
    func loadLogs()                           -> [StudyLog]   { inner.loadLogs() }
    func appendLog(_ log: StudyLog)                           { inner.appendLog(log) }
    func setLog(_ log: StudyLog)                              { inner.setLog(log) }
    func loadUserEvents()                     -> [UserEvent]  { inner.loadUserEvents() }
    func saveUserEvent(_ event: UserEvent)                    { inner.saveUserEvent(event) }
    func deleteUserEvent(id: UUID)                            { inner.deleteUserEvent(id: id) }

    // MARK: - Seed

    private func seed() {
        let cal = Calendar.current
        let today = Date().startOfDay

        func daysAgo(_ n: Int) -> Date {
            cal.date(byAdding: .day, value: -n, to: today)!
        }
        func daysFromNow(_ n: Int) -> Date {
            cal.date(byAdding: .day, value: n, to: today)!
        }
        func at(_ date: Date, hour: Int, minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
        }

        // ── Exam ──────────────────────────────────────────────────────────
        let examID = UUID()
        let exam = Exam(
            id: examID,
            name: "Macroeconomics",
            date: daysFromNow(24),
            studyInterval: StudyInterval(startHour: 9, endHour: 21),
            unit: .pages,
            totalAmount: 320,
            pagesPerHour: 18,
            completedAmount: 0,   // recalculated from logs below
            studyDays: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        )
        inner.saveExam(exam)

        // ── Study logs — 3 weeks of realistic history ─────────────────────
        // Pattern: consistent Mon–Sat, some light days, one missed day,
        // one strong day to make the chart interesting.
        let logEntries: [(daysAgo: Int, pages: Double)] = [
            // Week 3 ago
            (21, 14), (20, 18), (19, 22), (18, 10), (17, 20), (16, 25),
            // Week 2 ago
            (14, 18), (13, 0),  (12, 24), (11, 16), (10, 22), (9, 28),
            // Last week
            (7,  20), (6,  18), (5,  15), (4,  22), (3,  18), (2,  30),
            // This week
            (1,  20),
        ]

        for entry in logEntries {
            let date = daysAgo(entry.daysAgo)
            // Skip Sunday (the exam's studyDays doesn't include Sunday).
            let weekday = cal.component(.weekday, from: date)
            if weekday == 1 { continue }   // 1 = Sunday in Calendar
            inner.appendLog(StudyLog(
                examID: examID,
                date: date,
                amount: entry.pages,
                unit: .pages
            ))
        }

        // ── User events ───────────────────────────────────────────────────

        // Recurring lecture — Mon/Wed/Fri mornings
        let lectureID = UUID()
        inner.saveUserEvent(UserEvent(
            id: lectureID,
            title: "Macro Lecture",
            startDate: at(today, hour: 10),
            endDate:   at(today, hour: 11, minute: 30),
            repeatFrequency: .weekly,
            eventColor: .preset(.blue),
            notes: "Room B14",
            seriesID: UUID(),
            seriesStartDate: daysAgo(21)
        ))

        // Recurring gym — Tue/Thu evenings (saved as two separate weekly series)
        inner.saveUserEvent(UserEvent(
            id: UUID(),
            title: "Gym",
            startDate: at(today, hour: 18),
            endDate:   at(today, hour: 19, minute: 30),
            repeatFrequency: .weekly,
            eventColor: .preset(.green),
            notes: "",
            seriesID: UUID(),
            seriesStartDate: daysAgo(14)
        ))

        // One-off event this week — study group
        inner.saveUserEvent(UserEvent(
            id: UUID(),
            title: "Study Group",
            startDate: at(daysFromNow(2), hour: 14),
            endDate:   at(daysFromNow(2), hour: 16),
            repeatFrequency: .never,
            eventColor: .preset(.purple),
            notes: "Library 2nd floor"
        ))

        // One-off event next week — dentist
        inner.saveUserEvent(UserEvent(
            id: UUID(),
            title: "Dentist",
            startDate: at(daysFromNow(6), hour: 9, minute: 30),
            endDate:   at(daysFromNow(6), hour: 10, minute: 15),
            repeatFrequency: .never,
            eventColor: .preset(.red),
            notes: ""
        ))

        // Weekly dinner — Saturday evenings
        inner.saveUserEvent(UserEvent(
            id: UUID(),
            title: "Family Dinner",
            startDate: at(today, hour: 19),
            endDate:   at(today, hour: 21),
            repeatFrequency: .weekly,
            eventColor: .preset(.orange),
            notes: "",
            seriesID: UUID(),
            seriesStartDate: daysAgo(14)
        ))
    }
}
