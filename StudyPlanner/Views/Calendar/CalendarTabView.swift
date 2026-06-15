//
//  CalendarTabView.swift
//  StudyPlanner
//

import SwiftUI

struct CalendarTabView: View {
    @Environment(AppStore.self) private var store
    @Binding var selectedTab: MainTabView.Tab

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
        // Returning to the Calendar tab from elsewhere always jumps back to
        // today and the day view, rather than leaving you on whatever
        // date/mode you last viewed.
        .onChange(of: selectedTab) { _, newTab in
            guard newTab == .calendar else { return }
            selectedDate = Date()
            mode = .day
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
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showNewEvent = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("New personal event")
        }
    }
}

#Preview {
    CalendarTabView(selectedTab: .constant(.calendar))
        .environment(AppStore(repository: LocalExamRepository()))
}
