import Foundation

struct ScoreBreakdown: Codable, Equatable {
    var points: Int
    var advantages: Int
    var penalties: Int

    static let zero = ScoreBreakdown(points: 0, advantages: 0, penalties: 0)
}

struct ScoreState: Codable, Equatable {
    var athleteA: ScoreBreakdown
    var athleteB: ScoreBreakdown

    init(athleteA: ScoreBreakdown = .zero, athleteB: ScoreBreakdown = .zero) {
        self.athleteA = athleteA
        self.athleteB = athleteB
    }

    func breakdown(for competitor: Competitor) -> ScoreBreakdown {
        switch competitor {
        case .athleteA:
            return athleteA
        case .athleteB:
            return athleteB
        }
    }
}
