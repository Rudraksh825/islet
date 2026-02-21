import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject private var config = SystemConfig.shared
    @State private var newEnvName = ""
    @State private var selectedEnvConfig: String? = nil

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            modulesTab
                .tabItem { Label("Modules", systemImage: "square.grid.2x2") }

            envTab
                .tabItem { Label("Environments", systemImage: "gearshape.2") }
        }
        .frame(width: 480, height: 360)
        .padding()
    }

    // MARK: - General Tab
    private var generalTab: some View {
        Form {
            Section("Island") {
                HStack {
                    Text("Position offset X")
                    Slider(value: $config.islandPositionOffsetX, in: -100...100, step: 1)
                    Text("\(Int(config.islandPositionOffsetX))pt")
                }
                HStack {
                    Text("Position offset Y")
                    Slider(value: $config.islandPositionOffsetY, in: -50...50, step: 1)
                    Text("\(Int(config.islandPositionOffsetY))pt")
                }
                Toggle("Show above full-screen apps", isOn: $config.panelAboveFullScreen)
            }

            Section("Clipboard") {
                HStack {
                    Text("Stack size")
                    Slider(value: Binding(
                        get: { Double(config.clipboardStackSize) },
                        set: { config.clipboardStackSize = Int($0) }
                    ), in: 5...50, step: 1)
                    Text("\(config.clipboardStackSize) items")
                }
            }

            Section("File Recovery") {
                HStack {
                    Text("Recovery window")
                    Slider(value: Binding(
                        get: { Double(config.fileRecoveryWindowSeconds) },
                        set: { config.fileRecoveryWindowSeconds = Int($0) }
                    ), in: 5...120, step: 5)
                    Text("\(config.fileRecoveryWindowSeconds)s")
                }
            }

            Section("Weather") {
                HStack {
                    Text("Refresh interval")
                    Slider(value: Binding(
                        get: { Double(config.weatherRefreshMinutes) },
                        set: { config.weatherRefreshMinutes = Int($0) }
                    ), in: 5...60, step: 5)
                    Text("\(config.weatherRefreshMinutes) min")
                }
            }

            Section("Build Output") {
                HStack {
                    Text("Log file path")
                    TextField("Optional path to tail", text: $config.buildLogFilePath)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    // MARK: - Modules Tab
    private var modulesTab: some View {
        Form {
            ForEach(SystemConfig.allModuleIDs, id: \.self) { id in
                Toggle(id.capitalized, isOn: Binding(
                    get: { config.enabledModules.contains(id) },
                    set: { enabled in
                        if enabled {
                            config.enabledModules.insert(id)
                        } else {
                            config.enabledModules.remove(id)
                        }
                    }
                ))
            }
        }
    }

    // MARK: - Env Tab
    private var envTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environment Configurations")
                .font(.headline)

            List(Array(config.envConfigs.keys).sorted(), id: \.self, selection: $selectedEnvConfig) { name in
                HStack {
                    Text(name)
                    Spacer()
                    if name == config.activeEnvConfig {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    }
                }
            }

            HStack {
                TextField("Config name", text: $newEnvName)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    guard !newEnvName.isEmpty else { return }
                    config.envConfigs[newEnvName] = [:]
                    newEnvName = ""
                }
                if let selected = selectedEnvConfig {
                    Button("Remove") {
                        config.envConfigs.removeValue(forKey: selected)
                        selectedEnvConfig = nil
                    }
                    .foregroundColor(.red)
                    Button("Activate") {
                        viewModel.envConfigMonitor.activate(configName: selected)
                    }
                }
            }
        }
        .padding()
    }
}
