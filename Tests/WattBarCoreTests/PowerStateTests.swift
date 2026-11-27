import Testing
@testable import WattBarCore

struct PowerStateTests {
    @Test func charging() {
        let battery = BatteryReadings(externalConnected: true, amperageMA: 2000)
        #expect(PowerState(battery: battery) == .charging)
    }

    @Test func pluggedIdleWhenFull() {
        let battery = BatteryReadings(externalConnected: true, fullyCharged: true, amperageMA: 0)
        #expect(PowerState(battery: battery) == .pluggedIdle)
    }

    @Test func pluggedIdleWhenZeroCurrent() {
        let battery = BatteryReadings(externalConnected: true, amperageMA: 0)
        #expect(PowerState(battery: battery) == .pluggedIdle)
    }

    @Test func pluggedDraining() {
        let battery = BatteryReadings(externalConnected: true, amperageMA: -800)
        #expect(PowerState(battery: battery) == .pluggedDraining)
    }

    @Test func onBattery() {
        let battery = BatteryReadings(externalConnected: false, amperageMA: -1500)
        #expect(PowerState(battery: battery) == .onBattery)
    }

    @Test func unsupportedWithoutBattery() {
        #expect(PowerState(battery: nil) == .unsupported)
    }

    @Test func iconMapping() {
        #expect(IconState(.charging) == .charging)
        #expect(IconState(.pluggedIdle) == .plugged)
        #expect(IconState(.pluggedDraining) == .plugged)
        #expect(IconState(.onBattery) == .battery)
        #expect(IconState(.unsupported) == .unavailable)
    }
}
