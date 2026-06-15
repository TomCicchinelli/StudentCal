//
//  AppStore.swift
//  StudyPlanner
//

import Foundation
import Observation

@Observable
final class AppStore {

    // MARK: - State

    private(set) var exams: [Exam] = []
    private(set) var userEvents: [UserEvent] = []
    private(set) var scheduledBlocks: [UUID: [ScheduledBlock]] = [:]
    private(set) var planOverflowsExam: Bool = false

    var focusedExamID: UUID?
    var selectedDate: Date = Date()

    private let repository: ExamRepository

    // Expansion horizon for repeating events (2 years forward).
    private let expansionHorizon: Date = Calendar.current.date(
        byAdding: .year, value: 2, to: Date()) ?? Date()

    // MARK: - Preview

    /// Swap PreviewRepository() ↔ LocalExamRepository() to toggle fake data in all canvases.
    static let preview = AppStore(repository: LocalExamRepository())

    // MARK: - Init

    init(repository: ExamRepository) {
        self.repository = repository
        reload()
        focusedExamID = exams.first?.id
        recomputeSchedule()
        autoFillMissingDays()
    }

    // MARK: - Reads

    var focusedExam: Exam? {
        guard let id = focusedExamID else { return exams.first }
        return exams.first(where: { $0.id == id }) ?? exams.first
    }

    func exam(withID id: UUID) -> Exam? {
        exams.first(where: { $0.id == id })
    }

    func hasEvents(on day: Date) -> Bool {
        let hasStudy = scheduledBlocks.values.flatMap { $0 }.contains {
            Calendar.current.isDate($0.date, inSameDayAs: day)
        }
        let hasUser = !expandedUserEvents(on: day).isEmpty
        return hasStudy || hasUser
    }

    func logsForExam(id: UUID) -> [StudyLog] {
        repository.loadLogs()
            .filter { $0.examID == id }
            .sorted { $0.date < $1.date }
    }

    func loggedAmount(examID: UUID, on day: Date) -> Double? {
        repository.loadLogs().first {
            $0.examID == examID &&
            Calendar.current.isDate($0.date, inSameDayAs: day)
        }.map(\.amount)
    }

    func scheduledBlocks(on day: Date) -> [ScheduledBlock] {
        scheduledBlocks.values.flatMap { $0 }
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.date < $1.date }
    }

    func plannedHours(examID: UUID, on day: Date) -> Double? {
        let blocks = scheduledBlocks(on: day).filter { $0.examID == examID }
        guard !blocks.isEmpty else { return nil }
        return blocks.reduce(0) { $0 + $1.duration }
    }

    /// Concrete user events visible on `day`, including expanded repeats.
    func userEvents(on day: Date) -> [UserEvent] {
        expandedUserEvents(on: day).sorted { $0.startDate < $1.startDate }
    }

    /// All concrete occurrences on `day` from all stored events.
    private func expandedUserEvents(on day: Date) -> [UserEvent] {
        userEvents.flatMap { $0.occurrences(on: day) }
    }

    /// All concrete events across all days up to `horizon`,
    /// used by the scheduler to block time slots.
    func allExpandedEvents(upTo horizon: Date = Date().addingTimeInterval(365 * 2 * 86_400)) -> [UserEvent] {
        var result: [UserEvent] = []
        var cursor = Date().startOfDay
        while cursor <= horizon {
            result.append(contentsOf: expandedUserEvents(on: cursor))
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor)
                ?? cursor.addingTimeInterval(86_400)
        }
        return result
    }

    // MARK: - Exam mutations

    func upsert(_ exam: Exam) {
        repository.saveExam(exam)
        reload()
        focusedExamID = exam.id
        recomputeSchedule()
        autoFillMissingDays()
    }

    func delete(examID: UUID) {
        repository.deleteExam(id: examID)
        reload()
        scheduledBlocks.removeValue(forKey: examID)
        if focusedExamID == examID { focusedExamID = exams.first?.id }
        recomputeSchedule()
    }

    // MARK: - Logging

    func logStudy(amount: Double, on date: Date = Date()) {
        guard var exam = focusedExam, amount >= 0 else { return }
        repository.setLog(StudyLog(examID: exam.id, date: date,
                                   amount: amount, unit: exam.unit))
        let total = logsForExam(id: exam.id).reduce(0) { $0 + $1.amount }
        exam.completedAmount = min(exam.totalAmount, total)
        repository.saveExam(exam)
        reload()
        recomputeSchedule()
    }

    // MARK: - User event mutations

    /// Save a brand-new or edited single event (non-repeating, or first save of a series).
    func saveUserEvent(_ event: UserEvent) {
        var e = event
        // If it's a new repeating event, stamp the seriesID and seriesStartDate.
        if e.repeatFrequency != .never && e.seriesID == nil {
            e.seriesID        = UUID()
            e.seriesStartDate = e.startDate
        }
        repository.saveUserEvent(e)
        reload()
        recomputeSchedule()
        autoFillMissingDays()
    }

    /// Delete only this occurrence of a repeating event.
    /// Adds the date to the template's excludedDates.
    func deleteOccurrence(_ event: UserEvent, on day: Date) {
        if event.repeatFrequency != .never {
            // Find the template and add this day to its exclusions.
            var template = event
            template.excludedDates.append(day.startOfDay)
            repository.saveUserEvent(template)
        } else {
            repository.deleteUserEvent(id: event.id)
        }
        reload()
        recomputeSchedule()
        autoFillMissingDays()
    }

    /// Delete this occurrence and all future ones.
    /// For repeating events: stop the series by deleting the template entirely
    /// (since we repeat forever, "all future" = delete the whole series).
    func deleteThisAndFuture(_ event: UserEvent, from day: Date) {
        if event.repeatFrequency != .never {
            // We stop the series: if `day` is the first occurrence, delete
            // the template entirely. Otherwise exclude `day` onward by
            // truncating — simplest approach is delete + re-save a copy
            // that only covers up to (but not including) `day`.
            if Calendar.current.isDate(day.startOfDay,
                                       inSameDayAs: (event.seriesStartDate ?? event.startDate).startOfDay) {
                // Deleting from the very first occurrence = delete the whole series.
                repository.deleteUserEvent(id: event.id)
            } else {
                // Keep the series but stop it on the day before `day`.
                // We do this by marking every date from `day` onward as excluded.
                // Practically: store a "seriesEndDate" by adding an excludedDates
                // sentinel. Simpler: delete old template, save a copy whose
                // seriesStartDate stays the same but we add all future dates as excluded.
                // Even simpler for "repeat forever" semantics: delete the template
                // and save a new non-repeating copy of each past occurrence.
                // → Best approach: just add an endDate concept via excluded sentinel.
                var template = event
                // Add all days from `day` to horizon as excluded.
                var cursor = day.startOfDay
                let limit  = expansionHorizon
                while cursor <= limit {
                    template.excludedDates.append(cursor)
                    cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor)
                        ?? cursor.addingTimeInterval(86_400)
                }
                repository.saveUserEvent(template)
            }
        } else {
            repository.deleteUserEvent(id: event.id)
        }
        reload()
        recomputeSchedule()
        autoFillMissingDays()
    }

    /// Edit only this occurrence. Saves a new one-off event for this day
    /// and excludes this day from the original series.
    func updateOccurrence(_ edited: UserEvent, originalSeries: UserEvent, on day: Date) {
        // Exclude this day from the series.
        var template = originalSeries
        template.excludedDates.append(day.startOfDay)
        repository.saveUserEvent(template)

        // Save the edited occurrence as a standalone event.
        var oneOff = edited
        oneOff.repeatFrequency = .never
        oneOff.seriesID        = nil
        oneOff.seriesStartDate = nil
        oneOff.excludedDates   = []
        oneOff.id              = UUID()
        repository.saveUserEvent(oneOff)

        reload()
        recomputeSchedule()
        autoFillMissingDays()
    }

    /// Edit this occurrence and all future ones.
    /// Stops the old series before `day`, starts a new series from `day`.
    func updateThisAndFuture(_ edited: UserEvent, originalSeries: UserEvent, from day: Date) {
        // Stop old series at day - 1 (exclude day onward).
        var oldTemplate = originalSeries
        var cursor = day.startOfDay
        let limit  = expansionHorizon
        while cursor <= limit {
            oldTemplate.excludedDates.append(cursor)
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor)
                ?? cursor.addingTimeInterval(86_400)
        }
        // If we're editing from the very first occurrence, just replace entirely.
        let isFirstOccurrence = Calendar.current.isDate(
            day.startOfDay,
            inSameDayAs: (originalSeries.seriesStartDate ?? originalSeries.startDate).startOfDay
        )
        if isFirstOccurrence {
            repository.deleteUserEvent(id: originalSeries.id)
        } else {
            repository.saveUserEvent(oldTemplate)
        }

        // Save the edited version as a new series starting from `day`.
        var newSeries = edited
        newSeries.id              = UUID()
        newSeries.seriesID        = UUID()
        newSeries.seriesStartDate = edited.startDate
        newSeries.excludedDates   = []
        repository.saveUserEvent(newSeries)

        reload()
        recomputeSchedule()
        autoFillMissingDays()
    }

    /// Convenience: delete a non-repeating event by ID.
    /// For repeating events use deleteOccurrence or deleteThisAndFuture.
    func deleteUserEvent(id: UUID) {
        repository.deleteUserEvent(id: id)
        reload()
        recomputeSchedule()
        autoFillMissingDays()
    }

    // MARK: - Auto-fill past days

    /// Previously back-filled unlogged past study days with an estimated
    /// amount so progress always looked "on track." This made the app
    /// overstate progress for days the user never actually logged.
    ///
    /// Now a no-op: unlogged past days simply have no log entry, so
    /// `loggedAmount` returns nil for them, `completedAmount` reflects only
    /// real logged amounts, and the UI can show a "Not logged" indicator.
    /// Kept as a method (rather than removed) since it's called from
    /// scenePhase changes and after every mutation — removing those call
    /// sites isn't necessary now that this does nothing.
    func autoFillMissingDays() {
        // Intentionally empty.
    }

    // MARK: - Schedule recomputation

    func recomputeSchedule() {
        var newBlocks: [UUID: [ScheduledBlock]] = [:]
        var anyOverflow = false
        for exam in exams {
            // Pass all expanded events so the scheduler blocks repeat slots too.
            let result = StudyScheduler.schedule(
                exam: exam,
                logs: logsForExam(id: exam.id),
                userEvents: userEvents   // scheduler calls occurrences(on:) internally
            )
            newBlocks[exam.id] = result.blocks
            if result.overflowsExam { anyOverflow = true }
        }
        scheduledBlocks   = newBlocks
        planOverflowsExam = anyOverflow
    }

    // MARK: - Focus helpers

    func focusNextExam() {
        guard !exams.isEmpty else { return }
        let idx = exams.firstIndex(where: { $0.id == focusedExamID }) ?? 0
        focusedExamID = exams[(idx + 1) % exams.count].id
    }

    func focusPreviousExam() {
        guard !exams.isEmpty else { return }
        let idx = exams.firstIndex(where: { $0.id == focusedExamID }) ?? 0
        focusedExamID = exams[(idx - 1 + exams.count) % exams.count].id
    }

    // MARK: - Private

    private func reload() {
        exams      = repository.loadExams().sorted { $0.date < $1.date }
        userEvents = repository.loadUserEvents()
    }
}
