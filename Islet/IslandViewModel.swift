import Foundation
import Combine
import AppKit
import SwiftUI

final class IslandViewModel: ObservableObject {

    // MARK: - Published state consumed by views
    @Published var currentMode: IslandMode = .collapsed
    @Published var isHovered: Bool = false

    // Per-monitor published data
    @Published var nowPlayingTrack: String = ""
    @Published var nowPlayingArtist: String = ""
    @Published var nowPlayingArt: NSImage? = nil
    @Published var nowPlayingIsPlaying: Bool = false
    @Published var nowPlayingElapsedFraction: Double = 0

    @Published var volumeLevel: Double = 0.5
    @Published var volumeIsMuted: Bool = false

    @Published var weatherTemp: Double = 0
    @Published var weatherCondition: String = ""
    @Published var weatherSymbol: String = "cloud"
    @Published var weatherPrecipProb: Int = 0

    @Published var cpuUsage: Double = 0
    @Published var gpuUsage: Double = 0
    @Published var cpuTemp: Double = 0
    @Published var gpuTemp: Double = 0
    @Published var fanRPM: [Double] = []
    @Published var thermalState: ProcessInfo.ThermalState = .nominal

    @Published var aneActive: Bool = false

    @Published var networkUpBPS: Double = 0
    @Published var networkDownBPS: Double = 0
    @Published var networkTopProcesses: [(name: String, bytesPerSec: Double)] = []

    @Published var batteryLevel: Double = 1.0
    @Published var batteryIsCharging: Bool = false
    @Published var batteryHealth: Double = 1.0
    @Published var batteryWatts: Double = 0
    @Published var bluetoothPeripherals: [(name: String, battery: Int)] = []

    @Published var clipboardItems: [ClipboardItem] = []
    @Published var clipboardCount: Int = 0

    @Published var cameraActive: Bool = false
    @Published var micActive: Bool = false
    @Published var avAppName: String = ""

    @Published var fftBins: [Double] = Array(repeating: 0, count: 32)

    @Published var buildIsRunning: Bool = false
    @Published var buildErrorCount: Int = 0
    @Published var buildWarningCount: Int = 0
    @Published var buildLastLines: [String] = []
    @Published var buildSuccess: Bool? = nil

    @Published var stdoutLines: [String] = []

    @Published var activeEnvName: String = ""

    @Published var companionApps: [(bundleID: String, icon: NSImage?)] = []

    // MARK: - Mode queue
    private var activeQueue: [IslandMode] = []
    private var dismissTimers: [String: AnyCancellable] = [:]
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Monitors (owned here)
    let nowPlayingMonitor = NowPlayingMonitor()
    let volumeMonitor = VolumeMonitor()
    let weatherMonitor = WeatherMonitor()
    let notificationMonitor = NotificationMonitor()
    let systemStatsMonitor = SystemStatsMonitor()
    let aneMonitor = ANEMonitor()
    let networkMonitor = NetworkMonitor()
    let batteryMonitor = BatteryMonitor()
    let clipboardMonitor = ClipboardMonitor()
    let trashMonitor = TrashMonitor()
    let appUsageMonitor = AppUsageMonitor()
    let avSessionMonitor = AVSessionMonitor()
    let fftMonitor = FFTMonitor()
    let airDropMonitor = AirDropMonitor()
    let buildMonitor = BuildMonitor()
    let envConfigMonitor = EnvConfigMonitor()

    init() {
        startMonitors()
        bindMonitors()
    }

    // MARK: - Lifecycle
    private func startMonitors() {
        nowPlayingMonitor.start()
        volumeMonitor.start()
        weatherMonitor.start()
        notificationMonitor.start()
        systemStatsMonitor.start()
        aneMonitor.start()
        networkMonitor.start()
        batteryMonitor.start()
        clipboardMonitor.start()
        trashMonitor.start()
        appUsageMonitor.start()
        avSessionMonitor.start()
        fftMonitor.start()
        airDropMonitor.start()
        buildMonitor.start()
        envConfigMonitor.start()
    }

    // MARK: - Monitor → ViewModel bindings
    private func bindMonitors() {
        // NowPlaying
        nowPlayingMonitor.$trackTitle.receive(on: DispatchQueue.main).sink { [weak self] v in
            self?.nowPlayingTrack = v
            if !v.isEmpty { self?.activateMode(.nowPlaying) }
        }.store(in: &cancellables)
        nowPlayingMonitor.$artistName.receive(on: DispatchQueue.main).assign(to: &$nowPlayingArtist)
        nowPlayingMonitor.$albumArt.receive(on: DispatchQueue.main).assign(to: &$nowPlayingArt)
        nowPlayingMonitor.$isPlaying.receive(on: DispatchQueue.main).assign(to: &$nowPlayingIsPlaying)
        nowPlayingMonitor.$elapsedFraction.receive(on: DispatchQueue.main).assign(to: &$nowPlayingElapsedFraction)

        // Volume
        volumeMonitor.$volume.receive(on: DispatchQueue.main).sink { [weak self] v in
            self?.volumeLevel = v
            self?.activateMode(.volume(level: v, isMuted: self?.volumeIsMuted ?? false))
        }.store(in: &cancellables)
        volumeMonitor.$isMuted.receive(on: DispatchQueue.main).sink { [weak self] v in
            self?.volumeIsMuted = v
            self?.activateMode(.volume(level: self?.volumeLevel ?? 0.5, isMuted: v))
        }.store(in: &cancellables)

        // Weather
        weatherMonitor.$temperature.receive(on: DispatchQueue.main).assign(to: &$weatherTemp)
        weatherMonitor.$condition.receive(on: DispatchQueue.main).assign(to: &$weatherCondition)
        weatherMonitor.$sfSymbol.receive(on: DispatchQueue.main).assign(to: &$weatherSymbol)
        weatherMonitor.$precipitationProbability.receive(on: DispatchQueue.main).assign(to: &$weatherPrecipProb)
        weatherMonitor.$shouldShow.receive(on: DispatchQueue.main).sink { [weak self] show in
            if show { self?.activateMode(.weather) }
        }.store(in: &cancellables)

        // Notifications
        notificationMonitor.$pendingNotification.receive(on: DispatchQueue.main).sink { [weak self] n in
            guard let n = n else { return }
            self?.activateMode(.notification(title: n.title, body: n.body, appName: n.appName, appIcon: n.appIcon))
        }.store(in: &cancellables)

        // SystemStats
        systemStatsMonitor.$cpuUsage.receive(on: DispatchQueue.main).assign(to: &$cpuUsage)
        systemStatsMonitor.$gpuUsage.receive(on: DispatchQueue.main).assign(to: &$gpuUsage)
        systemStatsMonitor.$cpuTemp.receive(on: DispatchQueue.main).assign(to: &$cpuTemp)
        systemStatsMonitor.$gpuTemp.receive(on: DispatchQueue.main).assign(to: &$gpuTemp)
        systemStatsMonitor.$fanRPM.receive(on: DispatchQueue.main).assign(to: &$fanRPM)
        systemStatsMonitor.$thermalState.receive(on: DispatchQueue.main).assign(to: &$thermalState)
        systemStatsMonitor.$cpuUsage.receive(on: DispatchQueue.main).sink { [weak self] v in
            if v > 0.6 { self?.activateMode(.systemStats) }
        }.store(in: &cancellables)

        // ANE
        aneMonitor.$isActive.receive(on: DispatchQueue.main).assign(to: &$aneActive)

        // Network
        networkMonitor.$uploadBytesPerSec.receive(on: DispatchQueue.main).assign(to: &$networkUpBPS)
        networkMonitor.$downloadBytesPerSec.receive(on: DispatchQueue.main).assign(to: &$networkDownBPS)
        networkMonitor.$topProcesses.receive(on: DispatchQueue.main).sink { [weak self] procs in
            self?.networkTopProcesses = procs
            let total = procs.map(\.bytesPerSec).reduce(0, +)
            if total > 500_000 { self?.activateMode(.network) }
        }.store(in: &cancellables)

        // Battery
        batteryMonitor.$level.receive(on: DispatchQueue.main).assign(to: &$batteryLevel)
        batteryMonitor.$isCharging.receive(on: DispatchQueue.main).assign(to: &$batteryIsCharging)
        batteryMonitor.$health.receive(on: DispatchQueue.main).assign(to: &$batteryHealth)
        batteryMonitor.$watts.receive(on: DispatchQueue.main).assign(to: &$batteryWatts)
        batteryMonitor.$peripherals.receive(on: DispatchQueue.main).assign(to: &$bluetoothPeripherals)

        // Clipboard
        clipboardMonitor.$items.receive(on: DispatchQueue.main).sink { [weak self] items in
            self?.clipboardItems = items
            self?.clipboardCount = items.count
            if !items.isEmpty { self?.activateMode(.clipboard) }
        }.store(in: &cancellables)

        // Trash
        trashMonitor.$pendingRecovery.receive(on: DispatchQueue.main).sink { [weak self] item in
            guard let item = item else { return }
            self?.activateMode(.fileRecovery(fileName: item.fileName, trashURL: item.trashURL, originalURL: item.originalURL))
        }.store(in: &cancellables)

        // AppUsage
        appUsageMonitor.$companions.receive(on: DispatchQueue.main).assign(to: &$companionApps)

        // AV Session
        avSessionMonitor.$cameraActive.receive(on: DispatchQueue.main).sink { [weak self] v in
            self?.cameraActive = v
            if v { self?.activateMode(.avConference) }
        }.store(in: &cancellables)
        avSessionMonitor.$micActive.receive(on: DispatchQueue.main).sink { [weak self] v in
            self?.micActive = v
            if v && !(self?.cameraActive ?? false) { self?.activateMode(.avConference) }
        }.store(in: &cancellables)
        avSessionMonitor.$appName.receive(on: DispatchQueue.main).assign(to: &$avAppName)

        // FFT
        fftMonitor.$bins.receive(on: DispatchQueue.main).assign(to: &$fftBins)

        // AirDrop
        airDropMonitor.$pendingFile.receive(on: DispatchQueue.main).sink { [weak self] fileName in
            guard let fileName = fileName else { return }
            self?.activateMode(.airDrop(fileName: fileName))
        }.store(in: &cancellables)

        // Build
        buildMonitor.$isRunning.receive(on: DispatchQueue.main).sink { [weak self] v in
            self?.buildIsRunning = v
            if v { self?.activateMode(.buildStatus) }
        }.store(in: &cancellables)
        buildMonitor.$errorCount.receive(on: DispatchQueue.main).assign(to: &$buildErrorCount)
        buildMonitor.$warningCount.receive(on: DispatchQueue.main).assign(to: &$buildWarningCount)
        buildMonitor.$lastLines.receive(on: DispatchQueue.main).assign(to: &$buildLastLines)
        buildMonitor.$success.receive(on: DispatchQueue.main).assign(to: &$buildSuccess)

        // Stdout
        buildMonitor.$stdoutLines.receive(on: DispatchQueue.main).sink { [weak self] lines in
            self?.stdoutLines = lines
            if !lines.isEmpty { self?.activateMode(.stdout) }
        }.store(in: &cancellables)

        // Env
        envConfigMonitor.$activeConfigName.receive(on: DispatchQueue.main).assign(to: &$activeEnvName)
    }

    // MARK: - Mode management
    func activateMode(_ mode: IslandMode) {
        // Remove existing entry of same type
        activeQueue.removeAll { $0 == mode }
        activeQueue.append(mode)
        activeQueue.sort { $0.priority > $1.priority }

        updateCurrentMode()

        // Schedule auto-dismiss
        if let interval = mode.autoDismissInterval {
            let key = "\(mode.priority)"
            dismissTimers[key]?.cancel()
            dismissTimers[key] = Just(())
                .delay(for: .seconds(interval), scheduler: DispatchQueue.main)
                .sink { [weak self] in self?.deactivateMode(mode) }
        }
    }

    func deactivateMode(_ mode: IslandMode) {
        activeQueue.removeAll { $0 == mode }
        dismissTimers["\(mode.priority)"]?.cancel()
        updateCurrentMode()
    }

    private func updateCurrentMode() {
        let newMode = activeQueue.first ?? .collapsed
        guard newMode != currentMode else { return }
        currentMode = newMode
    }

    // MARK: - Actions
    func dismissCurrent() {
        guard currentMode != .collapsed else { return }
        deactivateMode(currentMode)
    }

    func togglePlayPause() {
        nowPlayingMonitor.togglePlayPause()
    }

    func skipNext() {
        nowPlayingMonitor.skipNext()
    }

    func skipPrevious() {
        nowPlayingMonitor.skipPrevious()
    }

    func muteMic() {
        avSessionMonitor.toggleMicMute()
    }

    func restoreFile(trashURL: URL, originalURL: URL) {
        trashMonitor.restore(trashURL: trashURL, to: originalURL)
        deactivateMode(currentMode)
    }

    func selectClipboardItem(_ item: ClipboardItem) {
        clipboardMonitor.setActive(item)
    }
}
