//
//  CalendarMonthView.swift
//  StudyPlanner
//

import SwiftUI

struct CalendarMonthView: View {
    @Environment(AppStore.self) private var store
    @Binding var selectedDate: Date
    @Binding var showDayView: Bool

    private var months: [Date] {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        return (1...12).compactMap {
            cal.date(from: DateComponents(year: year, month: $0, day: 1))
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    ForEach(months, id: \.self) { monthStart in
                        MonthGridView(
                            monthStart: monthStart,
                            selectedDate: $selectedDate,
                            onDayTap: { day in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selectedDate = day
                showDayView = true
            },
                            hasDot: { day in store.hasEvents(on: day) }
                        )
                        .id(Calendar.current.component(.month, from: monthStart))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .onAppear {
                proxy.scrollTo(Calendar.current.component(.month, from: Date()), anchor: .top)
            }
        }
    }
}

// MARK: - Month grid

private struct MonthGridView: View {
    let monthStart: Date
    @Binding var selectedDate: Date
    let onDayTap: (Date) -> Void
    let hasDot: (Date) -> Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdayHeaders = ["M","T","W","T","F","S","S"]

    private var days: [Date?] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday  = cal.component(.weekday, from: monthStart)
        let leadingBlanks = (firstWeekday + 5) % 7
        return (0..<leadingBlanks).map { _ in nil } +
            range.map { day -> Date? in cal.date(bySetting: .day, value: day, of: monthStart) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(DateFormatters.monthName.string(from: monthStart))
                .font(.system(size: 20, weight: .bold, design: .rounded))

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(weekdayHeaders.enumerated()), id: \.offset) { _, lbl in
                    Text(lbl)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .frame(height: 28)
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, optDay in
                    if let day = optDay {
                        DayCell(
                            day: day,
                            isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate),
                            isToday: Calendar.current.isDateInToday(day),
                            hasDot: hasDot(day),
                            onTap: { onDayTap(day) }
                        )
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }
        }
    }
}

// MARK: - Day cell

private struct DayCell: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let hasDot: Bool
    let onTap: () -> Void

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: day))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                ZStack {
                    // Selected background
                    Circle()
                        .fill(isSelected ? Color.appAccent : Color.clear)
                        .frame(width: 34, height: 34)

                    // Today ring when not selected
                    if isToday && !isSelected {
                        Circle()
                            .stroke(Color.appAccent, lineWidth: 1.5)
                            .frame(width: 34, height: 34)
                    }

                    Text(dayNumber)
                        .font(.system(size: 15,
                                      weight: isToday ? .bold : .regular,
                                      design: .rounded))
                        .foregroundStyle(
                            isSelected ? Color.white :
                            isToday    ? Color.appAccent :
                            Color.primary
                        )
                }

                Circle()
                    .fill(hasDot && !isSelected ? Color.appAccent : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(height: 46)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    CalendarMonthView(selectedDate: .constant(Date()), showDayView: .constant(false))
        .environment(AppStore(repository: LocalExamRepository()))
}
