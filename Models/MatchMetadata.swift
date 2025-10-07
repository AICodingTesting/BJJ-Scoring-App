import Foundation

struct MatchMetadata: Codable, Equatable {
    var title: String
    var athleteAName: String
    var athleteBName: String
    var gym: String
    var date: Date
    var displayDuringPlayback: Bool

    static func empty() -> MatchMetadata {
        MatchMetadata(
            title: "",
            athleteAName: "Athlete A",
            athleteBName: "Athlete B",
            gym: "",
            date: Date(),
            displayDuringPlayback: true
        )
    }
}
