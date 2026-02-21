import Foundation
import Combine

// UserDefaults-backed settings model. All properties are persisted automatically.
final class SystemConfig: ObservableObject {
    static let shared = SystemConfig()

    private let defaults = UserDefaults.standard

    @Published var clipboardStackSize: Int {
        didSet { defaults.set(clipboardStackSize, forKey: Keys.clipboardStackSize) }
    }
    @Published var fileRecoveryWindowSeconds: Int {
        didSet { defaults.set(fileRecoveryWindowSeconds, forKey: Keys.fileRecoveryWindowSeconds) }
    }
    @Published var weatherRefreshMinutes: Int {
        didSet { defaults.set(weatherRefreshMinutes, forKey: Keys.weatherRefreshMinutes) }
    }
    @Published var buildLogFilePath: String {
        didSet { defaults.set(buildLogFilePath, forKey: Keys.buildLogFilePath) }
    }
    @Published var islandPositionOffsetX: Double {
        didSet { defaults.set(islandPositionOffsetX, forKey: Keys.islandPositionOffsetX) }
    }
    @Published var islandPositionOffsetY: Double {
        didSet { defaults.set(islandPositionOffsetY, forKey: Keys.islandPositionOffsetY) }
    }
    @Published var colorSamplerShortcutEnabled: Bool {
        didSet { defaults.set(colorSamplerShortcutEnabled, forKey: Keys.colorSamplerShortcutEnabled) }
    }
    @Published var panelAboveFullScreen: Bool {
        didSet { defaults.set(panelAboveFullScreen, forKey: Keys.panelAboveFullScreen) }
    }

    // Which modules are enabled
    @Published var enabledModules: Set<String> {
        didSet {
            defaults.set(Array(enabledModules), forKey: Keys.enabledModules)
        }
    }

    // Environment variable configurations: [configName: [key: value]]
    @Published var envConfigs: [String: [String: String]] {
        didSet {
            if let data = try? JSONEncoder().encode(envConfigs) {
                defaults.set(data, forKey: Keys.envConfigs)
            }
        }
    }
    @Published var activeEnvConfig: String {
        didSet { defaults.set(activeEnvConfig, forKey: Keys.activeEnvConfig) }
    }

    private enum Keys {
        static let clipboardStackSize = "clipboardStackSize"
        static let fileRecoveryWindowSeconds = "fileRecoveryWindowSeconds"
        static let weatherRefreshMinutes = "weatherRefreshMinutes"
        static let buildLogFilePath = "buildLogFilePath"
        static let islandPositionOffsetX = "islandPositionOffsetX"
        static let islandPositionOffsetY = "islandPositionOffsetY"
        static let colorSamplerShortcutEnabled = "colorSamplerShortcutEnabled"
        static let panelAboveFullScreen = "panelAboveFullScreen"
        static let enabledModules = "enabledModules"
        static let envConfigs = "envConfigs"
        static let activeEnvConfig = "activeEnvConfig"
    }

    private init() {
        clipboardStackSize = defaults.integer(forKey: Keys.clipboardStackSize).nonZero(default: 10)
        fileRecoveryWindowSeconds = defaults.integer(forKey: Keys.fileRecoveryWindowSeconds).nonZero(default: 30)
        weatherRefreshMinutes = defaults.integer(forKey: Keys.weatherRefreshMinutes).nonZero(default: 15)
        buildLogFilePath = defaults.string(forKey: Keys.buildLogFilePath) ?? ""
        islandPositionOffsetX = defaults.double(forKey: Keys.islandPositionOffsetX)
        islandPositionOffsetY = defaults.double(forKey: Keys.islandPositionOffsetY)
        colorSamplerShortcutEnabled = defaults.bool(forKey: Keys.colorSamplerShortcutEnabled)
        panelAboveFullScreen = defaults.bool(forKey: Keys.panelAboveFullScreen)
        let rawModules = defaults.stringArray(forKey: Keys.enabledModules)
        enabledModules = rawModules.map { Set($0) } ?? Set(SystemConfig.allModuleIDs)
        if let data = defaults.data(forKey: Keys.envConfigs),
           let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
            envConfigs = decoded
        } else {
            envConfigs = [:]
        }
        activeEnvConfig = defaults.string(forKey: Keys.activeEnvConfig) ?? ""
    }

    static let allModuleIDs = [
        "nowPlaying", "volume", "weather", "notification", "systemStats",
        "ane", "network", "battery", "clipboard", "fileRecovery",
        "colorSampler", "appSwitcher", "avConference", "fft",
        "airDrop", "buildStatus", "stdout", "envToggle"
    ]

    func isEnabled(_ moduleID: String) -> Bool {
        enabledModules.contains(moduleID)
    }
}

private extension Int {
    func nonZero(default value: Int) -> Int {
        self == 0 ? value : self
    }
}
