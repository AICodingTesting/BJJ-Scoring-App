import SwiftUI

struct MetadataView: View {
    @Binding var metadata: MatchMetadata

    var body: some View {
        Form {
            Section(header: Text("Match")) {
                TextField("Title", text: $metadata.title)
                TextField("Gym", text: $metadata.gym)
                DatePicker("Date", selection: $metadata.date, displayedComponents: .date)
                Toggle("Show Metadata During Playback", isOn: $metadata.displayDuringPlayback)
            }
            Section(header: Text("Competitors")) {
                TextField("Athlete A", text: $metadata.athleteAName)
                TextField("Athlete B", text: $metadata.athleteBName)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}
