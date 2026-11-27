public protocol ExternalPowerStrategy: Sendable {
    func evaluate(ports: [PortReading], devices: [USBDeviceReading]) -> (Metric, [ExternalDevice])
}

public struct LayeredExternalPowerStrategy: ExternalPowerStrategy {
    public init() {}

    public func evaluate(
        ports: [PortReading],
        devices: [USBDeviceReading]
    ) -> (Metric, [ExternalDevice]) {
        let contracts = ports.compactMap { port -> ExternalDevice? in
            guard let watts = port.powerOutW, watts > 0 else { return nil }
            return ExternalDevice(
                id: "port-\(port.portNumber)",
                name: "USB-C 端口 \(port.portNumber)",
                watts: watts,
                quality: .contracted
            )
        }

        let allocations = devices.compactMap { device -> ExternalDevice? in
            guard !device.isBuiltIn, device.allocationMA > 0 else { return nil }
            return ExternalDevice(
                id: "usb-\(device.id)",
                name: device.name,
                watts: Double(device.allocationMA) * 5 / 1000,
                quality: .allocated
            )
        }

        let list = contracts + allocations

        if !contracts.isEmpty {
            return (Metric(watts: contracts.reduce(0) { $0 + $1.watts }, quality: .contracted), list)
        }
        if !allocations.isEmpty {
            return (Metric(watts: allocations.reduce(0) { $0 + $1.watts }, quality: .allocated), list)
        }
        return (Metric(watts: 0, quality: .measured), list)
    }
}
