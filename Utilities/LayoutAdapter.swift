import CoreGraphics

struct OverlayLayoutMetrics {
    let safeArea: CGRect
    let scoreboardFrame: CGRect
    let metadataFrame: CGRect
    let notesFrame: CGRect
}

enum LayoutAdapter {
    static func metrics(for aspect: ExportAspectRatio, in canvasSize: CGSize) -> OverlayLayoutMetrics {
        let inset: CGFloat = 40
        let safe = CGRect(origin: .zero, size: canvasSize).insetBy(dx: inset, dy: inset)
        let scoreboardHeight = safe.height * 0.12
        let scoreboardFrame = CGRect(
            x: safe.minX,
            y: safe.maxY - scoreboardHeight,
            width: safe.width,
            height: scoreboardHeight
        )
        let metadataHeight = safe.height * 0.08
        let metadataFrame = CGRect(
            x: safe.minX,
            y: safe.minY,
            width: safe.width,
            height: metadataHeight
        )
        let notesFrame = CGRect(
            x: safe.minX,
            y: safe.midY - safe.height * 0.1,
            width: safe.width,
            height: safe.height * 0.2
        )

        return OverlayLayoutMetrics(
            safeArea: safe,
            scoreboardFrame: scoreboardFrame,
            metadataFrame: metadataFrame,
            notesFrame: notesFrame
        )
    }
}
