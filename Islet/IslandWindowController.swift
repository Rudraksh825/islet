import AppKit
import SwiftUI
import Combine

struct NotchGeometry: Equatable {
    let screenFrame: NSRect
    let notchRect: NSRect      // screen coords: x range of notch, full menu-bar height
    let menuBarHeight: CGFloat

    static var current: NotchGeometry {
        guard let screen = NSScreen.main else {
            return NotchGeometry(
                screenFrame: NSRect(x: 0, y: 0, width: 1440, height: 900),
                notchRect: NSRect(x: 580, y: 864, width: 160, height: 36),
                menuBarHeight: 36
            )
        }
        return NotchGeometry(screen: screen)
    }

    init(screen: NSScreen) {
        self.screenFrame = screen.frame
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            self.menuBarHeight = left.height
            self.notchRect = NSRect(
                x: left.maxX, y: left.minY,
                width: right.minX - left.maxX,
                height: screen.frame.maxY - left.minY
            )
        } else {
            let barH = max(screen.safeAreaInsets.top, 32)
            self.menuBarHeight = barH
            self.notchRect = NSRect(
                x: screen.frame.midX, y: screen.frame.maxY - barH,
                width: 0, height: barH
            )
        }
    }

    init(screenFrame: NSRect, notchRect: NSRect, menuBarHeight: CGFloat) {
        self.screenFrame = screenFrame; self.notchRect = notchRect; self.menuBarHeight = menuBarHeight
    }

    var notchCenterX: CGFloat   { notchRect.midX }
    var notchBottomY: CGFloat   { notchRect.minY }
    var notchWidth: CGFloat     { notchRect.width }
    var notchHalfWidth: CGFloat { notchRect.width / 2 }
}

final class IslandWindowController: NSObject {

    private var panel: NSPanel!
    private var hostingView: NSHostingView<NotchIslandView>!
    private let viewModel: IslandViewModel
    private var cancellables = Set<AnyCancellable>()
    private var geo: NotchGeometry = .current

    init(viewModel: IslandViewModel) {
        self.viewModel = viewModel
        super.init()
        setupPanel()
        subscribeToModeChanges()
        subscribeToScreenChanges()
    }

    // MARK: - Panel setup

    private func setupPanel() {
        geo = .current
        let frame = panelFrame()

        panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        panel.isMovable = false
        panel.acceptsMouseMovedEvents = true

        let rootView = NotchIslandView(viewModel: viewModel, geometry: geo)
        hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = CGRect(origin: .zero, size: frame.size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        panel.orderOut(nil)
    }

    // Panel is always exactly the menu bar strip: full width, menuBarHeight tall, top of screen.
    // It never changes size — only shows/hides.
    private func panelFrame() -> NSRect {
        return NSRect(
            x: geo.screenFrame.minX,
            y: geo.screenFrame.maxY - geo.menuBarHeight,
            width: geo.screenFrame.width,
            height: geo.menuBarHeight
        )
    }

    // MARK: - Mode changes

    private func subscribeToModeChanges() {
        viewModel.$currentMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in self?.handleModeChange(mode) }
            .store(in: &cancellables)
    }

    private func handleModeChange(_ mode: IslandMode) {
        if mode == .collapsed {
            panel.orderOut(nil)
        } else {
            if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        }
    }

    // MARK: - Screen changes

    private func subscribeToScreenChanges() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        geo = .current
        hostingView.rootView = NotchIslandView(viewModel: viewModel, geometry: geo)
        panel.setFrame(panelFrame(), display: true)
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}
