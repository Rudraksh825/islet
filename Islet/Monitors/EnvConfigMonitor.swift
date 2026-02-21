import Foundation
import Combine
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "EnvConfig")

final class EnvConfigMonitor: ObservableObject {
    @Published var activeConfigName: String = ""

    private let config = SystemConfig.shared
    private var cancellables = Set<AnyCancellable>()

    func start() {
        activeConfigName = config.activeEnvConfig
        config.$activeEnvConfig
            .receive(on: DispatchQueue.main)
            .assign(to: &$activeConfigName)
    }

    func stop() {
        cancellables.removeAll()
    }

    func activate(configName: String) {
        guard let vars = config.envConfigs[configName] else { return }
        applyEnvironment(vars)
        config.activeEnvConfig = configName
        activeConfigName = configName
    }

    private func applyEnvironment(_ vars: [String: String]) {
        // Apply via launchctl setenv for current login session
        for (key, value) in vars {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["setenv", key, value]
            try? process.run()
            process.waitUntilExit()
        }
        os_log(.debug, log: log, "Applied environment config with %d vars", vars.count)
    }

    var colorForActiveConfig: String {
        let name = activeConfigName.lowercased()
        if name.contains("prod") { return "red" }
        if name.contains("staging") || name.contains("stage") { return "yellow" }
        return "green"
    }
}
