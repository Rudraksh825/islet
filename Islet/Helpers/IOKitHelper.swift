import Foundation
import IOKit
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "IOKit")

enum IOKitHelper {

    /// Returns the IOService matching the given name, or IO_OBJECT_NULL.
    static func service(named name: String) -> io_service_t {
        IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(name))
    }

    /// Reads a CFDictionary of properties from the given service.
    static func properties(of service: io_service_t) -> [String: Any]? {
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS else {
            return nil
        }
        return props?.takeRetainedValue() as? [String: Any]
    }

    /// Read a nested dictionary value from an IOKit service.
    static func readGPUUtilization() -> Double {
        // Apple Silicon: AGXAccelerator
        var service = service(named: "AGXAccelerator")
        if service == IO_OBJECT_NULL {
            service = IOKitHelper.service(named: "IOAccelerator")
        }
        guard service != IO_OBJECT_NULL else { return 0 }
        defer { IOObjectRelease(service) }

        guard let props = properties(of: service),
              let perfStats = props["PerformanceStatistics"] as? [String: Any],
              let util = perfStats["GPU Core Utilization"] as? Double else {
            return 0
        }
        return util
    }

    /// Read battery properties from AppleSmartBattery.
    static func readBatteryProperties() -> [String: Any]? {
        let service = IOKitHelper.service(named: "AppleSmartBattery")
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }
        return properties(of: service)
    }
}
