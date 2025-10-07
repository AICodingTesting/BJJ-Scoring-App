import AVFoundation
import CoreGraphics
import UIKit

/// Renders an animated scoreboard overlay onto a training video export.
final class OverlayRenderer {

    static func renderOverlay(
        from composition: AVMutableComposition,
        videoSize: CGSize,
        metadata: MatchMetadata,
        completion: @escaping (AVVideoComposition) -> Void
    ) {
        // Create video composition
        let videoComposition = AVMutableVideoComposition(propertiesOf: composition)

        // Build overlay layer
        let overlayLayer = buildOverlayLayer(from: metadata, videoSize: videoSize)

        // Combine video + overlay
        let parentLayer = CALayer()
        let videoLayer = CALayer()

        parentLayer.frame = CGRect(origin: .zero, size: videoSize)
        videoLayer.frame = CGRect(origin: .zero, size: videoSize)
        overlayLayer.frame = CGRect(origin: .zero, size: videoSize)

        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        completion(videoComposition)
    }

    /// Builds the overlay scoreboard layer.
    private static func buildOverlayLayer(from metadata: MatchMetadata, videoSize: CGSize) -> CALayer {
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: videoSize)
        overlayLayer.masksToBounds = true

        // Example scoreboard text
        let textLayer = CATextLayer()
        textLayer.string = "BJJ Score Tracker"
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.fontSize = 32
        textLayer.alignmentMode = .center
        textLayer.frame = CGRect(x: 0, y: 20, width: videoSize.width, height: 40)

        overlayLayer.addSublayer(textLayer)
        return overlayLayer
    }
}
