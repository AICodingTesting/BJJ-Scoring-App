import SwiftUI
import AVFoundation
import Combine

@MainActor
struct ContentView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @StateObject private var exportViewModel = ExportViewModel()

    var body: some View {
        VStack {
            Text("BJJ Score Tracker")
                .font(.largeTitle)
                .padding()

            Button("Start Export") {
                Task {
                    await exportViewModel.startExport(from: projectStore.currentProject) { project, bookmarkData in
                        var updatedProject = project
                        updatedProject.videoBookmark = bookmarkData
                        updatedProject.updatedAt = Date()
                        projectStore.update(updatedProject)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}
