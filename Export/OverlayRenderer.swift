import Foundation
import QuartzCore
import CoreGraphics
import UIKit
import AVFoundation

struct TimelineSnapshot {
    let duration: Double
    let events: [ScoreEvent]
    let notes: [MatchNote]
    let metadata: MatchMetadata
    let preferences: ExportPreferences
}

final class OverlayRenderer {
    func makeOverlay(configuration: OverlayConfiguration, snapshot: TimelineSnapshot) -> CALayer {
        let parent = CALayer()
        parent.frame = CGRect(origin: .zero, size: configuration.renderSize)
        parent.masksToBounds = true

        let metrics = LayoutAdapter.metrics(for: snapshot.preferences.aspectRatio, in: configuration.renderSize)

        if snapshot.preferences.includeMetadata && snapshot.metadata.displayDuringPlayback {
            let metadataLayer = makeMetadataLayer(frame: metrics.metadataFrame, metadata: snapshot.metadata)
            parent.addSublayer(metadataLayer)
        }

        let scoreboardLayer = makeScoreboardLayer(frame: metrics.scoreboardFrame, snapshot: snapshot)
        parent.addSublayer(scoreboardLayer)

        if snapshot.preferences.includeNotes {
            let notesLayer = makeNotesLayer(frame: metrics.notesFrame, snapshot: snapshot)
            parent.addSublayer(notesLayer)
        }

        if let watermarkLayer = makeWatermarkLayer(frame: metrics.safeArea, watermark: snapshot.preferences.watermark, renderSize: configuration.renderSize) {
            parent.addSublayer(watermarkLayer)
        }

        return parent
    }

    private func makeMetadataLayer(frame: CGRect, metadata: MatchMetadata) -> CALayer {
        let layer = CALayer()
        layer.frame = frame

        let background = CALayer()
        background.frame = layer.bounds
        background.backgroundColor = UIColor.black.withAlphaComponent(0.35).cgColor
        background.cornerRadius = 24
        layer.addSublayer(background)

        let titleLayer = textLayer(text: metadata.title.isEmpty ? "Match" : metadata.title, fontSize: 36, weight: .semibold, alignment: .left)
        titleLayer.frame = CGRect(x: 24, y: 8, width: frame.width - 48, height: frame.height / 2)
        layer.addSublayer(titleLayer)

        let subtitle = [metadata.athleteAName, metadata.athleteBName].joined(separator: " vs ")
        let subtitleLayer = textLayer(text: subtitle, fontSize: 24, weight: .regular, alignment: .left)
        subtitleLayer.frame = CGRect(x: 24, y: frame.height / 2, width: frame.width - 48, height: frame.height / 2 - 8)
        layer.addSublayer(subtitleLayer)

        return layer
    }

    private func makeScoreboardLayer(frame: CGRect, snapshot: TimelineSnapshot) -> CALayer {
        let layer = CALayer()
        layer.frame = frame
        layer.cornerRadius = frame.height / 2
        layer.backgroundColor = UIColor.black.withAlphaComponent(0.75).cgColor

        let padding: CGFloat = 24
        let columnWidth = (frame.width - padding * 3) / 2
        let columnHeight = frame.height - padding * 2

        let leftColumnFrame = CGRect(x: padding, y: padding, width: columnWidth, height: columnHeight)
        let rightColumnFrame = CGRect(x: frame.width - columnWidth - padding, y: padding, width: columnWidth, height: columnHeight)

        let athleteANameLayer = textLayer(text: snapshot.metadata.athleteAName, fontSize: 28, weight: .bold, alignment: .left)
        athleteANameLayer.frame = CGRect(x: leftColumnFrame.minX, y: leftColumnFrame.minY, width: columnWidth, height: 32)
        layer.addSublayer(athleteANameLayer)

        let athleteBNameLayer = textLayer(text: snapshot.metadata.athleteBName, fontSize: 28, weight: .bold, alignment: .right)
        athleteBNameLayer.frame = CGRect(x: rightColumnFrame.minX, y: rightColumnFrame.minY, width: columnWidth, height: 32)
        layer.addSublayer(athleteBNameLayer)

        let scoreboardEntries = buildScoreEntries(snapshot: snapshot)
        let keyTimes = scoreboardEntries.map { NSNumber(value: $0.time / max(snapshot.duration, 0.1)) }

        let athleteAPoints = makeValueLayer(initial: "0", frame: CGRect(x: leftColumnFrame.minX, y: leftColumnFrame.minY + 40, width: columnWidth / 3, height: 60), color: UIColor.systemGreen)
        layer.addSublayer(athleteAPoints)
        athleteAPoints.add(animation(values: scoreboardEntries.map { "\($0.state.athleteA.points)" }, keyTimes: keyTimes, duration: snapshot.duration), forKey: "points")

        let athleteAAdvantages = makeValueLayer(initial: "0", frame: CGRect(x: leftColumnFrame.minX + columnWidth / 3 + 12, y: leftColumnFrame.minY + 40, width: columnWidth / 3, height: 60), color: UIColor.systemYellow)
        layer.addSublayer(athleteAAdvantages)
        athleteAAdvantages.add(animation(values: scoreboardEntries.map { "\($0.state.athleteA.advantages)" }, keyTimes: keyTimes, duration: snapshot.duration), forKey: "advantages")

        let athleteAPenalties = makeValueLayer(initial: "0", frame: CGRect(x: leftColumnFrame.minX + columnWidth * 2 / 3 + 24, y: leftColumnFrame.minY + 40, width: columnWidth / 3, height: 60), color: UIColor.systemRed)
        layer.addSublayer(athleteAPenalties)
        athleteAPenalties.add(animation(values: scoreboardEntries.map { "\($0.state.athleteA.penalties)" }, keyTimes: keyTimes, duration: snapshot.duration), forKey: "penalties")

        let athleteBPoints = makeValueLayer(initial: "0", frame: CGRect(x: rightColumnFrame.maxX - columnWidth / 3, y: rightColumnFrame.minY + 40, width: columnWidth / 3, height: 60), color: UIColor.systemGreen)
        layer.addSublayer(athleteBPoints)
        athleteBPoints.add(animation(values: scoreboardEntries.map { "\($0.state.athleteB.points)" }, keyTimes: keyTimes, duration: snapshot.duration), forKey: "points")

        let athleteBAdvantages = makeValueLayer(initial: "0", frame: CGRect(x: rightColumnFrame.maxX - columnWidth * 2 / 3 - 12, y: rightColumnFrame.minY + 40, width: columnWidth / 3, height: 60), color: UIColor.systemYellow)
        layer.addSublayer(athleteBAdvantages)
        athleteBAdvantages.add(animation(values: scoreboardEntries.map { "\($0.state.athleteB.advantages)" }, keyTimes: keyTimes, duration: snapshot.duration), forKey: "advantages")

        let athleteBPenalties = makeValueLayer(initial: "0", frame: CGRect(x: rightColumnFrame.minX, y: rightColumnFrame.minY + 40, width: columnWidth / 3, height: 60), color: UIColor.systemRed)
        layer.addSublayer(athleteBPenalties)
        athleteBPenalties.add(animation(values: scoreboardEntries.map { "\($0.state.athleteB.penalties)" }, keyTimes: keyTimes, duration: snapshot.duration), forKey: "penalties")

        let clockLayer = makeValueLayer(initial: "00:00", frame: CGRect(x: frame.midX - 80, y: frame.minY + 20, width: 160, height: 48), color: UIColor.white)
        layer.addSublayer(clockLayer)
        clockLayer.add(animation(values: scoreboardEntries.map { TimeFormatter.string(from: $0.time) }, keyTimes: keyTimes, duration: snapshot.duration), forKey: "clock")

        return layer
    }

    private func makeNotesLayer(frame: CGRect, snapshot: TimelineSnapshot) -> CALayer {
        let container = CALayer()
        container.frame = frame

        for note in snapshot.notes {
            let noteLayer = textLayer(text: note.text, fontSize: 24, weight: .medium, alignment: .center)
            let height = frame.height / 3
            noteLayer.frame = CGRect(x: 16, y: (frame.height - height) / 2, width: frame.width - 32, height: height)
            noteLayer.backgroundColor = UIColor.black.withAlphaComponent(0.45).cgColor
            noteLayer.cornerRadius = 16
            noteLayer.opacity = 0

            let appear = CABasicAnimation(keyPath: "opacity")
            appear.fromValue = 0
            appear.toValue = 1
            appear.duration = 0.3
            appear.beginTime = snapshot.animationTime(for: note.timestamp)
            appear.fillMode = .forwards
            appear.isRemovedOnCompletion = false

            let disappear = CABasicAnimation(keyPath: "opacity")
            disappear.fromValue = 1
            disappear.toValue = 0
            disappear.duration = 0.4
            disappear.beginTime = snapshot.animationTime(for: note.timestamp + 4)
            disappear.fillMode = .forwards
            disappear.isRemovedOnCompletion = false

            let group = CAAnimationGroup()
            group.animations = [appear, disappear]
            group.duration = snapshot.duration + 5
            group.beginTime = AVCoreAnimationBeginTimeAtZero
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false

            noteLayer.add(group, forKey: "note_\(note.id.uuidString)")
            container.addSublayer(noteLayer)
        }

        return container
    }

    private func makeWatermarkLayer(frame: CGRect, watermark: WatermarkSettings, renderSize: CGSize) -> CALayer? {
        guard let data = watermark.imageBookmark, let url = BookmarkResolver.resolveBookmark(data) else { return nil }
        guard let image = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
        let layer = CALayer()
        layer.contents = image
        layer.opacity = Float(watermark.opacity)
        let size = CGSize(width: renderSize.width * 0.15, height: renderSize.height * 0.15)
        let origin: CGPoint
        switch watermark.position {
        case .topLeft:
            origin = CGPoint(x: frame.minX + 24, y: frame.minY + 24)
        case .topRight:
            origin = CGPoint(x: frame.maxX - size.width - 24, y: frame.minY + 24)
        case .bottomLeft:
            origin = CGPoint(x: frame.minX + 24, y: frame.maxY - size.height - 24)
        case .bottomRight:
            origin = CGPoint(x: frame.maxX - size.width - 24, y: frame.maxY - size.height - 24)
        case .center:
            origin = CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
        }
        layer.frame = CGRect(origin: origin, size: size)
        return layer
    }

    private func makeValueLayer(initial: String, frame: CGRect, color: UIColor) -> CATextLayer {
        let layer = textLayer(text: initial, fontSize: 48, weight: .heavy, alignment: .center)
        layer.frame = frame
        layer.foregroundColor = color.cgColor
        layer.backgroundColor = UIColor.white.withAlphaComponent(0.18).cgColor
        layer.cornerRadius = 12
        return layer
    }

    private func animation(values: [String], keyTimes: [NSNumber], duration: Double) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "string")
        animation.values = values
        animation.keyTimes = keyTimes
        animation.calculationMode = .discrete
        animation.duration = max(duration, 0.1)
        animation.beginTime = AVCoreAnimationBeginTimeAtZero
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        return animation
    }

    private func textLayer(text: String, fontSize: CGFloat, weight: UIFont.Weight, alignment: CATextLayerAlignmentMode) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = text
        layer.alignmentMode = alignment
        layer.contentsScale = UIScreen.main.scale
        layer.fontSize = fontSize
        layer.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        layer.foregroundColor = UIColor.white.cgColor
        return layer
    }

    private func buildScoreEntries(snapshot: TimelineSnapshot) -> [ScoreEntry] {
        var entries: [ScoreEntry] = []
        var running = ScoreState()
        entries.append(ScoreEntry(time: 0, state: running))
        let sorted = snapshot.events.sorted { $0.timestamp < $1.timestamp }
        for event in sorted {
            running = ScoreReducer.apply(event, to: running)
            entries.append(ScoreEntry(time: min(event.timestamp, snapshot.duration), state: running))
        }
        if let last = entries.last, last.time < snapshot.duration {
            entries.append(ScoreEntry(time: snapshot.duration, state: last.state))
        }
        return entries
    }
}

private struct ScoreEntry {
    let time: Double
    let state: ScoreState
}

struct OverlayConfiguration {
    let renderSize: CGSize
}

private extension TimelineSnapshot {
    func animationTime(for timestamp: Double) -> CFTimeInterval {
        guard duration > 0 else { return AVCoreAnimationBeginTimeAtZero }
        let ratio = max(0, min(timestamp / duration, 1))
        return AVCoreAnimationBeginTimeAtZero + CFTimeInterval(ratio * duration)
    }
}
