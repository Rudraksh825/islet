import SwiftUI

struct EnvToggleView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 16))
                .foregroundColor(badgeColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Environment")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.5))
                Text(viewModel.activeEnvName.isEmpty ? "None" : viewModel.activeEnvName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(badgeColor)
            }

            Spacer()

            // Cycle button
            Button("Change") {
                cycleEnvironment()
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .cornerRadius(6)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var badgeColor: Color {
        let name = viewModel.activeEnvName.lowercased()
        if name.contains("prod") { return .red }
        if name.contains("staging") || name.contains("stage") { return .yellow }
        return .green
    }

    private func cycleEnvironment() {
        let configs = Array(SystemConfig.shared.envConfigs.keys).sorted()
        guard !configs.isEmpty else { return }
        if let idx = configs.firstIndex(of: viewModel.activeEnvName) {
            let next = configs[(idx + 1) % configs.count]
            viewModel.envConfigMonitor.activate(configName: next)
        } else {
            viewModel.envConfigMonitor.activate(configName: configs[0])
        }
    }
}
