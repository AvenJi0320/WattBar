import Testing
@testable import WattBarCore

struct ExternalPowerStrategyTests {
    private let strategy = LayeredExternalPowerStrategy()

    @Test func contractsWinOverAllocations() {
        let ports = [PortReading(portNumber: 1, powerOutW: 15), PortReading(portNumber: 2, powerOutW: 5)]
        let devices = [USBDeviceReading(id: 1, name: "A", allocationMA: 500)]
        let (metric, list) = strategy.evaluate(ports: ports, devices: devices)
        #expect(metric.quality == .contracted)
        #expect(metric.watts == 20)
        #expect(list.count == 3)
    }

    @Test func allocationsOnly() {
        let devices = [
            USBDeviceReading(id: 1, name: "LAN", allocationMA: 350),
            USBDeviceReading(id: 2, name: "EarPods", allocationMA: 300),
        ]
        let (metric, _) = strategy.evaluate(ports: [], devices: devices)
        #expect(metric.quality == .allocated)
        #expect(abs((metric.watts ?? 0) - 3.25) < 0.001)
    }

    @Test func builtInDevicesExcluded() {
        let devices = [
            USBDeviceReading(id: 1, name: "Cam", allocationMA: 500, isBuiltIn: true),
            USBDeviceReading(id: 2, name: "LAN", allocationMA: 100),
        ]
        let (metric, list) = strategy.evaluate(ports: [], devices: devices)
        #expect(abs((metric.watts ?? 0) - 0.5) < 0.001)
        #expect(list.count == 1)
    }

    @Test func noDevicesIsMeasuredZero() {
        let (metric, list) = strategy.evaluate(ports: [PortReading(portNumber: 1)], devices: [])
        #expect(metric.watts == 0)
        #expect(metric.quality == .measured)
        #expect(list.isEmpty)
    }

    @Test func zeroAllocationExcluded() {
        let devices = [USBDeviceReading(id: 1, name: "Hub", allocationMA: 0)]
        let (metric, list) = strategy.evaluate(ports: [], devices: devices)
        #expect(metric.quality == .measured)
        #expect(list.isEmpty)
    }
}
