import AVFoundation
import Foundation

protocol VideoExportSession: AnyObject {
    var status: AVAssetExportSession.Status { get }
    var progress: Float { get }
    var outputURL: URL? { get set }
    var outputFileType: AVFileType? { get set }
    var error: Error? { get }
    func exportAsynchronously(completionHandler handler: @escaping @Sendable () -> Void)
    func cancelExport()
}

extension AVAssetExportSession: VideoExportSession {}

/// ViewModel responsible for exporting video assets asynchronously.
@MainActor
final class ExportViewModel: ObservableObject {
    typealias BookmarkRefreshHandler = @MainActor (Project, Data) -> Void

    enum ExportError: LocalizedError {
        case missingVideoBookmark

        var errorDescription: String? {
            switch self {
            case .missingVideoBookmark:
                return "No video bookmark available for export."
            }
        }
    }

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

    private let resolveBookmark: (Data) async throws -> BookmarkResolver.ResolvedBookmark
    private let bookmarkCreator: (URL) -> Data?
    private let exportSessionFactory: (AVAsset) -> VideoExportSession?

    private var exporter: VideoExportSession?
    private var progressTask: Task<Void, Never>?

    init(
        resolveBookmark: @escaping (Data) async throws -> BookmarkResolver.ResolvedBookmark = { data in
            try await BookmarkResolver.resolveBookmark(from: data)
        },
        bookmarkCreator: @escaping (URL) -> Data? = { url in
            BookmarkResolver.bookmark(for: url)
        },
        exportSessionFactory: @escaping (AVAsset) -> VideoExportSession? = ExportViewModel.defaultExportSessionFactory
    ) {
        self.resolveBookmark = resolveBookmark
        self.bookmarkCreator = bookmarkCreator
        self.exportSessionFactory = exportSessionFactory
    }

    /// Cleans up any ongoing export tasks when the ViewModel is deinitialized.
    deinit {
        progressTask?.cancel()
        exporter?.cancelExport()
        resetState()
    }

    /// Resets the export state and clears exporter and progressTask.
    /// This method must be called on the MainActor.
    @MainActor
    private func resetState() {
        progressTask = nil
        exporter = nil
    }

    /// Starts exporting the video from the given project asynchronously.
    /// - Parameters:
    ///   - project: The project containing the video bookmark to export.
    ///   - refreshBookmark: Optional handler invoked when the resolved bookmark is reported as stale.
    func startExport(from project: Project, refreshBookmark: BookmarkRefreshHandler? = nil) async {
        guard !isExporting else { return }

        exportProgress = 0.0
        isExporting = true
        exportCompleted = false
        exportError = nil
        exportURL = nil

        guard let bookmarkData = project.videoBookmark else {
            exportError = ExportError.missingVideoBookmark
            isExporting = false
            return
        }

        do {
            let resolvedBookmark = try await resolveBookmark(bookmarkData)
            let videoURL = resolvedBookmark.url

            if resolvedBookmark.isStale {
                scheduleBookmarkRefresh(for: project, resolvedURL: videoURL, handler: refreshBookmark)
            }

            let asset = AVAsset(url: videoURL)

            guard exporter == nil else {
                isExporting = false
                return
            }

            guard let exportSession = exportSessionFactory(asset) else {
                exportError = NSError(domain: "ExportViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session."])
                isExporting = false
                return
            }

            exporter = exportSession
            let tempDirectory = FileManager.default.temporaryDirectory
            let outputURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mov

            exportSession.exportAsynchronously { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.handleCompletion()
                }
            }

            beginMonitoringProgress()
        } catch {
            exportError = error
            isExporting = false
            progressTask?.cancel()
            resetState()
        }
    }

    /// Cancels any ongoing export operation safely and resets the export state.
    func cancelExport() {
        progressTask?.cancel()
        exporter?.cancelExport()
        isExporting = false
        exportCompleted = false
        progressTask = nil
        resetState()
    }

    private func scheduleBookmarkRefresh(for project: Project, resolvedURL: URL, handler: BookmarkRefreshHandler?) {
        guard let handler else { return }
        guard let refreshedBookmark = bookmarkCreator(resolvedURL) else { return }
        handler(project, refreshedBookmark)
    }

    nonisolated private static func defaultExportSessionFactory(for asset: AVAsset) -> VideoExportSession? {
        AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
    }

    private func beginMonitoringProgress() {
        progressTask?.cancel()
        progressTask = Task(priority: .utility) { @MainActor [weak self] in
            guard let self else { return }

            do {
                while !Task.isCancelled, let exportSession = self.exporter, exportSession.status == .exporting {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    self.exportProgress = Double(exportSession.progress)
                }

                if let exportSession = self.exporter, exportSession.status == .completed {
                    self.exportProgress = Double(exportSession.progress)
                }
            } catch {
                // Ignore cancellation errors from Task.sleep.
            }
        }
    }

    @MainActor
    private func handleCompletion() {
        isExporting = false
        progressTask?.cancel()

        guard let exportSession = exporter else {
            resetState()
            return
        }

        switch exportSession.status {
        case .completed:
            exportCompleted = true
            exportURL = exportSession.outputURL
            exportProgress = 1.0
        case .failed:
            exportError = exportSession.error
        case .cancelled:
            exportError = NSError(domain: "ExportViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export was cancelled."])
        default:
            break
        }

        resetState()
    }
}
