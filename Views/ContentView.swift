import SwiftUI
import PhotosUI
import Foundation

@MainActor
struct ContentView: View {
    // Environment
    @EnvironmentObject private var projectStore: ProjectStore
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @EnvironmentObject private var timelineViewModel: TimelineViewModel
    @EnvironmentObject private var exportViewModel: ExportViewModel

    // UI State
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessingSelection = false
    @State private var alertMessage: String?
    @State private var isShowingAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                mainContent
                if isProcessingSelection {
                    selectionOverlay
                }
            }
            .navigationTitle("BJJ Score Tracker")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    let labelText = primaryActionLabelText
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .videos,
                        photoLibrary: .shared()
                    ) {
                        Label(labelText, systemImage: "film")
                    }
                    .disabled(isProcessingSelection || exportViewModel.isExporting)
                }
            }
        }
        .overlay(alignment: .center) {
            exportOverlay()
        }
        // React to a new selection
        .task(id: selectedItem, priority: .userInitiated) {
            guard let newItem = selectedItem else { return }
            await handleSelection(newItem)
        }
        // Bubble up export errors
        .onChange(of: exportViewModel.exportError?.localizedDescription) { description in
            guard let description else { return }
            alertMessage = description
            isShowingAlert = true
        }
        .alert("Error", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "An unknown error occurred.")
        }
    }

    private var primaryActionLabelText: String {
        if isProcessingSelection { return "Loading..." }
        if projectStore.currentProject.videoBookmark == nil { return "Select Video" }
        return "Change Video"
    }

    @ViewBuilder
    private var mainContent: some View {
        if projectStore.currentProject.videoBookmark == nil && !isProcessingSelection {
            emptyState
        } else {
            MatchEditorView(
                isSelectionInProgress: isProcessingSelection,
                onRequestExport: {
                    Task { await startExport() }
                }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Select a training video to start scoring matches.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Text("Use the \"Select Video\" button in the toolbar to import footage. You can add scoring events, notes, and metadata once the clip is loaded.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var selectionOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                Text("Importing video...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func exportOverlay() -> some View {
        if exportViewModel.isExporting {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView(value: exportViewModel.exportProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.white)
                    Text("\(Int(exportViewModel.exportProgress * 100))%")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Exporting video...")
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(28)
                .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
            }
            .transition(.opacity)
        }
    }

    // MARK: - Selection Handling (async-safe)

    private func handleSelection(_ item: PhotosPickerItem) async {
        await MainActor.run { isProcessingSelection = true }
        defer { Task { await MainActor.run { isProcessingSelection = false } } }

        Task.detached(priority: .userInitiated) {
            do {
                print("📦 Loading video data from PhotosPickerItem...")
                guard let movieData = try await item.loadTransferable(type: Data.self) else {
                    throw SelectionError.failedToLoad
                }

                print("💾 Persisting video data...")
                let destinationURL = try await persistVideoData(movieData, identifier: item.itemIdentifier)

                print("🔖 Creating bookmark data...")
                guard let bookmarkData = BookmarkResolver.bookmark(for: destinationURL) else {
                    throw SelectionError.failedToCreateBookmark
                }

                print("🧠 Preparing project update...")
                var updatedProject = await MainActor.run { projectStore.currentProject }
                updatedProject.videoBookmark = bookmarkData
                updatedProject.videoFilename = destinationURL.lastPathComponent
                updatedProject.duration = 0
                updatedProject.events = []
                updatedProject.notes = []
                if updatedProject.title == "New Match" {
                    updatedProject.title = destinationURL.deletingPathExtension().lastPathComponent
                }
                if updatedProject.metadata.title.isEmpty {
                    updatedProject.metadata.title = updatedProject.title
                }
                updatedProject.updatedAt = Date()

                print("💽 Saving project update...")
                await MainActor.run {
                    projectStore.currentProject = updatedProject
                    projectStore.update(updatedProject)
                    print("📎 After update: videoBookmark = \(String(describing: projectStore.currentProject.videoBookmark != nil))")
                    timelineViewModel.configure(events: [], notes: [])
                    timelineViewModel.updateCurrentScore(for: 0)
                    playerViewModel.pause()
                    NotificationCenter.default.post(name: .didUpdateProjectVideo, object: nil)
                    selectedItem = nil
                }

                print("✅ Video imported successfully: \(destinationURL.lastPathComponent)")
            } catch {
                print("❌ Import error: \(error)")
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    isShowingAlert = true
                }
            }
        }
    }

    // Persist to Documents (async-safe)
    private func persistVideoData(_ data: Data, identifier: String?) async throws -> URL {
        try await Task.detached(priority: .userInitiated) { () throws -> URL in
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory

            let fallbackName = UUID().uuidString + ".mov"
            let rawName = identifier?.trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitizedBase = rawName?.isEmpty == false ? rawName! : fallbackName
            let safeName = sanitizedBase.replacingOccurrences(of: "/", with: "-")
            let destinationURL = documentsDirectory.appendingPathComponent(UUID().uuidString + "-" + safeName)

            try data.write(to: destinationURL, options: [.atomic])
            return destinationURL
        }.value
    }

    // MARK: - Export

    private func startExport() async {
        let project = projectStore.currentProject
        await startExport(with: project)
    }

    private func startExport(with project: Project) async {
        await exportViewModel.startExport(from: project) { project, bookmarkData in
            var refreshed = project
            refreshed.videoBookmark = bookmarkData
            refreshed.updatedAt = Date()
            projectStore.update(refreshed)
        }
    }
}

// MARK: - Errors

extension ContentView {
    enum SelectionError: LocalizedError {
        case failedToLoad
        case failedToCreateBookmark

        var errorDescription: String? {
            switch self {
            case .failedToLoad:
                return "Unable to load the selected video."
            case .failedToCreateBookmark:
                return "Unable to save access to the selected video."
            }
        }
    }
}
