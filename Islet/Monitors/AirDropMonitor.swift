import Foundation
import CoreServices
import Combine
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "AirDrop")

final class AirDropMonitor: ObservableObject {
    @Published var pendingFile: String? = nil

    private var eventStream: FSEventStreamRef?
    private let airDropQueue = DispatchQueue(label: "com.islet.airdrop", qos: .utility)

    func start() {
        let downloadsURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")

        var ctx = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, eventFlags, eventIDs in
            guard let info = info else { return }
            let monitor = Unmanaged<AirDropMonitor>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
            for i in 0..<numEvents {
                let flags = eventFlags[i]
                if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
                    monitor.handleNewFile(path: paths[i])
                }
            }
        }

        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &ctx,
            [downloadsURL.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = eventStream {
            FSEventStreamSetDispatchQueue(stream, airDropQueue)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    deinit {
        stop()
    }

    private func handleNewFile(path: String) {
        let url = URL(fileURLWithPath: path)
        // Heuristic: files created within last 5 seconds in ~/Downloads are likely AirDrop
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        if let created = attrs?[.creationDate] as? Date, Date().timeIntervalSince(created) < 5 {
            DispatchQueue.main.async { [weak self] in
                self?.pendingFile = url.lastPathComponent
                DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                    self?.pendingFile = nil
                }
            }
        }
    }
}
