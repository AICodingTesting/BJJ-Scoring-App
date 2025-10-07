import SwiftUI

struct EventHistoryView: View {
    var events: [ScoreEvent]
    var onEdit: (ScoreEvent) -> Void
    var onDelete: (ScoreEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event History")
                .font(.title3.weight(.semibold))
            if events.isEmpty {
                Text("No scoring events yet")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(events) { event in
                        Button {
                            onEdit(event)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(eventDescription(event))
                                        .font(.subheadline.weight(.semibold))
                                    Text(TimeFormatter.string(from: event.timestamp))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    onDelete(event)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxHeight: 260)
                .listStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func eventDescription(_ event: ScoreEvent) -> String {
        let competitor = event.competitor == .athleteA ? "Athlete A" : "Athlete B"
        return "\(competitor): \(event.action.label) \(event.action.delta >= 0 ? "+" : "")\(event.action.delta)"
    }
}
