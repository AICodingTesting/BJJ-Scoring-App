import SwiftUI
import PhotosUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject private var projectStore: ProjectStore
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @EnvironmentObject private var timelineViewModel: TimelineViewModel
    @EnvironmentObject private var exportViewModel: ExportViewModel

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showingVideoMissingAlert = false
    @State private var editingEvent: ScoreEvent?
    @State private var isPresentingExportResult = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    videoSection
                    layoutColumns
                }
                .padding()
            }
            .navigationTitle(projectStore.currentProject.title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $photoPickerItem, matching: .videos, photoLibrary: .shared()) {
                        Label("Import Video", systemImage: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        exportCurrent()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(playerViewModel.player == nil)
                }
            }
            .alert("Video Missing", isPresented: $showingVideoMissingAlert, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text("The original video could not be found. Please re-link from the Photos picker.")
            })
            .sheet(item: $editingEvent) { event in
                EventEditView(event: event) { updated in
                    timelineViewModel.updateEvent(updated)
                    persistTimeline()
                    editingEvent = nil
                } onCancel: {
                    editingEvent = nil
                }
            }
            .onChange(of: photoPickerItem) { item in
                guard let item else { return }
                Task { await handlePickerItem(item) }
            }
            .onChange(of: playerViewModel.currentTime) { time in
                timelineViewModel.updateCurrentScore(for: time)
            }
            .onReceive(projectStore.$currentProject) { project in
                timelineViewModel.configure(events: project.events, notes: project.notes)
            }
            .onAppear {
                timelineViewModel.configure(events: projectStore.currentProject.events, notes: projectStore.currentProject.notes)
                if let url = BookmarkResolver.resolveBookmark(projectStore.currentProject.videoBookmark) {
                    playerViewModel.load(url: url)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if exportViewModel.isExporting {
                ProgressView(value: exportViewModel.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding()
            }
        }
        .alert("Export Complete", isPresented: Binding(
            get: { exportViewModel.lastExportURL != nil && !exportViewModel.isExporting },
            set: { newValue in
                if !newValue {
                    exportViewModel.lastExportURL = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
            if let url = exportViewModel.lastExportURL {
                ShareLink(item: url) {
                    Text("Share")
                }
            }
        } message: {
            Text("Your exported video is ready.")
        }
        .alert("Export Failed", isPresented: Binding(
            get: { exportViewModel.error != nil },
            set: { newValue in if !newValue { exportViewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportViewModel.error?.localizedDescription ?? "Unknown error")
        }
    }

    private var videoSection: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        VideoPlayerView(player: playerViewModel.player)
                            .overlay(
                                VStack {
                                    Spacer()
                                    ScoreOverlayView(
                                        score: timelineViewModel.currentScore,
                                        metadata: projectStore.currentProject.metadata,
                                        currentTime: playerViewModel.currentTime
                                    )
                                    .padding(.bottom, 16)
                                }
                            )
                    )
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(alignment: .bottom) {
                        noteOverlay
                    }
            }

            playbackControls
            timelineSlider
        }
    }

    private var noteOverlay: some View {
        VStack {
            if let note = timelineViewModel.notes(at: playerViewModel.currentTime).first {
                Text(note.text)
                    .font(.headline)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 80)
    }

    private var playbackControls: some View {
        HStack(spacing: 24) {
            Button {
                playerViewModel.rewind(by: 5)
            } label: {
                Label("Rewind", systemImage: "gobackward.5")
            }
            .buttonStyle(.bordered)

            Button {
                playerViewModel.playPause()
            } label: {
                Label(playerViewModel.isPlaying ? "Pause" : "Play", systemImage: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
            Text(TimeFormatter.string(from: playerViewModel.currentTime))
                .font(.headline.monospacedDigit())
            Text(TimeFormatter.string(from: playerViewModel.duration))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var timelineSlider: some View {
        Slider(
            value: Binding(
                get: { playerViewModel.currentTime },
                set: { newValue in
                    playerViewModel.seek(to: newValue)
                    timelineViewModel.updateCurrentScore(for: newValue)
                }
            ),
            in: 0...max(playerViewModel.duration, 1)
        )
    }

    private var layoutColumns: some View {
        AdaptiveStack(spacing: 24) {
            VStack(spacing: 24) {
                ControlsView { competitor, action in
                    addEvent(for: competitor, action: action)
                } onUndo: {
                    timelineViewModel.undo()
                    persistTimeline()
                } onRedo: {
                    timelineViewModel.redo()
                    persistTimeline()
                }

                EventHistoryView(events: timelineViewModel.events) { event in
                    editingEvent = event
                } onDelete: { event in
                    timelineViewModel.removeEvent(event)
                    persistTimeline()
                }

                NotesView(notes: timelineViewModel.notes) { text in
                    let note = MatchNote(timestamp: playerViewModel.currentTime, text: text)
                    timelineViewModel.addNote(note)
                    persistNotes()
                } onDelete: { note in
                    timelineViewModel.removeNote(note)
                    persistNotes()
                }
            }

            VStack(spacing: 24) {
                MetadataView(metadata: binding(
                    get: { projectStore.currentProject.metadata },
                    set: { metadata in
                        updateProject { $0.metadata = metadata }
                    }
                ))
                .frame(maxHeight: 420)

                ExportSettingsView(
                    preferences: binding(
                        get: { projectStore.currentProject.exportPreferences },
                        set: { prefs in
                            updateProject { $0.exportPreferences = prefs }
                        }
                    ),
                    onExport: exportCurrent,
                    isExporting: exportViewModel.isExporting,
                    progress: exportViewModel.progress
                )
                .frame(maxHeight: 420)
            }
        }
    }

    private func addEvent(for competitor: Competitor, action: ScoreEventAction) {
        let event = ScoreEvent(timestamp: playerViewModel.currentTime, competitor: competitor, action: action)
        timelineViewModel.addEvent(event)
        persistTimeline()
    }

    private func persistTimeline() {
        updateProject { project in
            project.events = timelineViewModel.events
            project.updatedAt = Date()
        }
    }

    private func persistNotes() {
        updateProject { project in
            project.notes = timelineViewModel.notes
            project.updatedAt = Date()
        }
    }

    private func exportCurrent() {
        guard let url = BookmarkResolver.resolveBookmark(projectStore.currentProject.videoBookmark) else {
            showingVideoMissingAlert = true
            return
        }
        exportViewModel.export(project: projectStore.currentProject, sourceURL: url)
    }

    private func handlePickerItem(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
                try data.write(to: tempURL)
                await MainActor.run {
                    loadVideo(url: tempURL, filename: item.itemIdentifier ?? tempURL.lastPathComponent)
                }
            }
        } catch {
            print("Failed to load video: \(error)")
        }
    }

    private func loadVideo(url: URL, filename: String) {
        playerViewModel.load(url: url)
        if let bookmark = BookmarkResolver.bookmark(for: url) {
            updateProject { project in
                project.videoBookmark = bookmark
                project.videoFilename = filename
                project.duration = playerViewModel.duration
            }
        }
    }

    private func updateProject(_ update: (inout Project) -> Void) {
        var project = projectStore.currentProject
        update(&project)
        project.updatedAt = Date()
        projectStore.currentProject = project
    }

    private func binding<Value>(get: @escaping () -> Value, set: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(get: get, set: set)
    }
}

private struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: () -> Content

    @Environment(\.horizontalSizeClass) private var sizeClass

    init(spacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if sizeClass == .compact {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
        } else {
            HStack(alignment: .top, spacing: spacing) {
                content()
            }
        }
    }
}
