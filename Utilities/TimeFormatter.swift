import Foundation

enum TimeFormatter {
    static func string(from seconds: Double) -> String {
        guard seconds.isFinite else { return "--:--" }
        let totalSeconds = max(Int(seconds.rounded()), 0)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
