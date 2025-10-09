@preconcurrency import AVFoundation
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
    typealias BookmarkRefreshHandler = @Sendable (Project, Data) -> Void

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

    private let resolveBookmark: @Sendable (Data) async throws -> BookmarkResolver.ResolvedBookmark
    private let bookmarkCreator: @Sendable (URL) -> Data?
    private let exportSessionFactory: @Sendable (AVAsset) -> VideoExportSession?

    private var exporter: VideoExportSession?
    private var progressTask: Task<Void, Never>?

    init(
        resolveBookmark: @escaping @Sendable (Data) async throws -> BookmarkResolver.ResolvedBookmark = { data in
            try await BookmarkResolver.resolveBookmark(from: data)
        },
        bookmarkCreator: @escaping @Sendable (URL) -> Data? = { url in
            BookmarkResolver.bookmark(for: url)
        },
        exportSessionFactory: @escaping @Sendable (AVAsset) -> VideoExportSession? = ExportViewModel.defaultExportSessionFactory
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
                guard let self else { return }
                Task { @MainActor in
                    self.isExporting = false
                    switch exportSession.status {
                    case .completed:
                        self.exportCompleted = true
                        self.exportURL = exportSession.outputURL
                        self.exportProgress = 1.0
                    case .failed:
                        self.exportError = exportSession.error
                    case .cancelled:
                        self.exportError = NSError(domain: "ExportViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export was cancelled."])
                    default:
                        break
                    }

                    self.progressTask?.cancel()
                    self.resetState()
                }
            }

            progressTask?.cancel()
            progressTask = Task(priority: .utility) { [weak exportSession] in
                do {
                    while let exportSession, exportSession.status == .exporting {
                        try Task.checkCancellation()
                        try await Task.sleep(nanoseconds: 200_000_000)
                        let progressValue = Double(exportSession.progress)
                        await MainActor.run { [weak self] in
                            self?.exportProgress = progressValue
                        }
                    }
                } catch {
                    // Task was cancelled or error occurred, safely ignore
                }
                await MainActor.run { [weak self] in
                    self?.progressTask = nil
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
        isExporting = false
        exportCompleted = false
        progressTask = nil
        resetState()
    }

    private func scheduleBookmarkRefresh(for project: Project, resolvedURL: URL, handler: BookmarkRefreshHandler?) {
        guard let handler else { return }
        let bookmarkCreator = bookmarkCreator
        Task(priority: .utility) {
            guard let refreshedBookmark = bookmarkCreator(resolvedURL) else { return }
            await MainActor.run {
                handler(project, refreshedBookmark)
            }
        }
    }

    private static func defaultExportSessionFactory(for asset: AVAsset) -> VideoExportSession? {
        AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
    }
}
