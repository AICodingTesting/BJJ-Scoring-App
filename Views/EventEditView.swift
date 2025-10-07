import SwiftUI

struct EventEditView: View {
    @State private var workingEvent: ScoreEvent
    var onSave: (ScoreEvent) -> Void
    var onCancel: () -> Void

    init(event: ScoreEvent, onSave: @escaping (ScoreEvent) -> Void, onCancel: @escaping () -> Void) {
        _workingEvent = State(initialValue: event)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Competitor")) {
                    Picker("Competitor", selection: $workingEvent.competitor) {
                        ForEach(Competitor.allCases) { competitor in
                            Text(competitor.displayNameDefault).tag(competitor)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text("Action")) {
                    Picker("Type", selection: bindingForActionType()) {
                        ForEach(ActionType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    Stepper(value: bindingForActionValue(), in: -10...10, step: 1) {
                        Text("Delta \(bindingForActionValue().wrappedValue)")
                    }
                }
                Section(header: Text("Timestamp")) {
                    Slider(value: $workingEvent.timestamp, in: 0...max(workingEvent.timestamp, 0) + 600, step: 0.1)
                    Text(TimeFormatter.string(from: workingEvent.timestamp))
                        .font(.headline.monospacedDigit())
                }
            }
            .navigationTitle("Edit Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(workingEvent)
                    }
                }
            }
        }
    }

    private func bindingForActionType() -> Binding<ActionType> {
        Binding<ActionType>(
            get: {
                switch workingEvent.action {
                case .points:
                    return .points
                case .advantage:
                    return .advantage
                case .penalty:
                    return .penalty
                }
            },
            set: { newValue in
                let value = bindingForActionValue().wrappedValue
                switch newValue {
                case .points:
                    workingEvent.action = .points(value)
                case .advantage:
                    workingEvent.action = .advantage(value)
                case .penalty:
                    workingEvent.action = .penalty(value)
                }
            }
        )
    }

    private func bindingForActionValue() -> Binding<Int> {
        Binding<Int>(
            get: {
                workingEvent.action.delta
            },
            set: { newValue in
                switch workingEvent.action {
                case .points:
                    workingEvent.action = .points(newValue)
                case .advantage:
                    workingEvent.action = .advantage(newValue)
                case .penalty:
                    workingEvent.action = .penalty(newValue)
                }
            }
        )
    }

    private enum ActionType: String, CaseIterable, Identifiable {
        case points
        case advantage
        case penalty

        var id: String { rawValue }

        var title: String {
            rawValue.capitalized
        }
    }
}
