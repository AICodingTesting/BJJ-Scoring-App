import AVFoundation
import UIKit

/// Builds a full export composition with synchronized video and overlay.
final class CompositionBuilder {

    static func buildComposition(
        with videoAsset: AVAsset,
        metadata: MatchMetadata,
        completion: @escaping @MainActor (AVAssetExportSession?) -> Void
    ) async {
        // 1. Create composition
        let composition = AVMutableComposition()

        guard
            let track = try? await videoAsset.loadTracks(withMediaType: .video).first,
            let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else {
            await completion(nil)
            return
        }

        do {
            let duration = try await videoAsset.load(.duration)
            try videoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: track,
                at: .zero
            )
        } catch {
            print("❌ Composition insert error:", error)
            await completion(nil)
            return
        }

        // 2. Create overlay composition
        do {
            let videoSize = try await track.load(.naturalSize)
            OverlayRenderer.renderOverlay(from: composition, videoSize: videoSize, metadata: metadata) { videoComposition in
                // 3. Export session
                guard let export = AVAssetExportSession(
                    asset: composition,
                    presetName: AVAssetExportPresetHighestQuality
                ) else {
                    Task { @MainActor in
                        completion(nil)
                    }
                    return
                }

                export.videoComposition = videoComposition
                export.outputFileType = AVFileType.mp4
                export.outputURL = makeExportURL()
                export.shouldOptimizeForNetworkUse = true

                Task { @MainActor in
                    completion(export)
                }
            }
        } catch {
            print("❌ Error loading video size:", error)
            await completion(nil)
            return
        }
    }

    private static func makeExportURL() -> URL {
        let filename = "bjj_export_\(UUID().uuidString).mp4"
        let documents = FileManager.default.temporaryDirectory
        return documents.appendingPathComponent(filename)
    }
}
