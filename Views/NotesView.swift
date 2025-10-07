import SwiftUI

struct NotesView: View {
    var notes: [MatchNote]
    var onAdd: (String) -> Void
    var onDelete: (MatchNote) -> Void

    @State private var noteText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.title3.weight(.semibold))
            HStack {
                TextField("Add note", text: $noteText)
                    .textFieldStyle(.roundedBorder)
                Button(action: submit) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if notes.isEmpty {
                Text("No notes yet")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(notes) { note in
                        HStack {
                            Text(TimeFormatter.string(from: note.timestamp))
                                .font(.subheadline.monospacedDigit())
                                .frame(width: 60, alignment: .leading)
                            Text(note.text)
                                .font(.body)
                            Spacer()
                            Button {
                                onDelete(note)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                }
                .frame(maxHeight: 220)
                .listStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func submit() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed)
        noteText = ""
    }
}
