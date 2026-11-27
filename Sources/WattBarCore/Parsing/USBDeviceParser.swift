import Foundation

public enum USBDeviceParser {
    public static func parse(_ props: [String: Any], entryID: UInt64) -> USBDeviceReading? {
        let allocation = RegistryValue.int(props["UsbPowerSinkAllocation"])
        let name = RegistryValue.string(props["USB Product Name"])
            ?? RegistryValue.string(props["kUSBProductString"])
        if allocation == nil && name == nil { return nil }

        let builtIn = RegistryValue.bool(props["Built-In"]) == true
            || RegistryValue.string(props["non-removable"]) == "yes"

        return USBDeviceReading(
            id: entryID,
            name: name ?? "未知设备",
            allocationMA: allocation ?? 0,
            isBuiltIn: builtIn
        )
    }
}
