import Foundation
import SwiftUI
import PhotosUI

@MainActor
struct ContentView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @StateObject private var exportViewModel = ExportViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessingSelection = false
    @State private var alertMessage: String?
    @State private var isShowingAlert = false

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Text("BJJ Score Tracker")
                    .font(.largeTitle)
                    .padding(.top, 40)

                PhotosPicker(
                    selection: $selectedItem,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    Text(isProcessingSelection ? "Loading..." : "Select Video")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessingSelection || exportViewModel.isExporting)
                .padding(.horizontal)

                if isProcessingSelection {
                    ProgressView("Preparing video...")
                        .padding(.horizontal)
                } else if projectStore.currentProject.videoBookmark != nil {
                    Button("Start Export") {
                        Task {
                            await startExport()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                } else {
                    Text("Select a video to begin exporting.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }

                Spacer()
            }

            if exportViewModel.isExporting {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView(value: exportViewModel.exportProgress, total: 1.0)
                        Text("\(Int(exportViewModel.exportProgress * 100))%")
                            .foregroundColor(.white)
                        Text("Exporting video...")
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await handleSelection(newItem)
            }
        }
        .onChange(of: exportViewModel.exportError) { _, error in
            guard let error else { return }
            alertMessage = error.localizedDescription
            isShowingAlert = true
        }
        .alert("Export Error", isPresented: $isShowingAlert, actions: {
            Button("OK", role: .cancel) {
                alertMessage = nil
            }
        }, message: {
            Text(alertMessage ?? "An unknown error occurred.")
        })
    }

    private func handleSelection(_ item: PhotosPickerItem) async {
        isProcessingSelection = true
        defer { isProcessingSelection = false }

        do {
            guard let movieData = try await item.loadTransferable(type: Data.self) else {
                throw SelectionError.failedToLoad
            }

            let destinationURL = try await persistVideoData(movieData, identifier: item.itemIdentifier)
            guard let bookmarkData = BookmarkResolver.bookmark(for: destinationURL) else {
                throw SelectionError.failedToCreateBookmark
            }

            var updatedProject = projectStore.currentProject
            updatedProject.videoBookmark = bookmarkData
            updatedProject.videoFilename = destinationURL.lastPathComponent
            updatedProject.updatedAt = Date()
            projectStore.update(updatedProject)

            await startExport(with: updatedProject)
            selectedItem = nil
        } catch {
            alertMessage = error.localizedDescription
            isShowingAlert = true
        }
    }

    private func persistVideoData(_ data: Data, identifier: String?) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let fileManager = FileManager.default
                    let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory

                    let fallbackName = UUID().uuidString + ".mov"
                    let rawName = identifier?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let sanitizedBase = rawName?.isEmpty == false ? rawName! : fallbackName
                    let safeName = sanitizedBase.replacingOccurrences(of: "/", with: "-")
                    let destinationURL = documentsDirectory.appendingPathComponent(UUID().uuidString + "-" + safeName)

                    try data.write(to: destinationURL, options: [.atomic])
                    continuation.resume(returning: destinationURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func startExport() async {
        let project = projectStore.currentProject
        await startExport(with: project)
    }

    private func startExport(with project: Project) async {
        await exportViewModel.startExport(from: project) { project, bookmarkData in
            var updatedProject = project
            updatedProject.videoBookmark = bookmarkData
            updatedProject.updatedAt = Date()
            projectStore.update(updatedProject)
        }
    }
}

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
