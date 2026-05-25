//
//  StudyPlannerApp.swift
//  StudyPlanner
//

import SwiftUI

@main
struct StudyPlannerApp: App {
    @State private var store = AppStore(repository: LocalExamRepository())
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        store.autoFillMissingDays()
                    }
                }
        }
    }
}
