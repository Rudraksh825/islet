import Foundation
import IOKit
import Combine
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "ANE")

// STUB: ANE monitoring uses private IOReport API.
// This implementation does best-effort via IOKit property reading.
// Wrapped in optionals — gracefully disabled if unavailable.

final class ANEMonitor: ObservableObject {
    @Published var isActive: Bool = false
    @Published var power: Double = 0

    private var timer: AnyCancellable?
    private let aneQueue = DispatchQueue(label: "com.islet.ane", qos: .utility)

    func start() {
        timer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.poll() }
    }

    func stop() {
        timer?.cancel()
    }

    private func poll() {
        aneQueue.async { [weak self] in
            let power = self?.readANEPower() ?? 0
            DispatchQueue.main.async {
                self?.power = power
                self?.isActive = power > 50 // mW threshold
            }
        }
    }

    private func readANEPower() -> Double {
        // Try reading from AppleARMIODevice
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleARMIODevice"))
        guard service != IO_OBJECT_NULL else { return 0 }
        defer { IOObjectRelease(service) }

        guard let props = IOKitHelper.properties(of: service),
              let anePower = props["ane_power"] as? Double else {
            return 0
        }
        return anePower
    }
}
