import SwiftUI

@MainActor
struct MatchEditorView: View {
    @EnvironmentObject private var projectStore: ProjectStore
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @EnvironmentObject private var timelineViewModel: TimelineViewModel
    @EnvironmentObject private var exportViewModel: ExportViewModel

    var isSelectionInProgress: Bool
    var onRequestExport: @Sendable () -> Void

    @State private var scrubbingPosition: Double = 0
    @State private var isScrubbing = false
    @State private var editingEvent: ScoreEvent?
    @State private var showingExportSheet = false
    @State private var loadError: String?
    @State private var isLoadingVideo = false
    @State private var configuredProjectID: UUID?
    @State private var configuredBookmark: Data?
    @State private var loadedBookmark: Data?

    private var project: Project { projectStore.currentProject }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                videoSection
                timelineSection
                adaptiveInfoStack
                EventHistoryView(events: timelineViewModel.events, onEdit: beginEditing(_:), onDelete: deleteEvent(_:))
                    .disabled(!playerViewModel.isReady)
                exportButton
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            controlsInset
        }
        .onAppear {
            Task { @MainActor in
                prepareView()
            }
        }
        .onChange(of: project.id) { _ in
            Task { @MainActor in
                prepareView(forceReconfigure: true)
            }
        }
        .onChange(of: project.videoBookmark) { _ in
            Task { @MainActor in
                prepareView(forceReconfigure: true)
            }
        }
        .onChange(of: playerViewModel.currentTime) { newValue in
            guard !isScrubbing else { return }
            scrubbingPosition = newValue
            timelineViewModel.updateCurrentScore(for: newValue)
        }
        .onChange(of: playerViewModel.duration) { duration in
            updateProject { project in
                project.duration = duration
            }
        }
        .sheet(item: $editingEvent) { event in
            NavigationStack {
                EventEditView(event: event, duration: max(playerViewModel.duration, 0), onSave: { updated in
                    timelineViewModel.updateEvent(updated)
                    persistEvents()
                    editingEvent = nil
                }, onCancel: { editingEvent = nil })
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            NavigationStack {
                ExportSettingsView(
                    preferences: exportPreferencesBinding,
                    onExport: {
                        onRequestExport()
                        showingExportSheet = false
                    },
                    isExporting: exportViewModel.isExporting,
                    progress: exportViewModel.exportProgress
                )
                .navigationTitle("Export")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showingExportSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Video Load Error", isPresented: Binding(
            get: { loadError != nil },
            set: { newValue in
                if !newValue { loadError = nil }
            }
        ), actions: {
            Button("OK", role: .cancel) { loadError = nil }
        }, message: {
            Text(loadError ?? "An unknown error occurred while loading the video.")
        })
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateProjectVideo)) { _ in
            Task { @MainActor in
                prepareView(forceReconfigure: true)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Project Title", text: Binding(
                get: { project.title },
                set: { value in
                    updateProject { $0.title = value }
                }
            ))
            .font(.title.bold())
            .textFieldStyle(.roundedBorder)
            .disabled(isSelectionInProgress)

            if let name = project.videoFilename {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var videoSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let player = playerViewModel.player, playerViewModel.isReady {
                    VideoPlayerView(player: player)
                        .ignoresSafeArea()
                        .background(Color.black)
                        .overlay(alignment: .topLeading) {
                            ScoreOverlayView(
                                score: timelineViewModel.currentScore,
                                metadata: project.metadata,
                                currentTime: scrubbingPosition
                            )
                            .padding()
                            .background(Color.clear)
                        }
                        .mask(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                } else if isLoadingVideo {
                    ProgressView("Preparing video...")
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.black.opacity(0.2))
                        )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Select a video to begin scoring")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.black.opacity(0.1))
                    )
                }
            }

            if playerViewModel.isReady {
                playbackControls
                    .padding(20)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .animation(.easeInOut, value: playerViewModel.isReady)
    }

    private var playbackControls: some View {
        HStack(spacing: 24) {
            Button(action: { playerViewModel.rewind(by: 5) }) {
                Image(systemName: "gobackward.5")
                    .font(.title2.weight(.semibold))
            }
            Button(action: playerViewModel.playPause) {
                Image(systemName: playerViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.35), in: Capsule())
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Slider(
                value: Binding(
                    get: { scrubbingPosition },
                    set: { newValue in
                        scrubbingPosition = newValue
                    }
                ),
                in: 0...max(playerViewModel.duration, 1),
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if !editing {
                        playerViewModel.seek(to: scrubbingPosition)
                        timelineViewModel.updateCurrentScore(for: scrubbingPosition)
                    }
                }
            )
            .disabled(!playerViewModel.isReady)

            HStack {
                Text(TimeFormatter.string(from: scrubbingPosition))
                    .font(.caption.monospacedDigit())
                Spacer()
                Text(TimeFormatter.string(from: playerViewModel.duration))
                    .font(.caption.monospacedDigit())
            }
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var adaptiveInfoStack: some View {
        AdaptiveStack {
            MetadataView(metadata: metadataBinding)
                .frame(maxWidth: .infinity)
            NotesView(notes: timelineViewModel.notes, onAdd: addNote(_:), onDelete: removeNote(_:))
                .frame(maxWidth: .infinity)
        }
    }

    private var controlsInset: some View {
        VStack(spacing: 12) {
            if !playerViewModel.isReady {
                Text("Select a video to enable scoring controls.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            ControlsView(
                showsCardBackground: false,
                onScore: handleScore(_:action:),
                onUndo: handleUndo,
                onRedo: handleRedo
            )
            .disabled(!playerViewModel.isReady || isSelectionInProgress || exportViewModel.isExporting)
            .opacity(playerViewModel.isReady ? 1 : 0.35)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.15))
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Divider()
                .blendMode(.overlay)
                .opacity(0.6)
        }
    }

    private var exportButton: some View {
        Button(action: { showingExportSheet = true }) {
            Label("Export Video", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!playerViewModel.isReady || exportViewModel.isExporting || isSelectionInProgress)
    }

    private func handleScore(_ competitor: Competitor, action: ScoreEventAction) {
        guard playerViewModel.isReady else { return }
        let timestamp = scrubbingPosition
        let event = ScoreEvent(timestamp: timestamp, competitor: competitor, action: action)
        timelineViewModel.addEvent(event)
        timelineViewModel.updateCurrentScore(for: timestamp)
        persistEvents()
    }

    private func handleUndo() {
        timelineViewModel.undo()
        persistEvents()
    }

    private func handleRedo() {
        timelineViewModel.redo()
        persistEvents()
    }

    private func beginEditing(_ event: ScoreEvent) {
        editingEvent = event
    }

    private func deleteEvent(_ event: ScoreEvent) {
        timelineViewModel.removeEvent(event)
        persistEvents()
    }

    private func addNote(_ text: String) {
        let note = MatchNote(timestamp: scrubbingPosition, text: text)
        timelineViewModel.addNote(note)
        persistNotes()
    }

    private func removeNote(_ note: MatchNote) {
        timelineViewModel.removeNote(note)
        persistNotes()
    }

    private func updateProject(_ mutation: (inout Project) -> Void) {
        var updated = project
        mutation(&updated)
        updated.updatedAt = Date()
        projectStore.update(updated)
    }

    private func persistEvents() {
        updateProject { project in
            project.events = timelineViewModel.events
        }
    }

    private func persistNotes() {
        updateProject { project in
            project.notes = timelineViewModel.notes
        }
    }

    private func prepareView(forceReconfigure: Bool = false) {
        let currentProject = project
        if forceReconfigure || configuredProjectID != currentProject.id {
            configureTimeline(for: currentProject)
            configuredProjectID = currentProject.id
            configuredBookmark = currentProject.videoBookmark
        } else if configuredBookmark != currentProject.videoBookmark {
            configureTimeline(for: currentProject)
            configuredBookmark = currentProject.videoBookmark
        }
        loadVideoIfNeeded(from: currentProject.videoBookmark)
    }

    private func configureTimeline(for project: Project) {
        timelineViewModel.configure(events: project.events, notes: project.notes)
        scrubbingPosition = 0
        timelineViewModel.updateCurrentScore(for: 0)
    }

    private func loadVideoIfNeeded(from bookmark: Data?) {
        guard let bookmark else {
            loadedBookmark = nil
            playerViewModel.pause()
            playerViewModel.isReady = false
            playerViewModel.currentTime = 0
            playerViewModel.duration = 0
            playerViewModel.player = nil
            return
        }
        guard loadedBookmark != bookmark else { return }
        loadedBookmark = bookmark
        isLoadingVideo = true
        loadError = nil

        Task { @MainActor in
            do {
                let resolved = try await BookmarkResolver.resolveBookmark(from: bookmark)
                if resolved.isStale, let refreshed = BookmarkResolver.bookmark(for: resolved.url) {
                    updateProject { project in
                        project.videoBookmark = refreshed
                    }
                }
                await playerViewModel.load(url: resolved.url)
                isLoadingVideo = false
            } catch {
                isLoadingVideo = false
                loadError = error.localizedDescription
            }
        }
    }

    private var metadataBinding: Binding<MatchMetadata> {
        Binding(
            get: { project.metadata },
            set: { metadata in
                updateProject { $0.metadata = metadata }
            }
        )
    }

    private var exportPreferencesBinding: Binding<ExportPreferences> {
        Binding(
            get: { project.exportPreferences },
            set: { preferences in
                updateProject { $0.exportPreferences = preferences }
            }
        )
    }
}

private struct AdaptiveStack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > 700 {
                HStack(alignment: .top, spacing: 16) {
                    content
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
            }
        }
        .frame(minHeight: 0)
    }
}

extension Notification.Name {
    static let didUpdateProjectVideo = Notification.Name("didUpdateProjectVideo")
}
