import Foundation
import CoreServices
import Combine
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "Trash")

struct TrashRecoveryItem {
    let fileName: String
    let trashURL: URL
    let originalURL: URL
    let timestamp: Date
}

final class TrashMonitor: ObservableObject {
    @Published var pendingRecovery: TrashRecoveryItem? = nil

    private var eventStream: FSEventStreamRef?
    private let trashQueue = DispatchQueue(label: "com.islet.trash", qos: .utility)
    private var recentlyTrashed: [String: URL] = [:] // filename → guessed original URL

    func start() {
        guard let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first else {
            os_log(.debug, log: log, "Could not find Trash directory")
            return
        }

        var ctx = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, eventFlags, _ in
            guard let info = info else { return }
            let monitor = Unmanaged<TrashMonitor>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
            for i in 0..<numEvents {
                let flags = eventFlags[i]
                if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
                    monitor.handleFileMovedToTrash(path: paths[i])
                }
            }
        }

        let watchPaths = [trashURL.path] as CFArray
        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &ctx,
            watchPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = eventStream {
            FSEventStreamSetDispatchQueue(stream, trashQueue)
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

    private func handleFileMovedToTrash(path: String) {
        let trashURL = URL(fileURLWithPath: path)
        let fileName = trashURL.lastPathComponent

        // Best-effort reconstruction: files in Trash typically came from home dir
        let guessedOriginal = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")
            .appendingPathComponent(fileName)

        let item = TrashRecoveryItem(
            fileName: fileName,
            trashURL: trashURL,
            originalURL: guessedOriginal,
            timestamp: Date()
        )

        DispatchQueue.main.async { [weak self] in
            self?.pendingRecovery = item
        }

        // Auto-clear after recovery window
        let window = Double(SystemConfig.shared.fileRecoveryWindowSeconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + window) { [weak self] in
            if self?.pendingRecovery?.trashURL == trashURL {
                self?.pendingRecovery = nil
            }
        }
    }

    func restore(trashURL: URL, to originalURL: URL) {
        do {
            try FileManager.default.moveItem(at: trashURL, to: originalURL)
            os_log(.debug, log: log, "Restored %{public}@ to %{public}@", trashURL.path, originalURL.path)
        } catch {
            os_log(.debug, log: log, "Restore failed: %{public}@", error.localizedDescription)
        }
        DispatchQueue.main.async { self.pendingRecovery = nil }
    }
}
