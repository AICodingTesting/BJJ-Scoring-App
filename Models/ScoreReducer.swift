import Foundation

struct ScoreReducer {
    static func reduce(events: [ScoreEvent]) -> ScoreState {
        var state = ScoreState()
        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            state = apply(event, to: state)
        }
        return state
    }

    static func apply(_ event: ScoreEvent, to state: ScoreState) -> ScoreState {
        var newState = state
        let delta = event.action.delta
        var breakdown = state.breakdown(for: event.competitor)

        switch event.action {
        case .points:
            breakdown.points += delta
        case .advantage:
            breakdown.advantages += delta
        case .penalty:
            breakdown.penalties += delta
        }

        switch event.competitor {
        case .athleteA:
            newState.athleteA = breakdown
        case .athleteB:
            newState.athleteB = breakdown
        }

        return newState
    }
}
