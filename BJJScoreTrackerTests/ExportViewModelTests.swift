import XCTest
import Dispatch
@preconcurrency import AVFoundation
@testable import BJJScoreTracker

final class MockExportSession: VideoExportSession {
    var status: AVAssetExportSession.Status = .unknown
    var progress: Float = 0
    var outputURL: URL?
    var outputFileType: AVFileType?
    var error: Error?
    var exportCompletion: (@Sendable () -> Void)?

    func exportAsynchronously(completionHandler handler: @escaping @Sendable () -> Void) {
        status = .exporting
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.01) { [weak self] in
            guard let self = self else { return }
            self.status = .completed
            self.progress = 1.0
            handler()
            self.exportCompletion?()
        }
    }

    func cancelExport() {
        status = .cancelled
    }
}

@MainActor
final class ExportViewModelTests: XCTestCase {
    func testExportCompletesAndRefreshesBookmarkWhenStale() async {
        let exportFinished = expectation(description: "Export finished")
        let bookmarkRefreshed = expectation(description: "Bookmark refreshed")

        let resolvedURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("video.mov")
        let refreshedBookmarkData = Data("refreshed".utf8)

        let mockSession = MockExportSession()
        mockSession.exportCompletion = {
            exportFinished.fulfill()
        }

        let viewModel = ExportViewModel(
            resolveBookmark: { _ in
                BookmarkResolver.ResolvedBookmark(url: resolvedURL, isStale: true)
            },
            bookmarkCreator: { _ in refreshedBookmarkData },
            exportSessionFactory: { _ in mockSession }
        )

        let project = Project(videoBookmark: Data([0x01]), videoFilename: "video.mov")

        var refreshedProject: Project?
        var refreshedData: Data?

        await viewModel.startExport(from: project) { project, data in
            refreshedProject = project
            refreshedData = data
            bookmarkRefreshed.fulfill()
        }

        await fulfillment(of: [exportFinished, bookmarkRefreshed], timeout: 1.0)

        // Allow the main actor task scheduled in the export completion handler to finish updating state.
        for _ in 0..<10 where !viewModel.exportCompleted {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertTrue(viewModel.exportCompleted)
        XCTAssertNil(viewModel.exportError)
        XCTAssertEqual(refreshedProject?.id, project.id)
        XCTAssertEqual(refreshedData, refreshedBookmarkData)
    }
}
