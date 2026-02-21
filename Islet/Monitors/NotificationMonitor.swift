import Foundation
import AppKit
import UserNotifications

struct PendingNotification {
    let title: String
    let body: String
    let appName: String
    let appIcon: NSImage?
}

final class NotificationMonitor: ObservableObject {
    @Published var pendingNotification: PendingNotification? = nil

    func start() {
        // Primary interception is done via AppDelegate's UNUserNotificationCenterDelegate.
        // This monitor just exposes the relay method.
    }

    func stop() {}

    // Called by AppDelegate when a notification arrives
    func receive(title: String, body: String, appName: String) {
        let icon = iconForApp(named: appName)
        DispatchQueue.main.async {
            self.pendingNotification = PendingNotification(
                title: title,
                body: body,
                appName: appName,
                appIcon: icon
            )
        }
    }

    private func iconForApp(named name: String) -> NSImage? {
        // Try to find the app by name in running applications
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.lowercased() == name.lowercased()
        }), let url = app.bundleURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(forFileType: "app")
    }
}
