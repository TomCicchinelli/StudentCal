//
//  MainTabView.swift
//  StudyPlanner
//

import SwiftUI

private let kTabScreenWidth: CGFloat = UIScreen.main.bounds.width

struct MainTabView: View {
    @State private var selectedTab: Tab = .exams

    enum Tab: Int, Hashable, CaseIterable {
        case calendar = 0
        case exams    = 1
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Sliding content ───────────────────────────────────────────
            GeometryReader { geo in
                HStack(spacing: 0) {
                    CalendarTabView()
                        .frame(width: geo.size.width)

                    ExamsTabView()
                        .frame(width: geo.size.width)
                }
                .offset(x: selectedTab == .calendar ? 0 : -geo.size.width)
                .animation(.interpolatingSpring(stiffness: 300, damping: 35), value: selectedTab)
            }
            .ignoresSafeArea()

            // ── Tab bar ───────────────────────────────────────────────────
            tabBar
        }
        .tint(Color.appAccent)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabBarButton(tab: .calendar, icon: "calendar",           label: "Calendar")
            tabBarButton(tab: .exams,    icon: "graduationcap.fill", label: "Exam")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 49)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(Color(.separator).opacity(0.4)).frame(height: 0.5), alignment: .top)
        .safeAreaPadding(.bottom)
    }

    private func tabBarButton(tab: Tab, icon: String, label: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            guard tab != selectedTab else { return }
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 35)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selectedTab == tab ? Color.appAccent : Color(.tertiaryLabel))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: selectedTab)
    }
}

#Preview {
    MainTabView()
        .environment(AppStore.preview)
}
