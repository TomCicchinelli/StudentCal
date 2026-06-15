//
//  ExamDetailView.swift
//  StudyPlanner
//

import SwiftUI

private let kScreenWidth: CGFloat = UIScreen.main.bounds.width

struct ExamDetailView: View {
    @Environment(AppStore.self) private var store
    @State private var isEditing        = false
    @State private var editingHighlight: ExamFormView.HighlightField = .none
    @State private var triggerPulse     = false
    @State private var browsingDate: Date = Date()
    @State private var showLoggedConfirmation = false
    @State private var showDatePicker   = false
    @State private var viewWidth: CGFloat = UIScreen.main.bounds.width

    // ── Quick-log state ──────────────────────────────────────────────────
    @State private var isAdjusting: Bool = false
    @State private var adjustmentAmountText: String = ""
    @FocusState private var adjustmentFieldFocused: Bool

    // ── Day swipe state ───────────────────────────────────────────────────
    @State private var dayOffset:     CGFloat = 0
    @State private var peekDate:      Date?   = nil
    @State private var dragDirection: CGFloat = 1

    private let commitThreshold: CGFloat = kScreenWidth * 0.30
    private var today: Date { Date().startOfDay }

    var body: some View {
        Group {
            if let exam = store.focusedExam {
                content(for: exam)
                    .onAppear {
                        browsingDate = today
                    }
                    .onChange(of: browsingDate) { _, _ in
                        isAdjusting = false
                        adjustmentAmountText = ""
                    }
                    .onChange(of: store.focusedExamID) { _, _ in
                        browsingDate = today
                        isAdjusting = false
                        adjustmentAmountText = ""
                    }
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
            }
        )
        .navigationTitle(store.focusedExam?.name ?? "Exam")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isEditing = true
                } label: {
                    Text("Edit")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
        .sheet(isPresented: $isEditing, onDismiss: { editingHighlight = .none; triggerPulse = false }) {
            if let exam = store.focusedExam {
                ExamFormView(mode: .edit(exam), highlightField: editingHighlight, triggerPulse: $triggerPulse)
            }
        }
        .onChange(of: isEditing) { _, open in
            guard open, editingHighlight != .none else { return }
            // Sheet animation takes ~0.5s. Fire pulse after it settles.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                triggerPulse = true
            }
        }
        .sheet(isPresented: $showDatePicker) {
            if let exam = store.focusedExam {
                DatePickerSheet(
                    selected: $browsingDate,
                    earliest: creationDay(for: exam),
                    latest: today
                )
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for exam: Exam) -> some View {
        let earliest        = min(today, creationDay(for: exam))
        let isBrowsingToday = Calendar.current.isDate(browsingDate, inSameDayAs: today)
        let isAtEarliest    = Calendar.current.isDate(browsingDate, inSameDayAs: earliest)
        let overflow        = store.planOverflowsExam
        let progress        = StudyPlanCalculator.progress(for: exam)
        let isComplete      = progress >= 1.0 && !overflow
        let glowColor       = overflow ? Color.red : isComplete ? Color.examGreen : Color.appAccent

        GeometryReader { geo in
            let _ = Task { @MainActor in viewWidth = geo.size.width }
            VStack(spacing: 0) {

                // ── Hero — always compact ─────────────────────────────────
                hero(exam: exam, overflow: overflow,
                     isComplete: isComplete, glowColor: glowColor, geo: geo)

                // ── Overflow banner — above the day carousel ──────────
                // NOTE: no swipe gesture here — the banner has its own
                // horizontal UIScrollView and must not trigger day navigation.
                // Hidden while the log input is focused so the keyboard has room.
                if overflow && !adjustmentFieldFocused {
                    overflowBanner(unit: exam.unit, glowColor: glowColor)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // ── Day carousel ──────────────────────────────────────────
                dayCarousel(earliest: earliest, isBrowsingToday: isBrowsingToday,
                            isAtEarliest: isAtEarliest, glowColor: glowColor, geo: geo)
                    .simultaneousGesture(daySwipeGesture(earliest: earliest,
                                                         isBrowsingToday: isBrowsingToday,
                                                         isAtEarliest: isAtEarliest))

                Divider().opacity(isComplete ? 0 : 0.4)

                // ── Bottom area — scrollable so everything always fits ─────
                ScrollView {
                    VStack(spacing: 0) {
                        if !isComplete {
                            logSection(exam: exam, isBrowsingToday: isBrowsingToday, glowColor: glowColor)
                                
                        } else {
                            CompletionSection(exam: exam, accentColor: glowColor)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .clipped()
                .scrollDisabled(true)
            }
            .animation(.easeInOut(duration: 0.25), value: adjustmentFieldFocused)
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private func hero(exam: Exam, overflow: Bool,
                      isComplete: Bool, glowColor: Color, geo: GeometryProxy) -> some View {
        let gradient: LinearGradient = {
            if overflow {
                return LinearGradient(colors: [Color.red.opacity(0.20), Color.red.opacity(0)],
                                      startPoint: .top, endPoint: .bottom)
            } else if isComplete {
                return LinearGradient(colors: [Color.examGreen.opacity(0.22), Color.examGreen.opacity(0)],
                                      startPoint: .top, endPoint: .bottom)
            } else {
                return LinearGradient(colors: [Color.appAccent.opacity(0.18), Color.appAccent.opacity(0)],
                                      startPoint: .top, endPoint: .bottom)
            }
        }()

        // When the overflow banner is shown, it adds height above the day
        // carousel. Shrink the hero by a bit more than that so the log
        // section below gains net space rather than just breaking even —
        // its buttons need more breathing room in the overflow state.
        let overflowBannerHeight: CGFloat = 64
        let heroHeight = max(0, geo.size.height * 0.48 - (overflow && !adjustmentFieldFocused ? overflowBannerHeight : 0))

        ZStack {
            gradient.ignoresSafeArea(edges: .top)
                .animation(.easeOut(duration: 0.5), value: overflow)
                .animation(.easeOut(duration: 0.5), value: isComplete)

            VStack(spacing: 14) {
                Spacer(minLength: 0)

                // Simple progress counter — no ring, just the numbers.
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatted(exam.completedAmount))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text("/ \(formatted(exam.totalAmount)) \(unitNoun(exam.totalAmount, for: exam))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // ── The headline: today's actionable sentence ─────────────
                todaySentence(exam: exam, overflow: overflow, isComplete: isComplete, glowColor: glowColor)
                    .padding(.horizontal, 20)

                // Stats row — exam date only
                HStack(spacing: 0) {
                    statCell(label: "Exam date",
                             value: DateFormatters.dayMonth.string(from: exam.date))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

                Spacer(minLength: 0)
            }
        }
        .frame(height: heroHeight)
        .animation(.easeOut(duration: 0.25), value: overflow)
        .animation(.easeOut(duration: 0.25), value: adjustmentFieldFocused)
    }

    /// The headline sentence: what to study today and when, or a
    /// completion / overflow message when there's nothing to plan.
    @ViewBuilder
    private func todaySentence(exam: Exam, overflow: Bool, isComplete: Bool, glowColor: Color) -> some View {
        if isComplete {
            VStack(spacing: 6) {
                Text("All done for \(exam.name) 🎉")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("Nothing left to study")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        } else if overflow {
            let pct = projectedCoveragePercent(for: exam)
            let planned = plannedForToday(exam: exam)
            VStack(spacing: 6) {
                (
                    Text("At this rate, you'll cover about ")
                        .foregroundStyle(.primary)
                    + Text("\(pct)%")
                        .foregroundStyle(Color.orange)
                    + Text(" of the material")
                        .foregroundStyle(.primary)
                )
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

                if let planned, planned > 0 {
                    Text("Study \(formatted(planned)) \(unitNoun(planned, for: exam)) today to stay on this pace")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        } else if let planned = plannedForToday(exam: exam), planned > 0 {
            VStack(spacing: 6) {
                (
                    Text("Study ")
                        .foregroundStyle(.primary)
                    + Text("\(formatted(planned)) \(unitNoun(planned, for: exam))")
                        .foregroundStyle(glowColor)
                    + Text(" today")
                        .foregroundStyle(.primary)
                )
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

                Text("Suggested window: \(todaysStudyWindow(exam: exam) ?? exam.studyInterval.displayLabel)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

        } else {
            VStack(spacing: 6) {
                Text("No study planned today")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Enjoy the rest day, or log a session if you studied anyway")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Day carousel

    @ViewBuilder
    private func dayCarousel(earliest: Date, isBrowsingToday: Bool,
                              isAtEarliest: Bool, glowColor: Color, geo: GeometryProxy) -> some View {
        ZStack {
            ZStack {
                dateLabel(date: browsingDate, isToday: isBrowsingToday)
                    .offset(x: dayOffset)
                if let peek = peekDate {
                    dateLabel(date: peek, isToday: Calendar.current.isDate(peek, inSameDayAs: today))
                        .offset(x: dayOffset + dragDirection * kScreenWidth)
                        .allowsHitTesting(false)
                }
            }
            .clipped()

            HStack {
                if !isAtEarliest {
                    navButton(systemName: "chevron.left") { stepDay(by: -1, earliest: earliest) }
                } else {
                    Color.clear.frame(width: 34, height: 34)
                }
                Spacer()
                if !isBrowsingToday {
                    navButton(systemName: "chevron.right") { stepDay(by: 1, earliest: earliest) }
                } else {
                    Color.clear.frame(width: 34, height: 34)
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(height: geo.size.height * 0.09)
        .background(glowColor.opacity(0.04))
    }

    // MARK: - Day swipe gesture (single instance, applied at top level)

    private func daySwipeGesture(earliest: Date, isBrowsingToday: Bool, isAtEarliest: Bool) -> some Gesture {
        DragGesture(minimumDistance: 15, coordinateSpace: .local)
            .onChanged { value in
                let h = abs(value.translation.width)
                let v = abs(value.translation.height)
                guard h > v * 1.5 else { return }
                let tx = value.translation.width
                if peekDate == nil {
                    let goingBack = tx > 0
                    if goingBack && isAtEarliest     { return }
                    if !goingBack && isBrowsingToday { return }
                    let delta = goingBack ? -1 : 1
                    if let candidate = Calendar.current.date(byAdding: .day, value: delta, to: browsingDate) {
                        peekDate      = max(earliest.startOfDay, min(today, candidate.startOfDay))
                        dragDirection = goingBack ? -1 : 1
                    }
                }
                dayOffset = tx
            }
            .onEnded { value in
                let h = abs(value.translation.width)
                let v = abs(value.translation.height)
                if h > v * 1.5, h > commitThreshold, let next = peekDate {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 35)) {
                        dayOffset = value.translation.width < 0 ? -kScreenWidth : kScreenWidth
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.27) {
                        browsingDate = next; dayOffset = 0; peekDate = nil
                    }
                } else {
                    if peekDate != nil {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 35)) { dayOffset = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { peekDate = nil }
                }
            }
    }

    // MARK: - Overflow banner

    @ViewBuilder
    private func overflowBanner(unit: StudyUnit, glowColor: Color) -> some View {
        let noun = unit == .pages ? "pages" : "hours"
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.orange)
            Text("To cover more of the program, edit your plan or try studying more \(noun) each day.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glowColor.opacity(0.04))
    }

    // MARK: - Log section

    @ViewBuilder
    private func logSection(exam: Exam, isBrowsingToday: Bool, glowColor: Color) -> some View {
        let logged = store.loggedAmount(examID: exam.id, on: browsingDate)

        VStack(alignment: .leading, spacing: 14) {
            // Header — hidden while adjusting so the amount field has more
            // room to sit higher, closer to the top of this section and
            // away from the keyboard.
            if !adjustmentFieldFocused {
                HStack(spacing: 6) {
                    if !isBrowsingToday {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                    Text("Study log")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .kerning(0.5)
                    Spacer()
                    if !isBrowsingToday && logged == nil {
                        // Feedback: this past day has no recorded session.
                        // Treated as 0 toward progress until the user logs it.
                        Text("Not logged")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.orange)
                    } else if let planned = plannedForDay(exam: exam), logged == nil {
                        Text("Planned: \(formatted(planned)) \(unitNoun(planned, for: exam))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity)
            }

            // Quick-tap logging
            quickLogControl(exam: exam, glowColor: glowColor)

        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            isBrowsingToday ? Color.clear : Color.orange.opacity(0.04)
        )
        .animation(.easeOut(duration: 0.25), value: isBrowsingToday)
        .animation(.easeOut(duration: 0.2), value: adjustmentFieldFocused)
    }

    // MARK: - Quick log control

    @ViewBuilder
    private func quickLogControl(exam: Exam, glowColor: Color) -> some View {
        let planned = plannedForDay(exam: exam)
        let logged  = store.loggedAmount(examID: exam.id, on: browsingDate)

        VStack(alignment: .leading, spacing: 12) {
            if logged != nil && !isAdjusting {
                // Already logged — show confirmation + option to change.
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.examGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Logged \(formatted(logged ?? 0)) \(unitNoun(logged ?? 0, for: exam))")
                            .font(.system(size: 15, weight: .semibold))
                        Text(isBrowsingToday(for: exam) ? "for today" : "for this day")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        beginAdjustment()
                    } label: {
                        Text("Edit")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.appAccent.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.examGreen.opacity(0.08))
                )
            } else {
                if isAdjusting {
                    // All choice buttons (and the prompt) collapse into the
                    // inline amount field — keeps this compact and closer to
                    // the keyboard so the field stays visible above it.
                    adjustmentField(exam: exam, planned: planned, glowColor: glowColor)
                } else {
                    // Question prompt
                    Text(promptText(exam: exam, planned: planned))
                        .font(.system(size: 15, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)

                    // Primary action: the common case (matches the plan exactly).
                    primaryLogChoiceCard(
                        title: "Yes, exactly that",
                        subtitle: planned != nil ? "Log \(formatted(planned ?? 0)) \(unitNoun(planned ?? 0, for: exam))" : "Log nothing",
                        icon: "checkmark.circle.fill",
                        color: Color.examGreen
                    ) {
                        let amount = planned ?? 0
                        store.logStudy(amount: amount, on: browsingDate)
                        isAdjusting = false
                        flashConfirmation()
                    }

                    HStack(spacing: 8) {
                        compactLogChoiceCard(
                            title: "Different amount",
                            icon: "pencil.circle.fill",
                            color: Color.blue
                        ) {
                            beginAdjustment()
                        }

                        compactLogChoiceCard(
                            title: "Didn't study",
                            icon: "moon.zzz.fill",
                            color: Color(.systemGray)
                        ) {
                            store.logStudy(amount: 0, on: browsingDate)
                            flashConfirmation()
                        }
                    }
                }

                if showLoggedConfirmation {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.examGreen)
                        Text("Logged!")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.examGreen)
                    }
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: isAdjusting)
        .animation(.easeOut(duration: 0.2), value: logged)
    }

    /// Inline amount field shown in place of the secondary action row.
    private func adjustmentField(exam: Exam, planned: Double?, glowColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How many \(exam.unit == .pages ? "pages" : "hours") in total?")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField(formatted(planned ?? 0), text: $adjustmentAmountText)
                    .keyboardType(.decimalPad)
                    .focused($adjustmentFieldFocused)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(width: 64)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(adjustmentValueValid ? glowColor.opacity(0.6) : Color(.systemGray4),
                                    lineWidth: adjustmentValueValid ? 1.5 : 1)
                    )

                Text(unitNoun(Double(adjustmentAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0, for: exam))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                Button {
                    isAdjusting = false
                    adjustmentAmountText = ""
                    adjustmentFieldFocused = false
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(Color.red)
                }
                .buttonStyle(.plain)

                Button {
                    submitAdjustment(exam: exam)
                } label: {
                    Text("Save")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(adjustmentValueValid ? glowColor : Color(.systemGray4))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!adjustmentValueValid)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .transition(.opacity)
    }

    /// Full-width primary choice — the common case (matches the plan).
    /// Same outlined/tinted style as the secondary cards below, just larger
    /// and full-width to signal it's the default action.
    private func primaryLogChoiceCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Smaller secondary choice — alternatives to the primary action.
    private func compactLogChoiceCard(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(height: 16)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// The question shown above the log choices.
    private func promptText(exam: Exam, planned: Double?) -> String {
        let timeframe = isBrowsingToday(for: exam) ? "today" : "that day"
        if let planned, planned > 0 {
            return "Did you study \(formatted(planned)) \(unitNoun(planned, for: exam)) \(timeframe)?"
        }
        return "Nothing was planned \(timeframe) — did you study anyway?"
    }

    private func isBrowsingToday(for exam: Exam) -> Bool {
        Calendar.current.isDate(browsingDate, inSameDayAs: today)
    }

    private func beginAdjustment() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isAdjusting = true
        adjustmentAmountText = ""
        DispatchQueue.main.async { adjustmentFieldFocused = true }
    }

    private var adjustmentValueValid: Bool {
        let cleaned = adjustmentAmountText.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value >= 0 else { return false }
        let cap: Double = store.focusedExam.map { $0.unit == .hours ? 24 : $0.totalAmount } ?? 24
        return value <= cap
    }

    private func submitAdjustment(exam: Exam) {
        let cleaned = adjustmentAmountText.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), adjustmentValueValid else { return }
        store.logStudy(amount: value, on: browsingDate)
        adjustmentFieldFocused = false
        isAdjusting = false
        flashConfirmation()
    }

    private func flashConfirmation() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.3)) { showLoggedConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.3)) { showLoggedConfirmation = false }
        }
    }

    private func dateLabel(date: Date, isToday: Bool) -> some View {
        // Only a clean tap (no finger movement) opens the picker. A TapGesture
        // inherently cancels if the touch moves, so swipes never trigger it.
        // The hit target is restricted to the text itself via .fixedSize().
        VStack(spacing: 2) {
            Text(isToday ? "Today" : "Past day")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.6)
            HStack(spacing: 5) {
                Text(DateFormatters.dayMonth.string(from: date))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }
        }
        .fixedSize()
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showDatePicker = true
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Subviews

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
    }

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.appAccent)
                .frame(width: 34, height: 34)
                .background(Color.appAccentSoft, in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func creationDay(for exam: Exam) -> Date {
        // The day the study plan was created — the carousel and log
        // shouldn't go back further than this, since there's nothing
        // to log for days before the plan existed.
        exam.createdAt.startOfDay
    }

    private func stepDay(by delta: Int, earliest: Date) {
        guard let next = Calendar.current.date(byAdding: .day, value: delta, to: browsingDate) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        browsingDate = max(earliest, min(today, next.startOfDay))
    }

    private func plannedForDay(exam: Exam) -> Double? {
        guard let hours = store.plannedHours(examID: exam.id, on: browsingDate),
              hours > 0 else { return nil }
        switch exam.unit {
        case .hours: return hours
        case .pages: return hours * exam.pagesPerHour
        }
    }

    /// Today's planned amount, independent of the browsing date shown in the carousel.
    private func plannedForToday(exam: Exam) -> Double? {
        guard let hours = store.plannedHours(examID: exam.id, on: today),
              hours > 0 else { return nil }
        switch exam.unit {
        case .hours: return hours
        case .pages: return hours * exam.pagesPerHour
        }
    }

    /// The actual scheduled study window(s) for today, formatted as "HH:mm–HH:mm".
    /// Spans from the start of the earliest block to the end of the latest block,
    /// so if the scheduler split today's session across multiple free slots,
    /// this still reads as a single window covering all of them.
    private func todaysStudyWindow(exam: Exam) -> String? {
        let blocks = store.scheduledBlocks(on: today).filter { $0.examID == exam.id }
        guard let first = blocks.min(by: { $0.date < $1.date }),
              let last  = blocks.max(by: { $0.endDate < $1.endDate }) else { return nil }
        let start = DateFormatters.hourMinute.string(from: first.date)
        let end   = DateFormatters.hourMinute.string(from: last.endDate)
        return "\(start)–\(end)"
    }

    /// Estimated % of the material that will be covered by the exam date,
    /// given the currently scheduled blocks plus what's already completed.
    private func projectedCoveragePercent(for exam: Exam) -> Int {
        guard exam.totalAmount > 0 else { return 0 }

        let scheduledHours = (store.scheduledBlocks[exam.id] ?? [])
            .reduce(0.0) { $0 + $1.duration }

        let scheduledAmount: Double = {
            switch exam.unit {
            case .hours: return scheduledHours
            case .pages: return scheduledHours * exam.pagesPerHour
            }
        }()

        let projected = exam.completedAmount + scheduledAmount
        let fraction = min(1, projected / exam.totalAmount)
        return Int((fraction * 100).rounded())
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value)) : String(format: "%.1f", value)
    }

    /// "page"/"pages" or "hour"/"hours" depending on whether the amount rounds to exactly 1.
    private func unitNoun(_ value: Double, for exam: Exam) -> String {
        let isSingular = abs(value - 1) < 0.001
        switch exam.unit {
        case .pages: return isSingular ? "page" : "pages"
        case .hours: return isSingular ? "hour" : "hours"
        }
    }

}

// MARK: - Completion section

private struct CompletionSection: View {
    let exam: Exam
    let accentColor: Color

    @State private var appeared  = false
    @State private var showDots  = false
    @State private var hasPlayed = false   // prevents replay on re-appear

    private let colors: [Color] = [.examGreen, .appAccent, .yellow, .orange, .pink, .teal]

    private struct Particle: Identifiable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let color: Color
        let delay: Double
    }

    private var particles: [Particle] {
        (0..<22).map { i in
            let angle  = Double(i) / 22.0 * 2 * .pi
            let radius = CGFloat(40 + (i % 5) * 18)
            return Particle(
                id:    i,
                x:     cos(angle) * radius + CGFloat((i % 3) - 1) * 12,
                y:     sin(angle) * radius * 0.5 + CGFloat((i % 3) - 1) * 8,
                size:  CGFloat(4 + (i % 4) * 2),
                color: colors[i % colors.count],
                delay: Double(i) * 0.018
            )
        }
    }

    var body: some View {
        ZStack {
            accentColor.opacity(0.05)

            ForEach(particles) { p in
                Circle()
                    .fill(p.color.opacity(0.75))
                    .frame(width: p.size, height: p.size)
                    .offset(x: p.x, y: p.y)
                    .opacity(showDots ? 1 : 0)
                    .scaleEffect(showDots ? 1 : 0.1)
                    .animation(.easeOut(duration: 0.5).delay(p.delay), value: showDots)
            }

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.examGreen.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Circle()
                        .stroke(Color.examGreen.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.examGreen)
                }
                .scaleEffect(appeared ? 1 : 0.3)
                .opacity(appeared ? 1 : 0)

                VStack(spacing: 6) {
                    Text("All done!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.examGreen)
                    Text("You've covered everything for \(exam.name)")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Exam on \(DateFormatters.dayMonth.string(from: exam.date)) — you're ready 🎓")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.examGreen.opacity(0.8))
                        .padding(.top, 2)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 40)
        }
        .onAppear {
            guard !hasPlayed else { return }
            hasPlayed = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.05)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showDots = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeIn(duration: 0.4)) { showDots = false }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

// MARK: - Date picker sheet

private struct DatePickerSheet: View {
    @Binding var selected: Date
    let earliest: Date
    let latest: Date

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Date = .distantPast   // overwritten in onAppear

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("", selection: $draft, in: earliest...latest,
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Color.appAccent)
                    .padding(.horizontal, 8)
                Spacer()
            }
            .navigationTitle("Jump to date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.appAccent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Go") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selected = draft.startOfDay
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                }
            }
            .onAppear { draft = selected }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack { ExamDetailView() }
        .environment(AppStore.preview)
}
