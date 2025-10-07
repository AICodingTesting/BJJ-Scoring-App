import SwiftUI

struct ScoreOverlayView: View {
    var score: ScoreState
    var metadata: MatchMetadata
    var currentTime: Double

    var body: some View {
        VStack(spacing: 12) {
            if metadata.displayDuringPlayback {
                MetadataBanner(metadata: metadata, currentTime: currentTime)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Scoreboard(score: score, metadata: metadata)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

private struct MetadataBanner: View {
    var metadata: MatchMetadata
    var currentTime: Double

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(metadata.title.isEmpty ? "Match" : metadata.title)
                    .font(.title3.weight(.semibold))
                Text(metadata.gym)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(dateFormatter.string(from: metadata.date))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(TimeFormatter.string(from: currentTime))
                    .font(.headline.monospacedDigit())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct Scoreboard: View {
    var score: ScoreState
    var metadata: MatchMetadata

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.75))
                HStack(spacing: 0) {
                    ScoreColumn(
                        name: metadata.athleteAName,
                        breakdown: score.athleteA,
                        color: Color(red: 0.1, green: 0.4, blue: 0.8)
                    )
                    Divider()
                        .blendMode(.overlay)
                        .frame(width: 2)
                        .background(Color.white.opacity(0.25))
                    ScoreColumn(
                        name: metadata.athleteBName,
                        breakdown: score.athleteB,
                        color: Color(red: 0.8, green: 0.15, blue: 0.2)
                    )
                }
                .frame(width: width, height: height)
            }
        }
        .frame(height: 120)
    }
}

private struct ScoreColumn: View {
    var name: String
    var breakdown: ScoreBreakdown
    var color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(name.isEmpty ? "Athlete" : name)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                ScoreBox(title: "PTS", value: breakdown.points, tint: color)
                ScoreBox(title: "ADV", value: breakdown.advantages, tint: .yellow)
                ScoreBox(title: "PEN", value: breakdown.penalties, tint: .red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

private struct ScoreBox: View {
    var title: String
    var value: Int
    var tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
            Text("\(value)")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(width: 72, height: 72)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
