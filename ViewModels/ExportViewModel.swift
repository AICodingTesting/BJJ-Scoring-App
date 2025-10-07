import Foundation
import AVFoundation
import Combine

final class ExportViewModel: ObservableObject {
    @Published var isExporting: Bool = false
    @Published var progress: Double = 0
    @Published var lastExportURL: URL?
    @Published var error: Error?

    private var exportSession: AVAssetExportSession?
    private var timer: Timer?

    func export(project: Project, sourceURL: URL, completion: ((Result<URL, Error>) -> Void)? = nil) {
        cancel()
        isExporting = true
        progress = 0
        error = nil

        do {
            let builder = CompositionBuilder()
            let package = try builder.build(from: sourceURL, project: project)
            try? FileManager.default.removeItem(at: package.outputURL)
            guard let session = AVAssetExportSession(asset: package.composition, presetName: preset(for: project.exportPreferences.resolution)) else {
                handleFailure(CompositionBuilderError.missingAsset, completion: completion)
                return
            }
            exportSession = session
            session.outputURL = package.outputURL
            session.outputFileType = .mp4
            session.videoComposition = package.videoComposition
            session.shouldOptimizeForNetworkUse = true

            startProgressUpdates()

            session.exportAsynchronously { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.stopProgressUpdates()
                    switch session.status {
                    case .completed:
                        self.isExporting = false
                        self.lastExportURL = package.outputURL
                        completion?(.success(package.outputURL))
                    case .failed, .cancelled:
                        let failure = session.error ?? CompositionBuilderError.missingAsset
                        self.handleFailure(failure, completion: completion)
                    default:
                        break
                    }
                }
            }
        } catch {
            handleFailure(error, completion: completion)
        }
    }

    func cancel() {
        exportSession?.cancelExport()
        stopProgressUpdates()
        exportSession = nil
        isExporting = false
        progress = 0
    }

    private func preset(for resolution: ExportResolution) -> String {
        switch resolution {
        case .p720:
            return AVAssetExportPreset1280x720
        case .p1080:
            return AVAssetExportPreset1920x1080
        case .p4K:
            return AVAssetExportPreset3840x2160
        }
    }

    private func startProgressUpdates() {
        timer?.invalidate()
        guard let session = exportSession else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.progress = Double(session.progress)
            }
        }
    }

    private func stopProgressUpdates() {
        timer?.invalidate()
        timer = nil
        progress = exportSession?.progress.doubleValue ?? 0
    }

    private func handleFailure(_ error: Error, completion: ((Result<URL, Error>) -> Void)?) {
        DispatchQueue.main.async {
            self.isExporting = false
            self.error = error
            completion?(.failure(error))
        }
    }
}

private extension Float {
    var doubleValue: Double { Double(self) }
}
