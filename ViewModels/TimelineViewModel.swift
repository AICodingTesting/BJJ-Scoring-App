import Foundation
import Combine

@MainActor
final class TimelineViewModel: ObservableObject {
    @Published private(set) var events: [ScoreEvent]
    @Published private(set) var notes: [MatchNote]
    @Published var currentScore: ScoreState

    private var undoStack: [[ScoreEvent]] = []
    private var redoStack: [[ScoreEvent]] = []

    init(events: [ScoreEvent] = [], notes: [MatchNote] = []) {
        self.events = events
        self.notes = notes
        self.currentScore = ScoreReducer.reduce(events: events)
    }

    func configure(events: [ScoreEvent], notes: [MatchNote]) {
        self.events = events
        self.notes = notes
        self.currentScore = ScoreReducer.reduce(events: events)
        clearHistory()
    }

    func state(at time: Double) -> ScoreState {
        let filtered = events.filter { $0.timestamp <= time }
        return ScoreReducer.reduce(events: filtered)
    }

    func updateCurrentScore(for time: Double) {
        currentScore = state(at: time)
    }

    func addEvent(_ event: ScoreEvent) {
        registerUndo()
        events.append(event)
        events.sort { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.timestamp < rhs.timestamp
        }
        redoStack.removeAll()
        currentScore = ScoreReducer.reduce(events: events)
    }

    func updateEvent(_ event: ScoreEvent) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        registerUndo()
        events[index] = event
        events.sort { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.timestamp < rhs.timestamp
        }
        redoStack.removeAll()
        currentScore = ScoreReducer.reduce(events: events)
    }

    func removeEvent(_ event: ScoreEvent) {
        guard events.contains(where: { $0.id == event.id }) else { return }
        registerUndo()
        events.removeAll { $0.id == event.id }
        redoStack.removeAll()
        currentScore = ScoreReducer.reduce(events: events)
    }

    func addNote(_ note: MatchNote) {
        notes.append(note)
        notes.sort { $0.timestamp < $1.timestamp }
    }

    func removeNote(_ note: MatchNote) {
        notes.removeAll { $0.id == note.id }
    }

    func notes(at time: Double, window: Double = 4) -> [MatchNote] {
        notes.filter { abs($0.timestamp - time) <= window }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(events)
        events = previous
        currentScore = ScoreReducer.reduce(events: events)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(events)
        events = next
        currentScore = ScoreReducer.reduce(events: events)
    }

    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    private func registerUndo() {
        undoStack.append(events)
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
}
