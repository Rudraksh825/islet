import Foundation
import AppKit
import Combine
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "NowPlaying")

final class NowPlayingMonitor: ObservableObject {
    @Published var trackTitle: String = ""
    @Published var artistName: String = ""
    @Published var albumArt: NSImage? = nil
    @Published var isPlaying: Bool = false
    @Published var elapsedFraction: Double = 0

    private var progressTimer: AnyCancellable?
    private var pollTimer: AnyCancellable?
    private var elapsed: Double = 0
    private var duration: Double = 0

    private let bridge = MediaRemoteBridge.shared

    // Hardcoded raw notification names — these are stable across macOS versions
    // and more reliable than resolving them via dlsym
    private static let infoChangedName = Notification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification")
    private static let playbackChangedName = Notification.Name("kMRMediaRemoteNowPlayingPlaybackQueueDidChangeNotification")
    private static let applicationChangedName = Notification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification")

    func start() {
        guard bridge.isAvailable else {
            os_log(.debug, log: log, "MediaRemote not available — NowPlaying stubbed")
            return
        }

        bridge.registerForNotifications(on: .main)

        for name in [Self.infoChangedName, Self.playbackChangedName, Self.applicationChangedName] {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(nowPlayingChanged),
                name: name,
                object: nil
            )
        }

        // Poll every 5s as a fallback in case notifications are missed
        pollTimer = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.fetchNowPlaying() }

        fetchNowPlaying()
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        progressTimer?.cancel()
        pollTimer?.cancel()
    }

    @objc private func nowPlayingChanged() {
        fetchNowPlaying()
    }

    private func fetchNowPlaying() {
        bridge.fetchNowPlayingInfo(on: .main) { [weak self] info in
            guard let self = self else { return }

            // Use hardcoded string keys — MediaRemote keys are stable
            let title   = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            let artist  = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
            let dur     = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
            let rate    = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0

            self.trackTitle = title
            self.artistName = artist
            self.elapsed = elapsed
            self.duration = dur
            self.isPlaying = rate > 0

            if let artData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                self.albumArt = NSImage(data: artData)
            } else {
                self.albumArt = nil
            }

            if self.isPlaying && self.duration > 0 {
                self.startProgressTimer()
            } else {
                self.progressTimer?.cancel()
                self.elapsedFraction = self.duration > 0 ? self.elapsed / self.duration : 0
            }
        }
    }

    private func startProgressTimer() {
        progressTimer?.cancel()
        progressTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying else { return }
                self.elapsed += 1
                if self.duration > 0 {
                    self.elapsedFraction = min(self.elapsed / self.duration, 1.0)
                }
            }
    }

    func togglePlayPause() { bridge.send(command: .togglePlayPause) }
    func skipNext()         { bridge.send(command: .nextTrack) }
    func skipPrevious()     { bridge.send(command: .previousTrack) }
}
