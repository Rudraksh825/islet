import Foundation
import IOKit
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "SMC")

// SMC data structures matching the AppleSMC kernel interface
struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

struct SMCKeyData_t {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    )
}

final class SMCHelper {

    private var connection: io_connect_t = IO_OBJECT_NULL
    private let queue = DispatchQueue(label: "com.islet.smc", qos: .utility)
    private var isOpen = false

    static let shared = SMCHelper()

    private init() {
        open()
    }

    deinit {
        close()
    }

    private func open() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != IO_OBJECT_NULL else {
            os_log(.debug, log: log, "AppleSMC service not found")
            return
        }
        defer { IOObjectRelease(service) }
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        isOpen = result == kIOReturnSuccess
        if !isOpen {
            os_log(.debug, log: log, "Failed to open SMC connection: %d", result)
        }
    }

    private func close() {
        if isOpen {
            IOServiceClose(connection)
            isOpen = false
        }
    }

    // MARK: - Key reading

    private func keyToUInt32(_ key: String) -> UInt32 {
        var result: UInt32 = 0
        for char in key.utf8.prefix(4) {
            result = result << 8 | UInt32(char)
        }
        return result
    }

    private func callSMC(_ inputStruct: inout SMCKeyData_t, _ outputStruct: inout SMCKeyData_t) -> kern_return_t {
        guard isOpen else { return kIOReturnNotOpen }
        var inputSize = MemoryLayout<SMCKeyData_t>.size
        var outputSize = MemoryLayout<SMCKeyData_t>.size
        return IOConnectCallStructMethod(
            connection,
            UInt32(2), // kSMCGetKeyValue
            &inputStruct, inputSize,
            &outputStruct, &outputSize
        )
    }

    // Returns temperature for a given 4-char SMC key (e.g. "TC0P"), or nil on failure
    func temperature(forKey key: String) -> Double? {
        guard isOpen else { return nil }
        var inputStruct = SMCKeyData_t()
        var outputStruct = SMCKeyData_t()

        // First, get key info (selector 9 = kSMCGetKeyInfo)
        inputStruct.key = keyToUInt32(key)
        inputStruct.data8 = UInt8(9) // kSMCGetKeyInfo
        var inputSize = MemoryLayout<SMCKeyData_t>.size
        var outputSize = MemoryLayout<SMCKeyData_t>.size
        let kr = IOConnectCallStructMethod(connection, 2, &inputStruct, inputSize, &outputStruct, &outputSize)
        guard kr == kIOReturnSuccess else { return nil }

        // Now read value
        var readInput = SMCKeyData_t()
        var readOutput = SMCKeyData_t()
        readInput.key = keyToUInt32(key)
        readInput.keyInfo.dataSize = outputStruct.keyInfo.dataSize
        readInput.data8 = UInt8(5) // kSMCReadKey
        inputSize = MemoryLayout<SMCKeyData_t>.size
        outputSize = MemoryLayout<SMCKeyData_t>.size
        let kr2 = IOConnectCallStructMethod(connection, 2, &readInput, inputSize, &readOutput, &outputSize)
        guard kr2 == kIOReturnSuccess else { return nil }

        // SP78 format: 2 bytes, first is integer part, second is fractional /256
        let b0 = readOutput.bytes.0
        let b1 = readOutput.bytes.1
        let temp = Double(b0) + Double(b1) / 256.0
        return temp > 0 && temp < 150 ? temp : nil
    }

    // Returns fan speed in RPM for fan index (0 = first fan)
    func fanSpeed(index: Int) -> Double? {
        guard isOpen else { return nil }
        let key = String(format: "F%dAc", index)
        var inputStruct = SMCKeyData_t()
        var outputStruct = SMCKeyData_t()
        inputStruct.key = keyToUInt32(key)
        inputStruct.data8 = UInt8(5) // kSMCReadKey
        inputStruct.keyInfo.dataSize = 2
        var inputSize = MemoryLayout<SMCKeyData_t>.size
        var outputSize = MemoryLayout<SMCKeyData_t>.size
        let kr = IOConnectCallStructMethod(connection, 2, &inputStruct, inputSize, &outputStruct, &outputSize)
        guard kr == kIOReturnSuccess else { return nil }

        // FPE2 format: fixed point 2^2
        let b0 = outputStruct.bytes.0
        let b1 = outputStruct.bytes.1
        let rpm = (Double(b0) * 256.0 + Double(b1)) / 4.0
        return rpm > 0 ? rpm : nil
    }

    // Async wrappers
    func readTemperatures(completion: @escaping (Double?, Double?) -> Void) {
        queue.async { [weak self] in
            let cpu = self?.temperature(forKey: "TC0P")
            let gpu = self?.temperature(forKey: "TG0P")
            completion(cpu, gpu)
        }
    }

    func readFanSpeeds(completion: @escaping ([Double]) -> Void) {
        queue.async { [weak self] in
            var speeds: [Double] = []
            for i in 0..<4 {
                if let rpm = self?.fanSpeed(index: i) {
                    speeds.append(rpm)
                } else {
                    break
                }
            }
            completion(speeds)
        }
    }
}
