import Testing
@testable import WattBarCore

struct PowerDeriverTests {
    private func close(_ value: Double?, _ expected: Double) -> Bool {
        abs((value ?? .nan) - expected) < 0.001
    }

    @Test func fullSMC() {
        let raw = RawReadings(
            smc: SMCPowerReadings(systemTotalW: 33, dcInW: 29.4, backlightW: 8.3),
            battery: BatteryReadings(externalConnected: true, voltageMV: 12600, amperageMA: 0),
            usbDevices: [
                USBDeviceReading(id: 1, name: "LAN", allocationMA: 350),
                USBDeviceReading(id: 2, name: "EarPods", allocationMA: 300),
            ]
        )
        let snapshot = PowerDeriver.derive(raw)
        #expect(close(snapshot.display.watts, 8.3))
        #expect(snapshot.display.quality == .measured)
        #expect(close(snapshot.external.watts, 3.25))
        #expect(snapshot.external.quality == .allocated)
        #expect(close(snapshot.computer.watts, 21.45))
        #expect(snapshot.computer.quality == .derived)
        #expect(close(snapshot.input.watts, 29.4))
    }

    @Test func smcMissingFallsBackToSystemLoad() {
        let battery = BatteryReadings(
            externalConnected: true,
            voltageMV: 12600,
            amperageMA: 0,
            telemetry: BatteryTelemetry(systemLoadMW: 26860, systemPowerInMW: 26860)
        )
        let raw = RawReadings(
            smc: nil,
            battery: battery,
            usbDevices: [USBDeviceReading(id: 1, name: "LAN", allocationMA: 350)]
        )
        let snapshot = PowerDeriver.derive(raw)
        #expect(close(snapshot.total.watts, 26.86))
        #expect(snapshot.display.quality == .unavailable)
        #expect(close(snapshot.computer.watts, 26.86 - 1.75))
        #expect(close(snapshot.input.watts, 26.86))
    }

    @Test func charging() {
        let raw = RawReadings(
            smc: SMCPowerReadings(systemTotalW: 30),
            battery: BatteryReadings(externalConnected: true, voltageMV: 12600, amperageMA: 2000)
        )
        let snapshot = PowerDeriver.derive(raw)
        #expect(close(snapshot.charge.watts, 25.2))
        #expect(close(snapshot.discharge.watts, 0))
        #expect(snapshot.state == .charging)
    }

    @Test func onBatteryWithoutTelemetry() {
        let raw = RawReadings(
            smc: nil,
            battery: BatteryReadings(externalConnected: false, voltageMV: 12000, amperageMA: -1500)
        )
        let snapshot = PowerDeriver.derive(raw)
        #expect(close(snapshot.total.watts, 18.0))
        #expect(close(snapshot.input.watts, 0))
        #expect(close(snapshot.discharge.watts, 18.0))
        #expect(close(snapshot.charge.watts, 0))
        #expect(snapshot.state == .onBattery)
    }

    @Test func computerNeverNegative() {
        let raw = RawReadings(
            smc: SMCPowerReadings(systemTotalW: 5, backlightW: 3),
            battery: BatteryReadings(externalConnected: true, amperageMA: 0),
            ports: [PortReading(portNumber: 1, powerOutW: 4)]
        )
        let snapshot = PowerDeriver.derive(raw)
        #expect(close(snapshot.computer.watts, 0))
    }

    @Test func invalidSMCValueFallsBack() {
        let telemetry = BatteryTelemetry(systemLoadMW: 20000)
        let battery = BatteryReadings(externalConnected: true, amperageMA: 0, telemetry: telemetry)
        for bad in [Double.nan, 9999] {
            let raw = RawReadings(smc: SMCPowerReadings(systemTotalW: bad), battery: battery)
            #expect(close(PowerDeriver.derive(raw).total.watts, 20.0))
        }
    }

    @Test func unsupportedMachine() {
        let snapshot = PowerDeriver.derive(RawReadings(smc: nil, battery: nil))
        #expect(snapshot.state == .unsupported)
        #expect(snapshot.total.quality == .unavailable)
        #expect(snapshot.total.watts == nil)
    }

    @Test func fixtureBatteryDerives() throws {
        let roots = try FixtureLoader.load("battery_ac_full")
        let first = try #require(roots.first)
        let battery = try #require(BatteryParser.parse(first))
        let snapshot = PowerDeriver.derive(RawReadings(smc: nil, battery: battery))
        #expect((snapshot.total.watts ?? 0) > 0)
        #expect(snapshot.adapterWatts == 90)
    }
}
