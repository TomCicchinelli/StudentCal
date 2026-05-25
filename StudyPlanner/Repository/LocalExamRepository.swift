//
//  LocalExamRepository.swift
//  StudyPlanner
//

import Foundation

final class LocalExamRepository: ExamRepository {

    private enum Keys {
        static let exams      = "studyplanner.exams.v1"
        static let logs       = "studyplanner.logs.v1"
        static let userEvents = "studyplanner.userevents.v1"
    }

    private let defaults: UserDefaults
    private let encoder  = JSONEncoder()
    private let decoder  = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Exams

    func loadExams() -> [Exam] { decode([Exam].self, key: Keys.exams) ?? [] }

    func saveExam(_ exam: Exam) {
        var all = loadExams()
        if let idx = all.firstIndex(where: { $0.id == exam.id }) { all[idx] = exam }
        else { all.append(exam) }
        encode(all, key: Keys.exams)
    }

    func deleteExam(id: UUID) {
        encode(loadExams().filter { $0.id != id }, key: Keys.exams)
        encode(loadLogs().filter { $0.examID != id }, key: Keys.logs)
    }

    // MARK: - Logs

    func loadLogs() -> [StudyLog] { decode([StudyLog].self, key: Keys.logs) ?? [] }

    func appendLog(_ log: StudyLog) {
        var all = loadLogs()
        all.append(log)
        encode(all, key: Keys.logs)
    }

    /// Replaces the existing log for (examID, same calendar day) or appends.
    func setLog(_ log: StudyLog) {
        var all = loadLogs()
        let cal = Calendar.current
        // Remove any previous entry for the same exam on the same day.
        all.removeAll {
            $0.examID == log.examID &&
            cal.isDate($0.date, inSameDayAs: log.date)
        }
        all.append(log)
        encode(all, key: Keys.logs)
    }

    // MARK: - User events

    func loadUserEvents() -> [UserEvent] { decode([UserEvent].self, key: Keys.userEvents) ?? [] }

    func saveUserEvent(_ event: UserEvent) {
        var all = loadUserEvents()
        if let idx = all.firstIndex(where: { $0.id == event.id }) { all[idx] = event }
        else { all.append(event) }
        encode(all, key: Keys.userEvents)
    }

    func deleteUserEvent(id: UUID) {
        encode(loadUserEvents().filter { $0.id != id }, key: Keys.userEvents)
    }

    // MARK: - Private

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
