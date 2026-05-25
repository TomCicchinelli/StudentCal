//
//  ExamRepository.swift
//  StudyPlanner
//

import Foundation

protocol ExamRepository {
    // Exams
    func loadExams() -> [Exam]
    func saveExam(_ exam: Exam)
    func deleteExam(id: UUID)

    // Study logs
    func loadLogs() -> [StudyLog]
    func appendLog(_ log: StudyLog)
    /// Upsert: replace any existing log for the same (examID, calendar day), or insert.
    func setLog(_ log: StudyLog)

    // User-created calendar events
    func loadUserEvents() -> [UserEvent]
    func saveUserEvent(_ event: UserEvent)
    func deleteUserEvent(id: UUID)
}
