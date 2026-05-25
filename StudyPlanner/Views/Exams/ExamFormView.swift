//
//  ExamFormView.swift
//  StudyPlanner
//

import SwiftUI

struct ExamFormView: View {
    enum Mode: Equatable {
        case create
        case edit(Exam)
    }

    let mode: Mode
    var canCancel: Bool = true

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var date: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var interval: StudyInterval = .default
    @State private var unit: StudyUnit = .pages
    @State private var totalPagesText: String = ""
    @State private var pagesPerHourText: String = ""
    @State private var totalHoursText: String = ""
    @State private var studyDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var showDeleteConfirm  = false
    @State private var showIntervalInfo   = false
    @State private var showCustomInterval = false
    @State private var showValidationErrors = false

    private var isEditing: Bool { if case .edit = mode { return true }; return false }
    private var editingExamID: UUID? { if case let .edit(e) = mode { return e.id }; return nil }

    private var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard !studyDays.isEmpty else { return false }
        guard interval.endHour > interval.startHour else { return false }
        switch unit {
        case .pages: return (Double(totalPagesText) ?? 0) > 0 && (Double(pagesPerHourText) ?? 0) > 0
        case .hours: return (Double(totalHoursText) ?? 0) > 0
        }
    }

    /// Human-readable list of what's missing.
    var validationErrors: [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Exam name is required")
        }
        if studyDays.isEmpty {
            errors.append("Select at least one study day")
        }
        if interval.endHour <= interval.startHour {
            errors.append("Study interval end must be after start")
        }
        switch unit {
        case .pages:
            if (Double(totalPagesText) ?? 0) <= 0 { errors.append("Total pages must be greater than 0") }
            if (Double(pagesPerHourText) ?? 0) <= 0 { errors.append("Pages per hour must be greater than 0") }
        case .hours:
            if (Double(totalHoursText) ?? 0) <= 0 { errors.append("Total hours must be greater than 0") }
        }
        return errors
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Name ──────────────────────────────────────────────
                    card {
                        VStack(alignment: .leading, spacing: 8) {
                            label("Exam name")
                            TextField("e.g. Calculus I", text: $name)
                                .font(.system(size: 16))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            showValidationErrors && name.trimmingCharacters(in: .whitespaces).isEmpty
                                                ? Color.red
                                                : (!name.isEmpty ? Color.appAccent.opacity(0.5) : Color(.systemGray4)),
                                            lineWidth: showValidationErrors && name.trimmingCharacters(in: .whitespaces).isEmpty ? 1.5 : 1
                                        )
                                )
                        }
                    }

                    // ── Date + Interval ───────────────────────────────────
                    card(invalid: showValidationErrors && interval.endHour <= interval.startHour) {
                        VStack(spacing: 14) {
                            HStack {
                                label("Exam date")
                                Spacer()
                                DatePicker("", selection: $date, in: Date()..., displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .tint(Color.appAccent)
                            }

                            Divider().opacity(0.5)

                            HStack {
                                HStack(spacing: 4) {
                                    label("Study interval")
                                    Button { showIntervalInfo = true } label: {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.appAccent.opacity(0.7))
                                    }
                                }
                                Spacer()
                                IntervalPicker(interval: $interval, showCustomInterval: $showCustomInterval)
                            }

                            if showCustomInterval {
                                HStack(spacing: 16) {
                                    customHourPicker(label: "From", selection: $interval.startHour, range: 0...23)
                                    customHourPicker(label: "To",   selection: $interval.endHour,   range: 1...24)
                                }
                                .onChange(of: interval.startHour) { _, newStart in
                                    if interval.endHour <= newStart { interval.endHour = newStart + 1 }
                                }
                            }
                        }
                    }

                    // ── Unit + Amounts ────────────────────────────────────
                    card(invalid: showValidationErrors && {
                        switch unit {
                        case .pages: return (Double(totalPagesText) ?? 0) <= 0 || (Double(pagesPerHourText) ?? 0) <= 0
                        case .hours: return (Double(totalHoursText) ?? 0) <= 0
                        }
                    }()) {
                        VStack(spacing: 14) {
                            Picker("Unit", selection: $unit) {
                                Text("Pages").tag(StudyUnit.pages)
                                Text("Total hours").tag(StudyUnit.hours)
                            }
                            .pickerStyle(.segmented)
                            .tint(Color.appAccent)

                            Divider().opacity(0.5)

                            if unit == .pages {
                                HStack {
                                    label("Total pages")
                                    Spacer()
                                    NumberStepperField(text: $totalPagesText, integer: true, placeholder: "e.g. 200")
                                        .frame(width: 140)
                                }
                                Divider().opacity(0.5)
                                HStack {
                                    label("Pages per hour")
                                    Spacer()
                                    NumberStepperField(text: $pagesPerHourText, integer: false, placeholder: "e.g. 5")
                                        .frame(width: 140)
                                }
                            } else {
                                HStack {
                                    label("Total hours")
                                    Spacer()
                                    NumberStepperField(text: $totalHoursText, integer: true, placeholder: "e.g. 60")
                                        .frame(width: 140)
                                }
                            }
                        }
                    }

                    // ── Study days ────────────────────────────────────────
                    card(invalid: showValidationErrors && studyDays.isEmpty) {
                        VStack(alignment: .leading, spacing: 12) {
                            label("Study days")
                            StudyDaysSelector(selection: $studyDays)
                        }
                    }

                    // ── Validation errors ────────────────────────────────
                    if showValidationErrors && !validationErrors.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(validationErrors, id: \.self) { error in
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(Color.red)
                                        .font(.system(size: 13))
                                    Text(error)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.red)
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.08))
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // ── Actions ───────────────────────────────────────────
                    if isEditing {
                        HStack(spacing: 12) {
                            Button(role: .destructive) { showDeleteConfirm = true } label: {
                                Label("Delete", systemImage: "trash")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.red.opacity(0.7), lineWidth: 1)
                                    )
                                    .foregroundStyle(.red)
                            }
                            Button {
                                if isValid { save() }
                                else { withAnimation { showValidationErrors = true } }
                            } label: {
                                Label("Save", systemImage: "checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.appAccent)
                                    )
                                    .foregroundStyle(.white)
                            }
                        }
                    } else {
                        Button {
                            if isValid { save() }
                            else { withAnimation { showValidationErrors = true } }
                        } label: {
                            Text("Add exam")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.appAccent)
                                )
                                .foregroundStyle(.white)
                        }
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)  // extra clearance for tab bar when embedded
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing && canCancel { Button("Cancel") { dismiss() }.foregroundStyle(Color.appAccent) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !isEditing && canCancel { Button("Cancel") { dismiss() }.foregroundStyle(Color.appAccent) }
                }
            }
            .onAppear(perform: prefill)
            .alert("Delete exam?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let id = editingExamID { store.delete(examID: id) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will also remove all study sessions. This cannot be undone.")
            }
            .alert("Study interval", isPresented: $showIntervalInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The hours you're available to study each day.")
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func card<Content: View>(invalid: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(invalid ? Color.red : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeOut(duration: 0.2), value: invalid)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func customHourPicker(label text: String, selection: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 4) {
            Text(text).font(.caption).foregroundStyle(.secondary)
            Picker("", selection: selection) {
                ForEach(Array(range), id: \.self) { h in
                    Text(hourLabel(h)).tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .clipped()
        }
    }

    // MARK: - Logic

    private func prefill() {
        guard case let .edit(exam) = mode else { return }
        name             = exam.name
        date             = exam.date
        interval         = exam.studyInterval
        unit             = exam.unit
        totalPagesText   = fmt(exam.totalAmount, integer: unit == .pages)
        pagesPerHourText = fmt(exam.pagesPerHour, integer: false)
        totalHoursText   = fmt(exam.totalAmount, integer: true)
        studyDays        = exam.studyDays
        let presets: [StudyInterval] = [
            StudyInterval(startHour: 6,  endHour: 12),
            StudyInterval(startHour: 9,  endHour: 17),
            StudyInterval(startHour: 12, endHour: 18),
            StudyInterval(startHour: 14, endHour: 20),
            StudyInterval(startHour: 18, endHour: 23)
        ]
        showCustomInterval = !presets.contains(exam.studyInterval)
    }

    private func save() {
        let id = editingExamID ?? UUID()
        let total: Double = unit == .pages ? (Double(totalPagesText) ?? 0) : (Double(totalHoursText) ?? 0)
        let pph = Double(pagesPerHourText) ?? 5
        let completed: Double = {
            if case let .edit(e) = mode { return min(e.completedAmount, total) }
            return 0
        }()
        store.upsert(Exam(id: id, name: name.trimmingCharacters(in: .whitespaces),
                          date: date, studyInterval: interval, unit: unit,
                          totalAmount: total, pagesPerHour: pph,
                          completedAmount: completed, studyDays: studyDays))
        dismiss()
    }

    private func fmt(_ value: Double, integer: Bool) -> String {
        integer ? String(Int(value)) : String(format: "%g", value)
    }

    private func hourLabel(_ h: Int) -> String {
        switch h {
        case 0:  return "12:00 AM"
        case 24: return "12:00 AM (midnight)"
        case 12: return "12:00 PM"
        default:
            let suffix = h >= 12 ? "PM" : "AM"
            let display = h > 12 ? h - 12 : h
            return "\(display):00 \(suffix)"
        }
    }
}

// MARK: - Interval picker

private struct IntervalPicker: View {
    @Binding var interval: StudyInterval
    @Binding var showCustomInterval: Bool

    private let presets: [(label: String, value: StudyInterval)] = [
        ("Morning (6–12)",    StudyInterval(startHour: 6,  endHour: 12)),
        ("Standard (9–17)",   StudyInterval(startHour: 9,  endHour: 17)),
        ("Afternoon (12–18)", StudyInterval(startHour: 12, endHour: 18)),
        ("Evening (14–20)",   StudyInterval(startHour: 14, endHour: 20)),
        ("Night (18–23)",     StudyInterval(startHour: 18, endHour: 23))
    ]

    private var menuLabel: String {
        if showCustomInterval { return "Custom (\(interval.displayLabel))" }
        return presets.first(where: { $0.value == interval })?.label ?? interval.displayLabel
    }

    var body: some View {
        Menu {
            ForEach(presets, id: \.value) { p in
                Button(p.label) { interval = p.value; showCustomInterval = false }
            }
            Divider()
            Button("Custom…") { showCustomInterval = true }
        } label: {
            HStack(spacing: 4) {
                Text(menuLabel).font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color.appAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10).fill(Color.appAccentSoft)
            )
        }
    }
}

// MARK: - Number stepper

private struct NumberStepperField: View {
    @Binding var text: String
    let integer: Bool
    var placeholder: String = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(integer ? .numberPad : .decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 16, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

// MARK: - Study days

private struct StudyDaysSelector: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.displayOrder) { day in
                let selected = selection.contains(day)
                Button {
                    if selected { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(day.shortLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selected ? Color.appAccent : Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                        )
                        .foregroundStyle(selected ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .animation(.easeOut(duration: 0.15), value: selected)
            }
        }
    }
}

#Preview("Create") {
    ExamFormView(mode: .create)
        .environment(AppStore(repository: LocalExamRepository()))
}
