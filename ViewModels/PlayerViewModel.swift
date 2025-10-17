import Foundation
@preconcurrency import AVFoundation
import Combine

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published var isPlaying: Bool = false
    @Published var isReady: Bool = false

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    deinit {
        Task { @MainActor in
            self.removeObservers()
        }
    }

    func load(url: URL) async {
        await MainActor.run {
            self.removeObservers()
        }
        isReady = false
        isPlaying = false
        currentTime = 0

        let asset = AVURLAsset(url: url)

        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            self.duration = durationSeconds.isFinite ? durationSeconds : 0
            self.currentTime = 0
            self.isPlaying = false

            let item = AVPlayerItem(asset: asset)
            configurePlayer(with: item)
            isReady = true
        } catch {
            player = nil
            duration = 0
            isReady = false
        }
    }

    private func configurePlayer(with item: AVPlayerItem) {
        let targetPlayer: AVPlayer
        if let existing = player {
            existing.pause()
            existing.replaceCurrentItem(with: item)
            targetPlayer = existing
        } else {
            targetPlayer = AVPlayer(playerItem: item)
        }
        targetPlayer.actionAtItemEnd = .pause
        targetPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        player = targetPlayer
        addObservers()
    }

    private func addObservers() {
        guard let player else { return }
        removeObservers()
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite {
                Task { @MainActor in
                    self.currentTime = seconds
                }
            }
        }

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .receive(on: RunLoop.main)
            .compactMap { $0.object as? AVPlayerItem }
            .filter { [weak player] item in
                guard let player else { return false }
                return item === player.currentItem
            }
            .sink { [weak self] _ in
                guard let self, let player = self.player else { return }
                player.pause()
                self.isPlaying = false
                self.currentTime = 0
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func removeObservers() {
        if let player = player, let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        cancellables.removeAll()
    }

    func playPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    func play() {
        guard let player else { return }
        player.play()
        isPlaying = true
    }

    func pause() {
        guard let player else { return }
        player.pause()
        isPlaying = false
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func rewind(by seconds: Double = 5) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }
}
