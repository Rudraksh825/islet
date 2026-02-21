import Foundation
import Darwin
import Combine
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "Network")

final class NetworkMonitor: ObservableObject {
    @Published var uploadBytesPerSec: Double = 0
    @Published var downloadBytesPerSec: Double = 0
    @Published var topProcesses: [(name: String, bytesPerSec: Double)] = []

    private var timer: AnyCancellable?
    private var prevBytesIn: UInt64 = 0
    private var prevBytesOut: UInt64 = 0
    private let netQueue = DispatchQueue(label: "com.islet.network", qos: .utility)

    func start() {
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.poll() }
    }

    func stop() {
        timer?.cancel()
    }

    private func poll() {
        netQueue.async { [weak self] in
            guard let self = self else { return }
            let (bytesIn, bytesOut) = self.readTotalBytes()
            let up = bytesOut > self.prevBytesOut ? Double(bytesOut - self.prevBytesOut) : 0
            let down = bytesIn > self.prevBytesIn ? Double(bytesIn - self.prevBytesIn) : 0
            self.prevBytesIn = bytesIn
            self.prevBytesOut = bytesOut

            DispatchQueue.main.async {
                self.uploadBytesPerSec = up
                self.downloadBytesPerSec = down
            }
        }
    }

    // Read total bytes across all non-loopback interfaces using getifaddrs
    private func readTotalBytes() -> (UInt64, UInt64) {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (0, 0) }
        defer { freeifaddrs(firstAddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let iface = current.pointee
            if iface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: iface.ifa_name)
                guard !name.hasPrefix("lo") else { ptr = iface.ifa_next; continue }

                if let data = iface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    totalIn  += UInt64(data.pointee.ifi_ibytes)
                    totalOut += UInt64(data.pointee.ifi_obytes)
                }
            }
            ptr = iface.ifa_next
        }
        return (totalIn, totalOut)
    }
}
