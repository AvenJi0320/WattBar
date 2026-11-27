import AppKit
import SwiftUI
import WattBarCore

@MainActor
enum PanelRenderer {
    static func render(to path: String, scenario: String) {
        let store = PowerStore(settings: Settings(defaults: UserDefaults(suiteName: "wattbar.render") ?? .standard))
        store.loadPreview(snapshot: snapshot(for: scenario))

        let isDark = scenario.hasSuffix("-dark")
        let content = PanelChrome(store: store)
            .padding(24)
            .environment(\.colorScheme, isDark ? .dark : .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else {
            FileHandle.standardError.write(Data("render failed\n".utf8))
            exit(1)
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
        } catch {
            FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func snapshot(for scenario: String) -> PowerSnapshot {
        var devices = [
            USBDeviceReading(id: 1, name: "USB 10_100_1000 LAN", allocationMA: 350),
            USBDeviceReading(id: 2, name: "EarPods", allocationMA: 300),
        ]
        if scenario.hasPrefix("many") {
            devices += [
                USBDeviceReading(id: 3, name: "Logitech USB Receiver", allocationMA: 100),
                USBDeviceReading(id: 4, name: "Samsung Portable SSD T7 Shield", allocationMA: 896),
                USBDeviceReading(id: 5, name: "YubiKey OTP+FIDO+CCID", allocationMA: 30),
            ]
        } else if scenario.hasPrefix("none") {
            devices = []
        }
        let smc = SMCPowerReadings(systemTotalW: 33.0, dcInW: 29.4, backlightW: 8.3)
        let telemetry = BatteryTelemetry(adapterLossMW: 640)
        let battery: BatteryReadings
        if scenario.hasPrefix("battery") {
            battery = BatteryReadings(
                externalConnected: false, voltageMV: 12000, amperageMA: -1500, percent: 72,
                timeToEmptyMin: 222, telemetry: telemetry
            )
        } else if scenario.hasPrefix("full") {
            battery = BatteryReadings(
                externalConnected: true, fullyCharged: true, voltageMV: 12647, amperageMA: 0, percent: 100,
                adapterWatts: 90, telemetry: telemetry
            )
        } else {
            battery = BatteryReadings(
                externalConnected: true, isCharging: true, voltageMV: 12600, amperageMA: 2250, percent: 54,
                adapterWatts: 90, telemetry: telemetry
            )
        }
        let smcReadings = scenario.hasPrefix("battery") ? SMCPowerReadings(systemTotalW: 18.0, backlightW: 6.0) : smc
        return PowerDeriver.derive(RawReadings(smc: smcReadings, battery: battery, usbDevices: devices))
    }
}
