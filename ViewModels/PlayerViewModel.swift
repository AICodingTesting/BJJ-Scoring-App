import Foundation
import AVFoundation
import Combine

final class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published var isPlaying: Bool = false
    @Published var isReady: Bool = false

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    deinit {
        removeObservers()
    }

    func load(url: URL) {
        removeObservers()
        isReady = false
        isPlaying = false
        currentTime = 0

        let asset = AVURLAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            guard let self else { return }
            var error: NSError?
            let status = asset.statusOfValue(forKey: "duration", error: &error)
            DispatchQueue.main.async {
                switch status {
                case .loaded:
                    let durationSeconds = CMTimeGetSeconds(asset.duration)
                    self.duration = durationSeconds.isFinite ? durationSeconds : 0
                    self.currentTime = 0
                    self.isPlaying = false
                    let item = AVPlayerItem(asset: asset)
                    self.configurePlayer(with: item)
                    self.isReady = true
                case .failed, .cancelled:
                    self.player = nil
                    self.duration = 0
                    self.isReady = false
                default:
                    break
                }
            }
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
                self.currentTime = seconds
            }
        }

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
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
