import SwiftUI

struct ControlsView: View {
    var onScore: (Competitor, ScoreEventAction) -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                controlColumn(for: .athleteA, label: "\u{2190} Athlete A")
                controlColumn(for: .athleteB, label: "Athlete B \u{2192}")
            }

            HStack {
                Button(action: onUndo) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button(action: onRedo) {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func controlColumn(for competitor: Competitor, label: String) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    scoreButton(title: "+2", color: .green) { trigger(competitor, .points(2)) }
                    scoreButton(title: "-2", color: .gray) { trigger(competitor, .points(-2)) }
                }
                GridRow {
                    scoreButton(title: "+3", color: .green) { trigger(competitor, .points(3)) }
                    scoreButton(title: "-3", color: .gray) { trigger(competitor, .points(-3)) }
                }
                GridRow {
                    scoreButton(title: "+4", color: .green) { trigger(competitor, .points(4)) }
                    scoreButton(title: "-4", color: .gray) { trigger(competitor, .points(-4)) }
                }
                GridRow {
                    scoreButton(title: "+ADV", color: .yellow) { trigger(competitor, .advantage(1)) }
                    scoreButton(title: "-ADV", color: .gray) { trigger(competitor, .advantage(-1)) }
                }
                GridRow {
                    scoreButton(title: "+PEN", color: .red) { trigger(competitor, .penalty(1)) }
                    scoreButton(title: "-PEN", color: .gray) { trigger(competitor, .penalty(-1)) }
                }
            }
        }
    }

    private func scoreButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(width: 72, height: 38)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }

    private func trigger(_ competitor: Competitor, _ action: ScoreEventAction) {
        onScore(competitor, action)
        HapticsManager.impact()
    }
}
