import Foundation
import CoreGraphics

enum ExportResolution: String, CaseIterable, Codable, Identifiable {
    case p720
    case p1080
    case p4K

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .p720:
            return CGSize(width: 1280, height: 720)
        case .p1080:
            return CGSize(width: 1920, height: 1080)
        case .p4K:
            return CGSize(width: 3840, height: 2160)
        }
    }

    var displayName: String {
        switch self {
        case .p720:
            return "720p"
        case .p1080:
            return "1080p"
        case .p4K:
            return "4K"
        }
    }
}

enum ExportAspectRatio: String, CaseIterable, Codable, Identifiable {
    case landscape16x9
    case portrait9x16
    case square1x1

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .landscape16x9:
            return "16:9"
        case .portrait9x16:
            return "9:16"
        case .square1x1:
            return "1:1"
        }
    }

    var aspect: CGSize {
        switch self {
        case .landscape16x9:
            return CGSize(width: 16, height: 9)
        case .portrait9x16:
            return CGSize(width: 9, height: 16)
        case .square1x1:
            return CGSize(width: 1, height: 1)
        }
    }
}

struct WatermarkSettings: Codable, Equatable {
    enum Position: String, CaseIterable, Codable, Identifiable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
        case center

        var id: String { rawValue }
    }

    var imageBookmark: Data?
    var opacity: Double
    var position: Position

    static let `default` = WatermarkSettings(imageBookmark: nil, opacity: 0.65, position: .topRight)
}

struct ExportPreferences: Codable, Equatable {
    var resolution: ExportResolution
    var aspectRatio: ExportAspectRatio
    var includeMetadata: Bool
    var includeNotes: Bool
    var watermark: WatermarkSettings

    static let `default` = ExportPreferences(
        resolution: .p1080,
        aspectRatio: .landscape16x9,
        includeMetadata: true,
        includeNotes: true,
        watermark: .default
    )
}
