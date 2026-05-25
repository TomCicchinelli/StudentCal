//
//  CalendarTabView.swift
//  StudyPlanner
//

import SwiftUI

struct CalendarTabView: View {
    @Environment(AppStore.self) private var store

    enum CalendarMode { case month, day }
    @State private var mode: CalendarMode = .day
    @State private var selectedDate: Date = Date()
    @State private var showDayView: Bool = false
    @State private var showNewEvent: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .day:
                    CalendarDayView(selectedDate: $selectedDate)
                case .month:
                    CalendarMonthView(selectedDate: $selectedDate, showDayView: $showDayView)
                        .onChange(of: showDayView) { _, newValue in
                            if newValue { mode = .day; showDayView = false }
                        }
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showNewEvent) {
                EventFormView(mode: .create(defaultDate: selectedDate))
            }
        }
    }

    private var titleText: String {
        switch mode {
        case .day:   return DateFormatters.monthName.string(from: selectedDate)
        case .month: return String(Calendar.current.component(.year, from: Date()))
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(mode == .day ? "Month" : "Day") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    mode = (mode == .day) ? .month : .day
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.appAccent)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showNewEvent = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.appAccentSoft))
            }
        }
    }
}

#Preview {
    CalendarTabView()
        .environment(AppStore(repository: LocalExamRepository()))
}
