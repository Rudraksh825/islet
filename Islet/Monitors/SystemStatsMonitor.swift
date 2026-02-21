import Foundation
import IOKit
import Darwin
import Combine
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "SystemStats")

final class SystemStatsMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0
    @Published var gpuUsage: Double = 0
    @Published var cpuTemp: Double = 0
    @Published var gpuTemp: Double = 0
    @Published var fanRPM: [Double] = []
    @Published var thermalState: ProcessInfo.ThermalState = .nominal

    private var timer: AnyCancellable?
    private var prevCPUInfo: processor_info_array_t?
    private var prevCPUInfoCount: mach_msg_type_number_t = 0
    private let statsQueue = DispatchQueue(label: "com.islet.systemstats", qos: .utility)

    func start() {
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.poll() }
    }

    func stop() {
        timer?.cancel()
    }

    private func poll() {
        statsQueue.async { [weak self] in
            let cpu = self?.readCPUUsage() ?? 0
            let gpu = IOKitHelper.readGPUUtilization()
            let thermal = ProcessInfo.processInfo.thermalState

            SMCHelper.shared.readTemperatures { cpuT, gpuT in
                SMCHelper.shared.readFanSpeeds { fans in
                    DispatchQueue.main.async {
                        self?.cpuUsage = cpu
                        self?.gpuUsage = gpu
                        self?.thermalState = thermal
                        self?.cpuTemp = cpuT ?? 0
                        self?.gpuTemp = gpuT ?? 0
                        self?.fanRPM = fans
                    }
                }
            }
        }
    }

    // MARK: - CPU Usage via host_processor_info
    private func readCPUUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0

        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &cpuInfoCount)
        guard kr == KERN_SUCCESS, let info = cpuInfo else { return 0 }

        var totalUser: Int32 = 0
        var totalSys: Int32 = 0
        var totalIdle: Int32 = 0
        var totalNice: Int32 = 0

        for i in 0..<Int(numCPUs) {
            let base = Int(CPU_STATE_MAX) * i
            let user  = info[base + Int(CPU_STATE_USER)]
            let sys   = info[base + Int(CPU_STATE_SYSTEM)]
            let idle  = info[base + Int(CPU_STATE_IDLE)]
            let nice  = info[base + Int(CPU_STATE_NICE)]

            if let prev = prevCPUInfo {
                let pBase = Int(CPU_STATE_MAX) * i
                let pUser  = prev[pBase + Int(CPU_STATE_USER)]
                let pSys   = prev[pBase + Int(CPU_STATE_SYSTEM)]
                let pIdle  = prev[pBase + Int(CPU_STATE_IDLE)]
                let pNice  = prev[pBase + Int(CPU_STATE_NICE)]
                totalUser += user - pUser
                totalSys  += sys  - pSys
                totalIdle += idle - pIdle
                totalNice += nice - pNice
            }
        }

        if let prev = prevCPUInfo {
            let size = MemoryLayout<integer_t>.size * Int(prevCPUInfoCount)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(size))
        }
        prevCPUInfo = info
        prevCPUInfoCount = cpuInfoCount

        let total = totalUser + totalSys + totalIdle + totalNice
        guard total > 0 else { return 0 }
        return Double(totalUser + totalSys + totalNice) / Double(total)
    }
}
