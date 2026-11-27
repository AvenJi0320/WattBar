import AppKit
import WattBarCore

@MainActor
final class StatusItemController: NSObject {
    private let store: PowerStore
    private let settings: Settings
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panelController: PanelController
    private let settingsMenu: SettingsMenu

    init(store: PowerStore, settings: Settings) {
        self.store = store
        self.settings = settings
        panelController = PanelController(store: store)
        settingsMenu = SettingsMenu(settings: settings)
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }
        refresh()
    }

    func refresh() {
        guard let button = statusItem.button else { return }
        let state = IconState(store.snapshot.state)
        let symbol = Self.symbolName(for: state)
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "WattBar")?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        button.image = image

        if settings.showValueInMenuBar, let watts = store.snapshot.total.watts {
            let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.attributedTitle = NSAttributedString(
                string: " \(Int(watts.rounded()))W",
                attributes: [.font: font]
            )
        } else {
            button.attributedTitle = NSAttributedString(string: "")
        }
    }

    private static func symbolName(for state: IconState) -> String {
        switch state {
        case .charging: "bolt.fill"
        case .plugged: "bolt"
        case .battery: "bolt.slash"
        case .unavailable: "bolt.trianglebadge.exclamationmark"
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if wantsMenu {
            panelController.close()
            statusItem.menu = settingsMenu.build()
            sender.performClick(nil)
            statusItem.menu = nil
        } else {
            panelController.toggle(relativeTo: sender)
        }
    }
}
