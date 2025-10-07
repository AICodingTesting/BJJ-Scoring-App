import Foundation
import AVFoundation
import CoreGraphics
import QuartzCore

struct ExportPackage {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition
    let outputURL: URL
}

enum CompositionBuilderError: Error {
    case missingVideoTrack
    case missingAsset
}

final class CompositionBuilder {
    private let overlayRenderer = OverlayRenderer()

    func build(from sourceURL: URL, project: Project) throws -> ExportPackage {
        let asset = AVURLAsset(url: sourceURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else { throw CompositionBuilderError.missingVideoTrack }

        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw CompositionBuilderError.missingVideoTrack
        }
        try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: .zero)
        compositionVideoTrack.preferredTransform = videoTrack.preferredTransform

        if let audioTrack = asset.tracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: audioTrack, at: .zero)
        }

        let renderSize = targetRenderSize(for: videoTrack, preferences: project.exportPreferences)
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        let transform = transformForAspectFit(track: videoTrack, renderSize: renderSize)
        layerInstruction.setTransform(transform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        let snapshot = TimelineSnapshot(
            duration: CMTimeGetSeconds(asset.duration),
            events: project.events,
            notes: project.notes,
            metadata: project.metadata,
            preferences: project.exportPreferences
        )
        let overlay = overlayRenderer.makeOverlay(configuration: OverlayConfiguration(renderSize: renderSize), snapshot: snapshot)

        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlay)

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        return ExportPackage(composition: composition, videoComposition: videoComposition, outputURL: tempURL)
    }

    private func targetRenderSize(for track: AVAssetTrack, preferences: ExportPreferences) -> CGSize {
        let baseSize = preferences.resolution.size
        let aspect = preferences.aspectRatio.aspect
        let width: CGFloat
        let height: CGFloat
        switch preferences.aspectRatio {
        case .landscape16x9:
            width = baseSize.width
            height = baseSize.height
        case .portrait9x16:
            width = baseSize.height * (aspect.width / aspect.height)
            height = baseSize.height
        case .square1x1:
            width = min(baseSize.width, baseSize.height)
            height = width
        }
        return CGSize(width: width.rounded(.towardZero), height: height.rounded(.towardZero))
    }

    private func transformForAspectFit(track: AVAssetTrack, renderSize: CGSize) -> CGAffineTransform {
        var transform = track.preferredTransform
        let naturalSize = track.naturalSize.applying(transform)
        let videoSize = CGSize(width: abs(naturalSize.width), height: abs(naturalSize.height))

        let scale = min(renderSize.width / videoSize.width, renderSize.height / videoSize.height)
        let scaledSize = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
        let x = (renderSize.width - scaledSize.width) / 2
        let y = (renderSize.height - scaledSize.height) / 2

        var finalTransform = transform
        finalTransform = finalTransform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        finalTransform = finalTransform.concatenating(CGAffineTransform(translationX: x, y: y))
        return finalTransform
    }
}
