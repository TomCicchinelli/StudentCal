//
//  UserEvent.swift
//  StudyPlanner
//

import Foundation
import SwiftUI

enum RepeatFrequency: String, Codable, CaseIterable, Identifiable {
    case never   = "Never"
    case daily   = "Daily"
    case weekly  = "Weekly"
    case monthly = "Monthly"
    var id: String { rawValue }

    /// Calendar component to advance by one repeat unit.
    var calendarComponent: Calendar.Component? {
        switch self {
        case .never:   return nil
        case .daily:   return .day
        case .weekly:  return .weekOfYear
        case .monthly: return .month
        }
    }
}

enum EventColor: Codable, Hashable, Identifiable {
    case preset(Preset)
    case custom(hex: String)

    enum Preset: String, Codable, CaseIterable, Identifiable {
        case red    = "Red"
        case orange = "Orange"
        case yellow = "Yellow"
        case green  = "Green"
        case teal   = "Teal"
        case blue   = "Blue"
        case indigo = "Indigo"
        case purple = "Purple"
        case pink   = "Pink"
        case rose   = "Rose"

        var id: String { rawValue }

        var swiftUIColor: Color {
            switch self {
            case .red:    return Color(red: 0.93, green: 0.18, blue: 0.18)
            case .orange: return Color(red: 1.00, green: 0.58, blue: 0.00)
            case .yellow: return Color(red: 0.98, green: 0.80, blue: 0.10)
            case .green:  return Color(red: 0.18, green: 0.78, blue: 0.25)
            case .teal:   return Color(red: 0.06, green: 0.67, blue: 0.56)
            case .blue:   return Color(red: 0.00, green: 0.48, blue: 1.00)
            case .indigo: return Color(red: 0.31, green: 0.28, blue: 0.90)
            case .purple: return Color(red: 0.55, green: 0.18, blue: 0.90)
            case .pink:   return Color(red: 1.00, green: 0.22, blue: 0.60)
            case .rose:   return Color(red: 0.95, green: 0.30, blue: 0.45)
            }
        }
    }

    var id: String {
        switch self {
        case .preset(let p): return "preset_\(p.rawValue)"
        case .custom(let h): return "custom_\(h)"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .preset(let p): return p.swiftUIColor
        case .custom(let h): return Color(hex: h) ?? .appAccent
        }
    }

    var displayName: String {
        switch self {
        case .preset(let p): return p.rawValue
        case .custom(let h): return "#\(h.uppercased())"
        }
    }

    private enum CodingKeys: String, CodingKey { case type, preset, hex }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .preset(let p):
            try c.encode("preset", forKey: .type)
            try c.encode(p, forKey: .preset)
        case .custom(let h):
            try c.encode("custom", forKey: .type)
            try c.encode(h, forKey: .hex)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "preset": self = .preset(try c.decode(Preset.self, forKey: .preset))
        case "custom": self = .custom(hex: try c.decode(String.self, forKey: .hex))
        default:       self = .preset(.blue)
        }
    }
}

extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >>  8) & 0xFF) / 255,
            blue:  Double( value        & 0xFF) / 255
        )
    }

    var hexString: String? {
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else { return nil }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

// MARK: - UserEvent

struct UserEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var repeatFrequency: RepeatFrequency
    var eventColor: EventColor
    var notes: String

    /// All occurrences of a repeated series share this ID.
    /// nil = non-repeating event.
    var seriesID: UUID?

    /// For a repeated series: the start date of the original (first) event.
    /// Used to correctly expand occurrences forward in time.
    var seriesStartDate: Date?

    /// Exceptions: dates (startOfDay) where this series has been
    /// individually deleted or modified. Stored on the template event.
    var excludedDates: [Date]

    init(
        id: UUID = UUID(),
        title: String = "",
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(7200),
        repeatFrequency: RepeatFrequency = .never,
        eventColor: EventColor = .preset(.red),
        notes: String = "",
        seriesID: UUID? = nil,
        seriesStartDate: Date? = nil,
        excludedDates: [Date] = []
    ) {
        self.id              = id
        self.title           = title
        self.startDate       = startDate
        self.endDate         = endDate
        self.repeatFrequency = repeatFrequency
        self.eventColor      = eventColor
        self.notes           = notes
        self.seriesID        = seriesID
        self.seriesStartDate = seriesStartDate
        self.excludedDates   = excludedDates
    }

    /// Duration of the event in seconds.
    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }

    /// Whether this event is the template (first) of a series.
    var isSeriesTemplate: Bool {
        seriesID != nil && repeatFrequency != .never
    }
}

// MARK: - Repeat expansion helper

extension UserEvent {

    /// Expand this repeating event into concrete occurrences that fall on `day`.
    /// Returns an array (0 or 1 elements — at most one occurrence per day
    /// for daily/weekly/monthly) with dates set to the actual occurrence time.
    func occurrences(on day: Date) -> [UserEvent] {
        guard repeatFrequency != .never,
              repeatFrequency.calendarComponent != nil else {
            // Non-repeating: check if this event itself falls on day.
            if Calendar.current.isDate(startDate, inSameDayAs: day) {
                return [self]
            }
            return []
        }

        let dayStart = day.startOfDay
        let cal      = Calendar.current

        // The series starts on startDate — find the occurrence on `day` if any.
        // Advance from seriesStart by N units until we reach or pass `day`.
        let base = seriesStartDate ?? startDate

        // For weekly: check if `day` is the same weekday as the series start.
        // For monthly: check if `day` has the same day-of-month.
        // For daily: every day.
        let occurrenceStart: Date? = {
            switch repeatFrequency {
            case .never: return nil

            case .daily:
                // Any day on or after series start is valid.
                guard dayStart >= base.startOfDay else { return nil }
                return cal.date(bySettingHour: cal.component(.hour, from: base),
                                minute: cal.component(.minute, from: base),
                                second: 0, of: day)

            case .weekly:
                // Same weekday as base.
                let baseWeekday = cal.component(.weekday, from: base)
                let dayWeekday  = cal.component(.weekday, from: day)
                guard baseWeekday == dayWeekday, dayStart >= base.startOfDay else { return nil }
                return cal.date(bySettingHour: cal.component(.hour, from: base),
                                minute: cal.component(.minute, from: base),
                                second: 0, of: day)

            case .monthly:
                // Same day-of-month as base.
                let baseDayOfMonth = cal.component(.day, from: base)
                let dayDayOfMonth  = cal.component(.day, from: day)
                guard baseDayOfMonth == dayDayOfMonth, dayStart >= base.startOfDay else { return nil }
                return cal.date(bySettingHour: cal.component(.hour, from: base),
                                minute: cal.component(.minute, from: base),
                                second: 0, of: day)
            }
        }()

        guard let start = occurrenceStart else { return [] }

        // Check exclusions.
        let excluded = excludedDates.contains { cal.isDate($0, inSameDayAs: day) }
        if excluded { return [] }

        var occurrence = self
        occurrence.startDate = start
        occurrence.endDate   = start.addingTimeInterval(duration)
        return [occurrence]
    }

    /// All time ranges this event occupies on `day` (for scheduler blocking).
    func blockedRanges(on day: Date) -> [ClosedRange<Double>] {
        occurrences(on: day).map { occ in
            let s = StudyScheduler.fractionalHour(from: occ.startDate)
            let e = StudyScheduler.fractionalHour(from: occ.endDate)
            return s...e
        }
    }
}
