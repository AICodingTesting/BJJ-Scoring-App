import Foundation

struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var title: String
    var videoBookmark: Data?
    var videoFilename: String?
    var duration: Double
    var events: [ScoreEvent]
    var notes: [MatchNote]
    var metadata: MatchMetadata
    var exportPreferences: ExportPreferences

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        title: String = "New Match",
        videoBookmark: Data? = nil,
        videoFilename: String? = nil,
        duration: Double = 0,
        events: [ScoreEvent] = [],
        notes: [MatchNote] = [],
        metadata: MatchMetadata = .empty(),
        exportPreferences: ExportPreferences = .default
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.videoBookmark = videoBookmark
        self.videoFilename = videoFilename
        self.duration = duration
        self.events = events
        self.notes = notes
        self.metadata = metadata
        self.exportPreferences = exportPreferences
    }
}

extension Project {
    static let sample = Project()
}
