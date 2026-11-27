import Foundation

public enum PortParser {
    public static func parse(_ props: [String: Any]) -> PortReading? {
        guard let number = RegistryValue.int(props["PortNumber"]) else { return nil }
        let transports = (props["TransportsActive"] as? [Any])?.compactMap { RegistryValue.string($0) } ?? []
        return PortReading(
            portNumber: number,
            connectionActive: RegistryValue.bool(props["ConnectionActive"]) ?? false,
            transports: transports,
            powerOutW: powerOut(props["PowerOutDetails"])
        )
    }

    static func powerOut(_ value: Any?) -> Double? {
        if let single = RegistryValue.dict(value) {
            return watts(single)
        }
        if let list = value as? [Any] {
            let all = list.compactMap { RegistryValue.dict($0) }.compactMap { watts($0) }
            return all.isEmpty ? nil : all.reduce(0, +)
        }
        return nil
    }

    private static func watts(_ details: [String: Any]) -> Double? {
        if let milliwatts = RegistryValue.int(details["PDPowermW"]), milliwatts > 0 {
            return Double(milliwatts) / 1000
        }
        if let watts = RegistryValue.int(details["Watts"]), watts > 0 {
            return Double(watts)
        }
        if let volts = RegistryValue.int(details["Voltage"]),
           let amps = RegistryValue.int(details["Current"]),
           volts > 0, amps > 0 {
            return Double(volts) * Double(amps) / 1_000_000
        }
        return nil
    }
}
