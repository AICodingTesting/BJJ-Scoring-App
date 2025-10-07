import UIKit
import CoreHaptics

enum HapticsManager {
    private static let supportsHaptics: Bool = {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }()

    static func impact() {
        guard supportsHaptics else { return }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
}
