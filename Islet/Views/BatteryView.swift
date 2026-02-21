import SwiftUI

struct BatteryView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: batterySymbol)
                    .font(.system(size: 20))
                    .foregroundColor(batteryColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(viewModel.batteryLevel * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(viewModel.batteryIsCharging ? "Charging" : String(format: "%.1fW", viewModel.batteryWatts))
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.6))
                }

                Spacer()

                Text("Health \(Int(viewModel.batteryHealth * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.5))
            }

            if !viewModel.bluetoothPeripherals.isEmpty {
                Divider().background(Color(white: 0.3))
                ForEach(viewModel.bluetoothPeripherals.prefix(3), id: \.name) { p in
                    HStack {
                        Text(p.name)
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.7))
                        Spacer()
                        Text("\(p.battery)%")
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.5))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var batterySymbol: String {
        if viewModel.batteryIsCharging { return "battery.100.bolt" }
        if viewModel.batteryLevel > 0.75 { return "battery.100" }
        if viewModel.batteryLevel > 0.5  { return "battery.75" }
        if viewModel.batteryLevel > 0.25 { return "battery.50" }
        return "battery.25"
    }

    private var batteryColor: Color {
        if viewModel.batteryIsCharging { return .green }
        if viewModel.batteryLevel > 0.2 { return .white }
        return .red
    }
}
