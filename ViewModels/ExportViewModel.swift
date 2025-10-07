import Foundation
import AVFoundation

extension AVAssetExportSession: @unchecked Sendable {}

/// ViewModel responsible for exporting video assets asynchronously.
@MainActor
final class ExportViewModel: ObservableObject {
    /// Progress of the export operation, ranging from 0.0 to 1.0.
    @Published var exportProgress: Double = 0.0
    /// Indicates whether an export operation is currently in progress.
    @Published var isExporting: Bool = false
    /// Indicates whether the export operation completed successfully.
    @Published var exportCompleted: Bool = false
    /// URL of the exported video file upon successful completion.
    @Published var exportURL: URL?
    /// Error encountered during export, if any.
    @Published var exportError: Error?

    private var exporter: AVAssetExportSession?
    private var progressTask: Task<Void, Never>?

    /// Cleans up any ongoing export tasks when the ViewModel is deinitialized.
    deinit {
        Task { @MainActor in
            progressTask?.cancel()
            exporter?.cancelExport()
            resetState()
        }
    }

    /// Resets the export state and clears exporter and progressTask.
    /// This method must be called on the MainActor.
    @MainActor
    private func resetState() {
        progressTask = nil
        exporter = nil
    }

    /// Starts exporting the video from the given project asynchronously.
    /// - Parameter project: The project containing the video bookmark to export.
    @discardableResult
    func startExport(from project: Project) async {
        guard !isExporting else { return }

        exportProgress = 0.0
        isExporting = true
        exportCompleted = false
        exportError = nil

        do {
            let videoURL: URL
            do {
                videoURL = try await BookmarkResolver.resolveBookmark(project.videoBookmark)
            } catch {
                exportError = error
                isExporting = false
                return
            }

            let asset = AVAsset(url: videoURL)

            let exportSession = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
                    continuation.resume(returning: session)
                }
            }

            guard let exportSession else {
                exportError = NSError(domain: "ExportViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session."])
                isExporting = false
                return
            }

            // Prevent starting a new export if one is already active
            guard exporter == nil else {
                return
            }

            exporter = exportSession
            let tempDirectory = FileManager.default.temporaryDirectory
            let outputURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mov

            exportSession.exportAsynchronously { [weak self, weak exportSession] in
                Task { @MainActor in
                    guard let self = self, let exportSession = exportSession else { return }
                    self.isExporting = false

                    switch exportSession.status {
                    case .completed:
                        self.exportCompleted = true
                        self.exportURL = outputURL
                        print("Export completed successfully: \(outputURL)")
                    case .failed:
                        self.exportError = exportSession.error
                        print("Export failed with error: \(String(describing: exportSession.error))")
                    case .cancelled:
                        self.exportError = NSError(domain: "ExportViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export was cancelled."])
                        print("Export was cancelled.")
                    default:
                        break
                    }

                    self.progressTask?.cancel()
                    self.progressTask = nil
                    self.resetState()
                }
            }

            progressTask?.cancel()
            progressTask = Task { [weak self] in
                guard let self = self else { return }
                do {
                    while let exportSession = exportSession, exportSession.status == .exporting {
                        try Task.checkCancellation()
                        try await Task.sleep(nanoseconds: 200_000_000)
                        await MainActor.run {
                            self.exportProgress = Double(exportSession.progress)
                        }
                    }
                } catch {
                    // Task was cancelled or error occurred, safely ignore
                }
                await MainActor.run {
                    self.progressTask = nil
                    self.exportProgress = 1.0
                }
            }
        } catch {
            exportError = error
            isExporting = false
            progressTask?.cancel()
            progressTask = nil
            resetState()
        }
    }

    /// Cancels any ongoing export operation safely and resets the export state.
    func cancelExport() {
        progressTask?.cancel()
        exporter?.cancelExport()
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.isExporting = false
            self.progressTask = nil
            self.resetState()
        }
    }
} 
