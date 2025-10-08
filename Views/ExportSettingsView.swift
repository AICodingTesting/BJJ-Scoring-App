import SwiftUI

struct ExportSettingsView: View {
    @Binding var preferences: ExportPreferences
    var onExport: @Sendable () -> Void
    var isExporting: Bool
    var progress: Double

    var body: some View {
        Form {
            Section(header: Text("Resolution")) {
                Picker("Resolution", selection: $preferences.resolution) {
                    ForEach(ExportResolution.allCases) { resolution in
                        Text(resolution.displayName).tag(resolution)
                    }
                }
            }
            Section(header: Text("Aspect Ratio")) {
                Picker("Aspect", selection: $preferences.aspectRatio) {
                    ForEach(ExportAspectRatio.allCases) { aspect in
                        Text(aspect.displayName).tag(aspect)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section(header: Text("Options")) {
                Toggle("Include Metadata", isOn: $preferences.includeMetadata)
                Toggle("Include Notes", isOn: $preferences.includeNotes)
                Toggle("Use Watermark", isOn: Binding(
                    get: { preferences.watermark.imageBookmark != nil },
                    set: { use in
                        if !use {
                            preferences.watermark.imageBookmark = nil
                        }
                    }
                ))
                Stepper(value: $preferences.watermark.opacity, in: 0.1...1.0, step: 0.05) {
                    Text("Watermark Opacity \(String(format: "%.0f%%", preferences.watermark.opacity * 100))")
                }
                Picker("Watermark Position", selection: $preferences.watermark.position) {
                    ForEach(WatermarkSettings.Position.allCases) { position in
                        Text(position.rawValue.capitalized).tag(position)
                    }
                }
            }
            Section {
                Button(action: onExport) {
                    if isExporting {
                        ProgressView(value: progress)
                    } else {
                        Label("Export Video", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(isExporting)
            }
        }
        .formStyle(.grouped)
    }
}
