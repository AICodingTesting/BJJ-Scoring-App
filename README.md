# BJJ Score Tracker

BJJ Score Tracker is an iOS app that helps practitioners analyze training footage, log scoring exchanges, capture notes, and export videos with an overlay scoreboard.

## Features

- **Video import** – Pick a clip from the Photos library to review matches frame by frame.
- **Interactive scoring controls** – Tap buttons for points, advantages, or penalties for either athlete. Undo and redo provide non-destructive editing.
- **Timeline scrubbing** – Seek through the match, review the real-time scoreboard, and drop events precisely where they happened.
- **Notes and metadata** – Capture quick notes, match context, and competitor names while you review.
- **Export with overlay** – Configure export settings and render a video that includes the live scoreboard and metadata banner.

## Getting Started

1. Open `BJJScoreTracker.xcodeproj` in Xcode 15 or later.
2. Select the **BJJScoreTracker** scheme and choose an iPhone or iPad simulator target.
3. Build and run (`⌘R`).

## Usage

1. Tap **Select Video** in the toolbar to import a match from Photos. The timeline, scoreboard, and controls become active after the clip loads.
2. Scrub the timeline or play the clip. The scoring panel stays pinned at the bottom so you can log events for either athlete while the video continues playing and the scoreboard updates instantly.
3. Open the **Event History** list to edit or delete logged events, or use the **Notes** card to jot down observations tied to the current timestamp.
4. Adjust metadata (match title, competitors, gym, date) as needed. These details appear in the overlay when exporting.
5. Choose **Export Video** to review export settings (resolution, aspect ratio, watermark options) and render the annotated clip.

## Project Structure

- `Models/`: Codable value types for projects, events, metadata, export preferences, and score reducers.
- `ViewModels/`: Observable objects for managing player state, timelines, export workflow, and persisted projects.
- `Views/`: SwiftUI interfaces including the new `MatchEditorView`, scoring controls, event history, metadata, notes, and export settings screens.
- `Export/`: Helpers that build AVFoundation compositions and render overlay layers for exports.
- `Utilities/`: Shared helpers (bookmark management, haptics, layout math, time formatting).
- `Persistence/`: iOS bookmark resolver implementation.

## Requirements

- iOS 17+ target
- Xcode 15+
- Photos library access to import videos

## License

This project is provided as-is for personal use and experimentation.
