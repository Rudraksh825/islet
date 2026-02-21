import Foundation
import AppKit
import Combine

final class AppUsageMonitor: ObservableObject {
    @Published var companions: [(bundleID: String, icon: NSImage?)] = []

    private var usageMap: [String: [String: Int]] = [:] // [frontApp: [companion: count]]
    private var previousAppID: String?
    private var currentAppID: String?
    private let usageKey = "appUsageMap"

    func start() {
        loadUsageMap()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func appActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let newID = app.bundleIdentifier else { return }

        if let prevID = currentAppID, prevID != newID {
            previousAppID = prevID
            // Increment companion count
            var companions = usageMap[newID] ?? [:]
            companions[prevID, default: 0] += 1
            usageMap[newID] = companions
            saveUsageMap()
        }

        currentAppID = newID
        updateCompanions(for: newID)
    }

    private func updateCompanions(for bundleID: String) {
        guard let companions = usageMap[bundleID], companions.count >= 5 else {
            DispatchQueue.main.async { self.companions = [] }
            return
        }

        let top3 = companions.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        let result = top3.map { id -> (bundleID: String, icon: NSImage?) in
            let icon = iconForBundleID(id)
            return (bundleID: id, icon: icon)
        }
        DispatchQueue.main.async { self.companions = result }
    }

    private func iconForBundleID(_ bundleID: String) -> NSImage? {
        guard let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: path)
    }

    private func saveUsageMap() {
        if let data = try? JSONEncoder().encode(usageMap.mapValues { $0 }) {
            UserDefaults.standard.set(data, forKey: usageKey)
        }
    }

    private func loadUsageMap() {
        guard let data = UserDefaults.standard.data(forKey: usageKey),
              let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data) else { return }
        usageMap = decoded
    }
}
