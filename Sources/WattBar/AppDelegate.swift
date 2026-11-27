import AppKit
import WattBarSystem

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private lazy var store = PowerStore(settings: settings)
    private var statusController: StatusItemController?
    private let powerObserver = PowerSourceObserver()
    private var workspaceObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyAppearance()
        let controller = StatusItemController(store: store, settings: settings)
        statusController = controller

        store.onUpdate = { [weak controller] in controller?.refresh() }
        settings.onChange = { [weak self] in
            guard let self else { return }
            self.applyAppearance()
            self.store.settingsChanged()
            self.statusController?.refresh()
        }

        store.start()
        powerObserver.start { [weak self] in self?.store.refreshNow() }
        observeWorkspace()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
        powerObserver.stop()
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    private func applyAppearance() {
        switch settings.appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        let suspendNames: [Notification.Name] = [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification]
        let resumeNames: [Notification.Name] = [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification]
        for name in suspendNames {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.store.setSuspended(true) }
            })
        }
        for name in resumeNames {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.store.setSuspended(false) }
            })
        }
    }
}
