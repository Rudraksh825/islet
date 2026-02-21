import AppKit
import SwiftUI
import Combine

// Notch geometry measured once at startup and on screen changes.
struct NotchGeometry {
    let screenFrame: NSRect
    // The physical notch rectangle in screen coordinates (origin at bottom-left of screen).
    let notchRect: NSRect
    // Menu bar height (height of the area beside the notch).
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
        let safe = screen.safeAreaInsets.top   // menu bar + notch height on notched Macs

        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            // Notched Mac: auxiliaryTopLeftArea/RightArea bound the notch exactly.
            let notchLeft  = left.maxX
            let notchRight = right.minX
            let notchBottom = left.minY          // bottom of menu bar stripe
            let notchTop    = screen.frame.maxY  // physical top of screen

            self.menuBarHeight = left.height
            self.notchRect = NSRect(
                x: notchLeft,
                y: notchBottom,
                width: notchRight - notchLeft,
                height: notchTop - notchBottom
            )
        } else {
            // No notch: treat the whole menu bar as the notch zone with zero width.
            let barH = safe > 0 ? safe : 32
            self.menuBarHeight = barH
            // Zero-width notch in the centre so layouts still work.
            self.notchRect = NSRect(
                x: screen.frame.midX,
                y: screen.frame.maxY - barH,
                width: 0,
                height: barH
            )
        }
    }

    init(screenFrame: NSRect, notchRect: NSRect, menuBarHeight: CGFloat) {
        self.screenFrame = screenFrame
        self.notchRect = notchRect
        self.menuBarHeight = menuBarHeight
    }

    // Notch centre in screen coordinates
    var notchCenterX: CGFloat { notchRect.midX }
    // Bottom edge of notch (== bottom of menu bar on notched Macs)
    var notchBottomY: CGFloat { notchRect.minY }
    // Half-width of the physical notch pill
    var notchHalfWidth: CGFloat { notchRect.width / 2 }
}

final class IslandWindowController: NSObject {

    private var panel: NSPanel!
    private var hostingView: NSHostingView<NotchIslandView>!
    private let viewModel: IslandViewModel
    private var cancellables = Set<AnyCancellable>()

    // Notch geometry — refreshed on screen change
    private(set) var notchGeometry: NotchGeometry = .current

    init(viewModel: IslandViewModel) {
        self.viewModel = viewModel
        super.init()
        setupPanel()
        subscribeToModeChanges()
        subscribeToScreenChanges()
    }

    // MARK: - Panel Setup

    private func setupPanel() {
        let geo = notchGeometry
        // The panel covers the full notch zone + some downward expansion space
        let panelFrame = frameForExpansion(height: 0)

        panel = NSPanel(
            contentRect: panelFrame,
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
        hostingView.frame = CGRect(origin: .zero, size: panelFrame.size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        panel.orderOut(nil)
        _ = geo  // suppress unused warning
    }

    // MARK: - Mode subscription

    private func subscribeToModeChanges() {
        viewModel.$currentMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.handleModeChange(mode)
            }
            .store(in: &cancellables)
    }

    private func handleModeChange(_ mode: IslandMode) {
        let expansionHeight: CGFloat = mode == .collapsed ? 0 : mode.expansionHeight
        let targetFrame = frameForExpansion(height: expansionHeight)

        if mode == .collapsed {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(targetFrame, display: true)
            }, completionHandler: {
                self.panel.orderOut(nil)
            })
        } else {
            if !panel.isVisible {
                panel.setFrame(frameForExpansion(height: 0), display: false)
                panel.orderFrontRegardless()
            }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(targetFrame, display: true)
            }
        }
    }

    // The panel spans the full notch width + padding on both sides.
    // Its top edge is always flush with the top of the screen.
    // expansionHeight = how far below the notch bottom the content extends.
    private func frameForExpansion(height: CGFloat) -> NSRect {
        let geo = notchGeometry
        let padding: CGFloat = 80   // extra space on each side beyond the notch
        let totalWidth = geo.notchRect.width + padding * 2
        let totalHeight = geo.menuBarHeight + height
        let x = geo.notchCenterX - totalWidth / 2
        let y = geo.screenFrame.maxY - totalHeight
        return NSRect(x: x, y: y, width: totalWidth, height: totalHeight)
    }

    // MARK: - Screen change notifications

    private func subscribeToScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        notchGeometry = .current
        // Rebuild the hosting view with new geometry
        let rootView = NotchIslandView(viewModel: viewModel, geometry: notchGeometry)
        hostingView.rootView = rootView
        guard panel.isVisible else { return }
        let mode = viewModel.currentMode
        let h = mode == .collapsed ? 0 : mode.expansionHeight
        panel.setFrame(frameForExpansion(height: h), display: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
