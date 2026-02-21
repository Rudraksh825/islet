import AppKit
import SwiftUI
import UserNotifications
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "App")

@main
struct IsletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty — all UI is driven by AppDelegate (menu bar + NSPanel island + NSWindow settings)
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    let viewModel = IslandViewModel()
    private var windowController: IslandWindowController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController = IslandWindowController(viewModel: viewModel)
        setupMenuBar()
        requestPermissions()
    }

    // MARK: - Menu bar
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use the PNG from the app bundle (copied from repo root)
            let iconURL = Bundle.module.url(forResource: "menubar_icon", withExtension: "png")
            let img = iconURL.flatMap { NSImage(contentsOf: $0) }
            if let img = img {
                img.isTemplate = true  // lets macOS tint it for dark/light mode
                img.size = NSSize(width: 18, height: 18)
                button.image = img
            } else {
                // Fallback: SF Symbol if image not found in bundle
                button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Islet")
            }
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            openSettings()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Islet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil  // clear so left-click still works next time
    }

    @objc func openSettings() {
        if let win = settingsWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(viewModel: viewModel)
        let hosting = NSHostingController(rootView: settingsView)
        hosting.view.frame = NSRect(x: 0, y: 0, width: 500, height: 400)

        let window = NSWindow(contentViewController: hosting)
        window.title = "Islet Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 500, height: 400))
        window.minSize = NSSize(width: 420, height: 320)
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Permissions
    private func requestPermissions() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                os_log(.debug, log: log, "Notification permission error: %{public}@", error.localizedDescription)
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.notificationMonitor.receive(
                title: content.title,
                body: content.body,
                appName: content.threadIdentifier
            )
        }
        completionHandler([])
    }
}
