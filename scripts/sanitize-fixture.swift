import Foundation

// Keeps only the IORegistry keys that WattBarCore parsers read, so fixtures
// never carry serial numbers, UUIDs, process names or other machine-specific data.
// Usage: swift scripts/sanitize-fixture.swift <battery|usb|ports> <input.plist> <output.plist>

let allowedKeys: [String: Set<String>] = [
    "battery": [
        "ExternalConnected", "IsCharging", "FullyCharged", "Voltage", "InstantAmperage", "Amperage",
        "CurrentCapacity", "AvgTimeToEmpty", "AdapterDetails", "PowerTelemetryData", "ChargerData",
    ],
    "usb": ["USB Product Name", "kUSBProductString", "UsbPowerSinkAllocation", "Built-In", "non-removable"],
    "ports": ["PortNumber", "ConnectionActive", "TransportsActive", "PowerOutDetails"],
]

let allowedNestedKeys: [String: Set<String>] = [
    "AdapterDetails": ["Watts", "AdapterVoltage", "Current"],
    "PowerTelemetryData": ["SystemLoad", "SystemPowerIn", "BatteryPower", "AdapterEfficiencyLoss"],
    "ChargerData": ["NotChargingReason"],
]

func sanitize(_ node: [String: Any], allowed: Set<String>, keepChildren: Bool) -> [String: Any]? {
    var result: [String: Any] = [:]
    for (key, value) in node {
        if key == "IORegistryEntryChildren", keepChildren, let children = value as? [[String: Any]] {
            let cleaned = children.compactMap { sanitize($0, allowed: allowed, keepChildren: true) }
            if !cleaned.isEmpty { result[key] = cleaned }
        } else if allowed.contains(key) {
            if let nested = allowedNestedKeys[key], let dictionary = value as? [String: Any] {
                result[key] = dictionary.filter { nested.contains($0.key) }
            } else {
                result[key] = value
            }
        }
    }
    return result.isEmpty ? nil : result
}

let arguments = CommandLine.arguments
guard arguments.count == 4, let allowed = allowedKeys[arguments[1]] else {
    FileHandle.standardError.write(Data("usage: sanitize-fixture.swift <battery|usb|ports> <input> <output>\n".utf8))
    exit(2)
}

let input = try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
guard let roots = try PropertyListSerialization.propertyList(from: input, format: nil) as? [[String: Any]] else {
    FileHandle.standardError.write(Data("input is not an ioreg -a array\n".utf8))
    exit(1)
}
let cleaned = roots.compactMap { sanitize($0, allowed: allowed, keepChildren: arguments[1] == "usb") }
let output = try PropertyListSerialization.data(fromPropertyList: cleaned, format: .xml, options: 0)
try output.write(to: URL(fileURLWithPath: arguments[3]))
