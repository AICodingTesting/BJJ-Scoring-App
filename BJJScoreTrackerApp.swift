import SwiftUI

@main
struct BJJScoreTrackerApp: App {
    @StateObject private var projectStore = ProjectStore()
    @StateObject private var playerViewModel = PlayerViewModel()
    @StateObject private var timelineViewModel = TimelineViewModel()
    @StateObject private var exportViewModel = ExportViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectStore)
                .environmentObject(playerViewModel)
                .environmentObject(timelineViewModel)
                .environmentObject(exportViewModel)
        }
    }
}
