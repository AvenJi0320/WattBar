import AppKit

@MainActor
final class SettingsMenu: NSObject {
    private let settings: Settings

    init(settings: Settings) {
        self.settings = settings
    }

    func build() -> NSMenu {
        let menu = NSMenu()

        let intervalItem = NSMenuItem(title: "刷新频率", action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        for seconds in Settings.intervalChoices {
            let item = NSMenuItem(title: "\(seconds) 秒", action: #selector(selectInterval(_:)), keyEquivalent: "")
            item.target = self
            item.tag = seconds
            item.state = settings.panelIntervalSeconds == seconds ? .on : .off
            intervalMenu.addItem(item)
        }
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        let showValue = NSMenuItem(title: "在菜单栏显示功率", action: #selector(toggleShowValue), keyEquivalent: "")
        showValue.target = self
        showValue.state = settings.showValueInMenuBar ? .on : .off
        menu.addItem(showValue)

        let appearanceItem = NSMenuItem(title: "外观", action: nil, keyEquivalent: "")
        let appearanceMenu = NSMenu()
        for (index, mode) in AppearanceMode.allCases.enumerated() {
            let item = NSMenuItem(title: mode.title, action: #selector(selectAppearance(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = settings.appearance == mode ? .on : .off
            appearanceMenu.addItem(item)
            if mode == .system { appearanceMenu.addItem(.separator()) }
        }
        appearanceItem.submenu = appearanceMenu
        menu.addItem(appearanceItem)

        let login = NSMenuItem(title: "登录时启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = settings.launchAtLogin ? .on : .off
        login.isEnabled = settings.canLaunchAtLogin
        menu.addItem(login)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出 WattBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        return menu
    }

    @objc private func selectInterval(_ sender: NSMenuItem) {
        settings.panelIntervalSeconds = sender.tag
    }

    @objc private func toggleShowValue() {
        settings.showValueInMenuBar.toggle()
    }

    @objc private func selectAppearance(_ sender: NSMenuItem) {
        let modes = AppearanceMode.allCases
        guard modes.indices.contains(sender.tag) else { return }
        settings.appearance = modes[sender.tag]
    }

    @objc private func toggleLaunchAtLogin() {
        settings.launchAtLogin.toggle()
    }
}
