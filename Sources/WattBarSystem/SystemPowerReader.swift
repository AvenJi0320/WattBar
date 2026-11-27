import Foundation
import IOKit
import WattBarCore

public final class SystemPowerReader: @unchecked Sendable {
    public let smc: SMCClient?
    private let usbCache = USBDeviceCache()
    private var batteryService: io_service_t = 0

    private static let batteryKeys = [
        "ExternalConnected", "IsCharging", "FullyCharged", "Voltage", "InstantAmperage",
        "Amperage", "CurrentCapacity", "AvgTimeToEmpty", "AdapterDetails",
        "PowerTelemetryData", "ChargerData",
    ]
    private static let portClasses = ["AppleTCControllerType10", "AppleTCControllerType11"]

    public init() {
        smc = SMCClient()
    }

    deinit {
        if batteryService != 0 { IOObjectRelease(batteryService) }
    }

    public func read() -> RawReadings {
        RawReadings(
            smc: readSMC(),
            battery: readBattery(),
            ports: readPorts(),
            usbDevices: usbCache.devices()
        )
    }

    private func readSMC() -> SMCPowerReadings? {
        guard let smc else { return nil }
        let readings = SMCPowerReadings(
            systemTotalW: smc.readDouble("PSTR"),
            dcInW: smc.readDouble("PDTR"),
            backlightW: smc.readDouble("PDBR"),
            batteryRailW: smc.readDouble("PPBR")
        )
        if readings == SMCPowerReadings() { return nil }
        return readings
    }

    private func readBattery() -> BatteryReadings? {
        if batteryService == 0 {
            batteryService = Registry.firstService(named: "AppleSmartBattery")
        }
        guard batteryService != 0 else { return nil }
        var props: [String: Any] = [:]
        for key in Self.batteryKeys {
            if let value = Registry.property(batteryService, key) {
                props[key] = value
            }
        }
        return BatteryParser.parse(props)
    }

    private func readPorts() -> [PortReading] {
        var byNumber: [Int: PortReading] = [:]
        for className in Self.portClasses {
            Registry.forEachService(named: className) { service in
                var props: [String: Any] = [:]
                for key in ["PortNumber", "ConnectionActive", "TransportsActive"] {
                    if let value = Registry.property(service, key) { props[key] = value }
                }
                if let details = Registry.searchProperty(service, "PowerOutDetails") {
                    props["PowerOutDetails"] = details
                }
                guard let port = PortParser.parse(props) else { return }
                if let existing = byNumber[port.portNumber],
                   existing.connectionActive || !port.connectionActive {
                    return
                }
                byNumber[port.portNumber] = port
            }
        }
        return byNumber.values.sorted { $0.portNumber < $1.portNumber }
    }
}
