import Foundation

enum Competitor: String, Codable, CaseIterable, Identifiable {
    case athleteA
    case athleteB

    var id: String { rawValue }

    var displayNameDefault: String {
        switch self {
        case .athleteA:
            return "Athlete A"
        case .athleteB:
            return "Athlete B"
        }
    }
}
