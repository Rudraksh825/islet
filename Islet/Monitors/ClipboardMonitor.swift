import Foundation
import AppKit
import Combine
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "Clipboard")

final class ClipboardMonitor: ObservableObject {
    @Published var items: [ClipboardItem] = []

    private var timer: AnyCancellable?
    private var lastChangeCount: Int = 0
    private let clipQueue = DispatchQueue(label: "com.islet.clipboard", qos: .utility)

    func start() {
        loadPersistedItems()
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.checkPasteboard() }
    }

    func stop() {
        timer?.cancel()
    }

    private func checkPasteboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        clipQueue.async { [weak self] in
            self?.readPasteboard()
        }
    }

    private func readPasteboard() {
        let pb = NSPasteboard.general

        var newItem: ClipboardItem?

        if let str = pb.string(forType: .string) {
            if let url = URL(string: str), url.scheme != nil {
                newItem = .url(url)
            } else {
                newItem = .text(str)
            }
        } else if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL], let url = urls.first {
            if url.isFileURL {
                newItem = .file(url)
            } else {
                newItem = .url(url)
            }
        } else if let images = pb.readObjects(forClasses: [NSImage.self]) as? [NSImage], let image = images.first {
            if let data = image.tiffRepresentation {
                newItem = .image(data)
            }
        }

        guard let item = newItem else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let maxSize = SystemConfig.shared.clipboardStackSize
            self.items.removeAll { $0.id == item.id }
            self.items.insert(item, at: 0)
            if self.items.count > maxSize {
                self.items = Array(self.items.prefix(maxSize))
            }
            self.persistItems()
        }
    }

    func setActive(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item {
        case .text(let s):
            pb.setString(s, forType: .string)
        case .url(let u):
            pb.setString(u.absoluteString, forType: .string)
        case .file(let u):
            pb.writeObjects([u as NSURL])
        case .image(let d):
            if let img = NSImage(data: d) {
                pb.writeObjects([img])
            }
        }
        lastChangeCount = pb.changeCount
    }

    func removeItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        persistItems()
    }

    // MARK: - Persistence
    private func persistItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "clipboardStack")
        }
    }

    private func loadPersistedItems() {
        guard let data = UserDefaults.standard.data(forKey: "clipboardStack"),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else { return }
        DispatchQueue.main.async { self.items = decoded }
    }
}
