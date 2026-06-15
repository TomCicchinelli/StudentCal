//
//  StudyScheduler.swift
//  StudyPlanner
//
//  Algorithm
//  ─────────
//  Slots within each day are sorted biggest → smallest.
//  Each pass adds 1 h to every day starting from the front of its
//  current active slot (biggest first). When a slot is full the cursor
//  advances to the next slot automatically on the next pass.
//  No day waits for another — every day progresses in parallel.
//

import Foundation

// MARK: - Output

struct ScheduledBlock: Identifiable, Hashable {
    let id: UUID
    let examID: UUID
    let date: Date
    let duration: Double

    var endDate: Date { date.addingTimeInterval(duration * 3_600) }
}

// MARK: - Scheduler

enum StudyScheduler {

    static func schedule(
        exam: Exam,
        logs: [StudyLog],
        userEvents: [UserEvent],
        now: Date = Date()
    ) -> (blocks: [ScheduledBlock], overflowsExam: Bool) {

        // ── 1. Hours remaining ───────────────────────────────────────────
        let totalHours: Double = {
            switch exam.unit {
            case .hours: return exam.totalAmount
            case .pages: return exam.pagesPerHour > 0
                ? exam.totalAmount / exam.pagesPerHour : 0
            }
        }()

        let todayStart  = now.startOfDay
        let credited    = logs
            .filter { $0.date.startOfDay < todayStart }
            .reduce(0.0) { $0 + hoursFromLog($1, exam: exam) }
        var remaining   = max(0, totalHours - credited)

        let todayLogged = logs
            .filter { Calendar.current.isDate($0.date, inSameDayAs: todayStart) }
            .reduce(0.0) { $0 + hoursFromLog($1, exam: exam) }
        remaining = max(0, remaining - todayLogged)

        guard remaining > 0 else { return ([], false) }

        // ── 2. Eligible days ─────────────────────────────────────────────
        let examDay  = exam.date.startOfDay
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: todayStart)!

        var eligibleDays: [Date] = [todayStart]
        var cur = tomorrow
        while cur < examDay {
            eligibleDays.append(cur)
            cur = Calendar.current.date(byAdding: .day, value: 1, to: cur)!
        }
        eligibleDays = eligibleDays.filter {
            guard let wd = $0.weekday else { return false }
            return exam.studyDays.contains(wd)
        }

        // ── 3. Build free slots per day, biggest first ───────────────────
        struct DayState {
            let day: Date
            var slots: [TimeSlot]       // sorted biggest → smallest
            // allocations[i] = hours placed into slots[i]
            var allocations: [Double]

            var currentSlotIdx: Int {
                // First slot not yet completely filled.
                allocations.indices.first { allocations[$0] < slots[$0].length - 0.001 }
                ?? slots.count   // all full
            }
            var isFull: Bool { currentSlotIdx >= slots.count }
        }

        var states: [DayState] = eligibleDays.compactMap { day in
            let isToday = Calendar.current.isDate(day, inSameDayAs: todayStart)
            let iStart  = isToday
                ? max(exam.studyInterval.startHour, currentHourCeiling(now))
                : exam.studyInterval.startHour
            let iEnd    = exam.studyInterval.endHour
            guard iEnd > iStart else { return nil }

            // Use occurrences(on:) so repeating events also block time slots.
            let blocked: [ClosedRange<Double>] = userEvents
                .flatMap { $0.occurrences(on: day) }
                .map { fractionalHour(from: $0.startDate)...fractionalHour(from: $0.endDate) }

            var free = buildFreeSlots(from: Double(iStart), to: Double(iEnd),
                                       blocking: blocked)
            guard !free.isEmpty else { return nil }

            // Biggest slot first.
            free.sort { $0.length > $1.length }

            return DayState(day: day, slots: free,
                            allocations: Array(repeating: 0, count: free.count))
        }

        // ── 4. Round-robin fill ──────────────────────────────────────────
        let increment = 1.0
        let minChunk  = 0.25
        var overflow  = false
        var safety    = 100_000

        while remaining > 0.001 && safety > 0 {
            safety -= 1
            var addedThisPass = false

            for i in states.indices {
                guard remaining > 0.001 else { break }
                let si = states[i].currentSlotIdx
                guard si < states[i].slots.count else { continue }   // day full

                let slot     = states[i].slots[si]
                let used     = states[i].allocations[si]
                let slotLeft = slot.length - used
                var chunk    = min(increment, min(remaining, slotLeft))

                // Normally skip slivers smaller than minChunk (don't carve a
                // 2-minute block into a day). But if `remaining` itself is
                // the final sliver of the whole exam — less than minChunk
                // overall — and this slot has room for it, allocate it
                // anyway. Otherwise that last fraction of a page/hour gets
                // dropped and incorrectly reported as overflow even though
                // it plainly fits in the available time.
                if chunk < minChunk {
                    if remaining < minChunk && slotLeft >= remaining {
                        chunk = remaining
                    } else {
                        continue
                    }
                }

                states[i].allocations[si] += chunk
                remaining                 -= chunk
                addedThisPass              = true
            }

            if !addedThisPass { overflow = true; break }
        }

        if remaining > 0.001 { overflow = true }

        // ── 5. Emit blocks ───────────────────────────────────────────────
        var blocks: [ScheduledBlock] = []

        for state in states {
            for (si, slot) in state.slots.enumerated() {
                let hours = state.allocations[si]
                // Use the same epsilon as the allocation loop (0.001) rather
                // than minChunk here — a slot can legitimately end up holding
                // just the final sub-minChunk sliver of the exam's remaining
                // work (see step 4), and dropping it here would silently lose
                // that time from the schedule even though it was counted as
                // "not overflowing".
                guard hours > 0.001 else { continue }

                let start = state.day.setting(
                    hour:   Int(slot.start),
                    minute: Int((slot.start.truncatingRemainder(dividingBy: 1)) * 60)
                )
                blocks.append(ScheduledBlock(
                    id: UUID(), examID: exam.id,
                    date: start, duration: hours
                ))
            }
        }

        return (blocks, overflow)
    }

    // MARK: - Helpers

    private static func hoursFromLog(_ log: StudyLog, exam: Exam) -> Double {
        switch log.unit {
        case .hours: return log.amount
        case .pages: return exam.pagesPerHour > 0 ? log.amount / exam.pagesPerHour : 0
        }
    }

    static func fractionalHour(from date: Date) -> Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60.0
    }

    private static func currentHourCeiling(_ now: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return (c.minute ?? 0) == 0 ? (c.hour ?? 0) : (c.hour ?? 0) + 1
    }

    private static func buildFreeSlots(from start: Double,
                                        to end: Double,
                                        blocking: [ClosedRange<Double>]) -> [TimeSlot] {
        var free = [TimeSlot(start: start, end: end)]
        for b in blocking.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            free = free.flatMap { $0.subtracting(b) }
        }
        return free.filter { $0.length >= 0.25 }
    }
}

// MARK: - TimeSlot

struct TimeSlot: Hashable {
    var start: Double
    var end:   Double
    var length: Double { end - start }

    func subtracting(_ b: ClosedRange<Double>) -> [TimeSlot] {
        if b.upperBound <= start || b.lowerBound >= end { return [self] }
        var r: [TimeSlot] = []
        if start < b.lowerBound { r.append(TimeSlot(start: start, end: b.lowerBound)) }
        if b.upperBound < end   { r.append(TimeSlot(start: b.upperBound, end: end))   }
        return r
    }
}

private extension Date {
    func setting(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: self) ?? self
    }
}
