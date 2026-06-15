//
//  ExamOnboardingView.swift
//  StudyPlanner
//
//  Conversational, step-by-step exam setup. Replaces the old all-fields-at-once
//  create form. Study interval is NOT asked here — it defaults to
//  StudyInterval.default (9–17) and can be changed later from the edit screen.
//

import SwiftUI

struct ExamOnboardingView: View {
    var canCancel: Bool = false

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    // MARK: - Steps

    private enum Step: Int, CaseIterable {
        case nameAndDate
        case unit
        case amounts
        case studyDays
    }

    @State private var step: Step = .nameAndDate

    // MARK: - Answers

    @State private var name: String = ""
    @State private var date: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var unit: StudyUnit = .pages
    @State private var totalPagesText: String = ""
    @State private var pagesPerHourText: String = ""
    @State private var totalHoursText: String = ""
    @State private var studyDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var showPastDateWarning: Bool = false

    @FocusState private var focusedField: Field?
    private enum Field { case name, totalPages, pagesPerHour, totalHours }

    // MARK: - Validation per step

    private var canAdvance: Bool {
        switch step {
        case .nameAndDate:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .unit:
            return true
        case .amounts:
            switch unit {
            case .pages: return (Double(totalPagesText) ?? 0) > 0 && (Double(pagesPerHourText) ?? 0) > 0
            case .hours: return (Double(totalHoursText) ?? 0) > 0
            }
        case .studyDays:
            return !studyDays.isEmpty
        }
    }

    private var isLastStep: Bool { step == Step.allCases.last }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressDots

                ScrollView {
                    VStack(spacing: 24) {
                        // Study days has 7 rows plus header/helper text — skip
                        // the top spacer here so everything fits without
                        // scrolling on smaller screens.
                        if step != .studyDays {
                            Spacer(minLength: 24)
                        }

                        switch step {
                        case .nameAndDate: nameAndDateStep
                        case .unit:        unitStep
                        case .amounts:     amountsStep
                        case .studyDays:   studyDaysStep
                        }

                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, step == .studyDays ? 8 : 0)
                    .animation(.easeOut(duration: 0.25), value: step)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollDisabled(step == .studyDays)

                footer
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if canCancel {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(Color.appAccent)
                    } else if step != .nameAndDate {
                        Button {
                            withAnimation { goBack() }
                        } label: {
                            Image(systemName: "chevron.left")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .foregroundStyle(Color.appAccent)
                    }
                }
            }
        }
        // Tap anywhere outside a text field to dismiss the keyboard/numpad.
        // simultaneousGesture (not onTapGesture) so it doesn't block taps
        // on buttons, the date picker, or other controls underneath.
        .simultaneousGesture(
            TapGesture().onEnded {
                focusedField = nil
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        )
    }

    // MARK: - Progress

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Color.appAccent : Color(.systemGray5))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .animation(.easeOut(duration: 0.25), value: step)
    }

    // MARK: - Step 1: name + date

    private var nameAndDateStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            questionHeader("What exam are you preparing for?")

            Text("This helps us label your study sessions and plan.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            TextField("e.g. Calculus I", text: $name)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .focused($focusedField, equals: .name)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(name.isEmpty ? Color(.systemGray4) : Color.appAccent.opacity(0.5), lineWidth: 1)
                )
                .submitLabel(.next)
                .onSubmit { advanceIfPossible() }

            HStack {
                Text("When is it?")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker("", selection: $date, in: Date()..., displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Color.appAccent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(showPastDateWarning ? Color.red : Color(.systemGray4), lineWidth: showPastDateWarning ? 1.5 : 1)
            )
            .onChange(of: date) { _, newDate in
                if newDate.startOfDay < Date().startOfDay {
                    withAnimation { showPastDateWarning = true }
                    date = Date()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showPastDateWarning = false }
                    }
                }
            }

            if showPastDateWarning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Please select a future date")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.red)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Step 2: unit

    private var unitStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            questionHeader("How do you want to track your progress?")

            Text("Pick whichever feels more natural — you can always change it later.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                choiceCard(
                    title: "Pages",
                    subtitle: "Good for textbooks and readings",
                    icon: "book.pages",
                    isSelected: unit == .pages
                ) { unit = .pages }

                choiceCard(
                    title: "Total hours",
                    subtitle: "Good for revision or problem sets",
                    icon: "clock",
                    isSelected: unit == .hours
                ) { unit = .hours }
            }
        }
    }

    // MARK: - Step 3: amounts

    private var amountsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            if unit == .pages {
                questionHeader("How many pages do you need to cover?")

                amountField(text: $totalPagesText, placeholder: "e.g. 200", suffix: "pages",
                            integer: true, field: .totalPages)

                Text("How many pages do you study in an hour?")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .padding(.top, 8)

                Text("A rough guess is fine — you can adjust this later as you go.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                amountField(text: $pagesPerHourText, placeholder: "e.g. 5", suffix: "pages / hour",
                            integer: false, field: .pagesPerHour)
            } else {
                questionHeader("How many hours do you need in total?")

                Text("A rough estimate is fine for now.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                amountField(text: $totalHoursText, placeholder: "e.g. 60", suffix: "hours",
                            integer: true, field: .totalHours)
            }
        }
    }

    private func amountField(text: Binding<String>, placeholder: String, suffix: String,
                              integer: Bool, field: Field) -> some View {
        HStack {
            TextField(placeholder, text: text)
                .keyboardType(integer ? .numberPad : .decimalPad)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .focused($focusedField, equals: field)
            Text(suffix)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke((Double(text.wrappedValue) ?? 0) > 0 ? Color.appAccent.opacity(0.5) : Color(.systemGray4), lineWidth: 1)
        )
    }

    // MARK: - Step 4: study days

    private var studyDaysStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            questionHeader("Which days work best for studying?")

            Text("Pick the days you'd like to study — we'll build your plan around them.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(Weekday.displayOrder) { day in
                    let selected = studyDays.contains(day)
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        if selected { studyDays.remove(day) } else { studyDays.insert(day) }
                    } label: {
                        HStack {
                            Text(fullLabel(for: day))
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(selected ? Color.appAccent : Color(.systemGray4))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selected ? Color.appAccentSoft : Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selected ? Color.appAccent.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                        .foregroundStyle(Color.primary)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeOut(duration: 0.15), value: selected)
                }
            }

            Text("You can fine-tune your daily study window later from the edit screen.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private func fullLabel(for day: Weekday) -> String {
        switch day {
        case .monday:    return "Monday"
        case .tuesday:   return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday:  return "Thursday"
        case .friday:    return "Friday"
        case .saturday:  return "Saturday"
        case .sunday:    return "Sunday"
        }
    }

    // MARK: - Shared subviews

    private func questionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func choiceCard(title: String, subtitle: String, icon: String,
                             isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.appAccent : Color(.tertiarySystemFill))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Color.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
                Spacer(minLength: 8)
                // Reserve the checkmark's space even when unselected, so
                // selecting a card doesn't shrink the title/subtitle column
                // and cause the subtitle to wrap.
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.appAccent)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.appAccent.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
            .foregroundStyle(Color.primary)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Footer

    private var footer: some View {
        Button {
            if isLastStep {
                if canAdvance { save() }
            } else {
                advanceIfPossible()
            }
        } label: {
            Text(isLastStep ? "Create exam" : "Continue")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(canAdvance ? Color.appAccent : Color(.systemGray4))
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!canAdvance)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24 + 49)   // clear the floating tab bar in MainTabView, with extra breathing room
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Navigation

    private func advanceIfPossible() {
        guard canAdvance else { return }
        focusedField = nil
        if let next = Step(rawValue: step.rawValue + 1) {
            withAnimation(.easeOut(duration: 0.25)) { step = next }
        }
    }

    private func goBack() {
        focusedField = nil
        if let prev = Step(rawValue: step.rawValue - 1) {
            step = prev
        } else {
            dismiss()
        }
    }

    // MARK: - Save

    private func save() {
        let total: Double = unit == .pages ? (Double(totalPagesText) ?? 0) : (Double(totalHoursText) ?? 0)
        let pph = Double(pagesPerHourText) ?? 5

        store.upsert(Exam(
            name: name.trimmingCharacters(in: .whitespaces),
            date: date,
            studyInterval: .default,
            unit: unit,
            totalAmount: total,
            pagesPerHour: pph,
            completedAmount: 0,
            studyDays: studyDays
        ))
        dismiss()
    }
}

#Preview {
    ExamOnboardingView()
        .environment(AppStore(repository: LocalExamRepository()))
}
