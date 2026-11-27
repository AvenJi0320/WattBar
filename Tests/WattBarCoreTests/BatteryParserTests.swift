import Foundation
import Testing
@testable import WattBarCore

struct BatteryParserTests {
    @Test func acFullFixture() throws {
        let roots = try FixtureLoader.load("battery_ac_full")
        let first = try #require(roots.first)
        let readings = try #require(BatteryParser.parse(first))
        #expect(readings.externalConnected)
        #expect(readings.fullyCharged)
        #expect(readings.amperageMA == 0)
        #expect(readings.adapterWatts == 90)
        #expect((readings.telemetry?.systemLoadMW ?? 0) > 0)
        #expect(readings.timeToEmptyMin == nil)
    }

    @Test func dischargingIsNegative() throws {
        let props: [String: Any] = [
            "ExternalConnected": false,
            "Voltage": 12000,
            "InstantAmperage": -1500,
        ]
        let readings = try #require(BatteryParser.parse(props))
        #expect(readings.amperageMA == -1500)
    }

    @Test func unsignedWrapAroundBecomesNegative() throws {
        let props: [String: Any] = [
            "ExternalConnected": false,
            "InstantAmperage": UInt64(18_446_744_073_709_550_616),
        ]
        let readings = try #require(BatteryParser.parse(props))
        #expect(readings.amperageMA == -1000)
    }

    @Test func amperageFallsBackToAmperageKey() throws {
        let props: [String: Any] = ["ExternalConnected": true, "Amperage": 2000]
        let readings = try #require(BatteryParser.parse(props))
        #expect(readings.amperageMA == 2000)
    }

    @Test func invalidTimeToEmptyIsNil() throws {
        let props: [String: Any] = ["ExternalConnected": false, "AvgTimeToEmpty": 65535]
        let readings = try #require(BatteryParser.parse(props))
        #expect(readings.timeToEmptyMin == nil)
    }

    @Test func emptyDictionaryIsNil() {
        #expect(BatteryParser.parse([:]) == nil)
    }
}
