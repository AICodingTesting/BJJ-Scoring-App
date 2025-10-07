import Foundation
import CoreMedia

enum ScoreEventAction: Codable, Equatable {
    case points(Int)
    case advantage(Int)
    case penalty(Int)

    var delta: Int {
        switch self {
        case .points(let value), .advantage(let value), .penalty(let value):
            return value
        }
    }

    var label: String {
        switch self {
        case .points:
            return "Points"
        case .advantage:
            return "Advantage"
        case .penalty:
            return "Penalty"
        }
    }
}

struct ScoreEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var timestamp: Double
    var competitor: Competitor
    var action: ScoreEventAction
    var createdAt: Date

    init(id: UUID = UUID(), timestamp: Double, competitor: Competitor, action: ScoreEventAction, createdAt: Date = Date()) {
        self.id = id
        self.timestamp = timestamp
        self.competitor = competitor
        self.action = action
        self.createdAt = createdAt
    }
}

extension ScoreEvent {
    var timecode: CMTime {
        CMTime(seconds: timestamp, preferredTimescale: 600)
    }
}
