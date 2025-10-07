import Foundation

struct MatchNote: Identifiable, Codable, Equatable {
    let id: UUID
    var timestamp: Double
    var text: String
    var isPinned: Bool

    init(id: UUID = UUID(), timestamp: Double, text: String, isPinned: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.isPinned = isPinned
    }
}
