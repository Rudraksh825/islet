import Foundation
import IOKit
import IOKit.ps
import Combine
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "Battery")

final class BatteryMonitor: ObservableObject {
    @Published var level: Double = 1.0
    @Published var isCharging: Bool = false
    @Published var health: Double = 1.0
    @Published var watts: Double = 0
    @Published var peripherals: [(name: String, battery: Int)] = []

    private var timer: AnyCancellable?
    private let batteryQueue = DispatchQueue(label: "com.islet.battery", qos: .utility)

    func start() {
        poll()
        timer = Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.poll() }
    }

    func stop() {
        timer?.cancel()
    }

    private func poll() {
        batteryQueue.async { [weak self] in
            self?.readBattery()
            self?.readBluetoothPeripherals()
        }
    }

    private func readBattery() {
        guard let props = IOKitHelper.readBatteryProperties() else {
            os_log(.debug, log: log, "Could not read battery properties")
            return
        }

        let current  = props["CurrentCapacity"] as? Double ?? 0
        let maxCap   = props["MaxCapacity"] as? Double ?? 100
        let design   = props["DesignCapacity"] as? Double ?? 100
        let charging = props["IsCharging"] as? Bool ?? false
        let amperage = props["InstantAmperage"] as? Double ?? 0
        let voltage  = props["Voltage"] as? Double ?? 0

        let lvl     = maxCap > 0 ? current / maxCap : 0
        let hlth    = design > 0 ? maxCap / design : 1.0
        let w       = abs(amperage) * voltage / 1000.0 // milliamps * millivolts → watts

        DispatchQueue.main.async {
            self.level = lvl
            self.isCharging = charging
            self.health = min(hlth, 1.0)
            self.watts = w
        }
    }

    private func readBluetoothPeripherals() {
        // STUB: IOBluetooth peripheral battery requires linking IOBluetooth framework.
        // Using IOKit HID approach for battery level.
        // Real implementation would use IOBluetoothDevice.pairedDevices()
        // For now, leave as empty — gracefully disabled.
        // STUB: requires IOBluetooth framework linkage
    }
}
