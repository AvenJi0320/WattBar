import AppKit
import SwiftUI

private final class WattBarPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSPopoverDelegate {
    private let store: PowerStore
    private let popover = NSPopover()
    private var panel: NSPanel?
    private var panelHosting: NSHostingController<PanelChrome>?
    private weak var anchor: NSStatusBarButton?
    private var sizeObservation: NSKeyValueObservation?
    private var globalClickMonitor: Any?
    private var activationObserver: NSObjectProtocol?

    private static let gapBelowMenuBar: CGFloat = 6
    private static let screenMargin: CGFloat = 8

    init(store: PowerStore) {
        self.store = store
        super.init()
        popover.behavior = .transient
        popover.delegate = self
    }

    var isShown: Bool { panel != nil || popover.isShown }

    func toggle(relativeTo button: NSStatusBarButton) {
        if isShown {
            close()
        } else if Self.isDarkAppearance {
            showPopover(relativeTo: button)
        } else {
            showPanel(relativeTo: button)
        }
    }

    func close() {
        if popover.isShown { popover.performClose(nil) }
        closePanel()
    }

    private static var isDarkAppearance: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    // MARK: Dark mode: system popover (Liquid Glass)

    private func showPopover(relativeTo button: NSStatusBarButton) {
        let hosting = NSHostingController(rootView: PowerPanelView(store: store))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.appearance = NSApp.effectiveAppearance
        store.setPanelOpen(true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    func popoverDidClose(_ notification: Notification) {
        popover.contentViewController = nil
        store.setPanelOpen(false)
    }

    // MARK: Light mode: opaque white panel

    private func showPanel(relativeTo button: NSStatusBarButton) {
        anchor = button

        let hosting = NSHostingController(rootView: PanelChrome(store: store))
        hosting.sizingOptions = [.preferredContentSize]

        let panel = WattBarPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.appearance = NSApp.effectiveAppearance
        panel.contentViewController = hosting

        panelHosting = hosting
        self.panel = panel
        store.setPanelOpen(true)
        layoutPanel()

        sizeObservation = hosting.observe(\.preferredContentSize, options: [.new]) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.layoutPanel() }
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
        installMonitors()
    }

    private func closePanel() {
        guard let panel else { return }
        removeMonitors()
        sizeObservation = nil
        panel.orderOut(nil)
        panel.contentViewController = nil
        self.panel = nil
        panelHosting = nil
        store.setPanelOpen(false)
    }

    private func layoutPanel() {
        guard let panel, let panelHosting, let button = anchor, let buttonWindow = button.window else { return }
        let size = panelHosting.view.fittingSize
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? buttonRect
        var originX = buttonRect.midX - size.width / 2
        originX = min(max(originX, visible.minX + Self.screenMargin), visible.maxX - size.width - Self.screenMargin)
        let originY = buttonRect.minY - Self.gapBelowMenuBar - size.height
        panel.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
        panel.invalidateShadow()
    }

    private func installMonitors() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePanel() }
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePanel() }
        }
    }

    private func removeMonitors() {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
    }
}
