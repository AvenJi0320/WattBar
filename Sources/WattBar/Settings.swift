import Foundation
import ServiceManagement

enum AppearanceMode: String, CaseIterable {
    case system, light, dark

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }
}

@MainActor
final class Settings {
    private enum Key {
        static let panelInterval = "wattbar.panelIntervalSeconds"
        static let showValue = "wattbar.showValueInMenuBar"
        static let appearance = "wattbar.appearance"
    }

    static let intervalChoices = [1, 2, 5]

    private let defaults: UserDefaults
    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var panelIntervalSeconds: Int {
        get {
            let stored = defaults.integer(forKey: Key.panelInterval)
            return Self.intervalChoices.contains(stored) ? stored : 1
        }
        set {
            defaults.set(newValue, forKey: Key.panelInterval)
            onChange?()
        }
    }

    var showValueInMenuBar: Bool {
        get { defaults.bool(forKey: Key.showValue) }
        set {
            defaults.set(newValue, forKey: Key.showValue)
            onChange?()
        }
    }

    var appearance: AppearanceMode {
        get { defaults.string(forKey: Key.appearance).flatMap(AppearanceMode.init(rawValue:)) ?? .system }
        set {
            defaults.set(newValue.rawValue, forKey: Key.appearance)
            onChange?()
        }
    }

    var canLaunchAtLogin: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            guard canLaunchAtLogin else { return }
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("WattBar: launch at login change failed: \(error)")
            }
        }
    }
}
