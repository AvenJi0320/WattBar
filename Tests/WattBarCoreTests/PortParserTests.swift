import Testing
@testable import WattBarCore

struct PortParserTests {
    @Test func fixturePorts() throws {
        let roots = try FixtureLoader.load("ports_ac_full")
        let ports = roots.compactMap { PortParser.parse($0) }
        #expect(ports.count >= 3)
        let first = try #require(ports.first { $0.portNumber == 1 })
        #expect(first.connectionActive)
        #expect(first.transports.contains("CC"))
        #expect(first.powerOutW == nil)
    }

    @Test func powerOutFromMilliwatts() throws {
        let props: [String: Any] = ["PortNumber": 1, "PowerOutDetails": ["PDPowermW": 15000]]
        #expect(try #require(PortParser.parse(props)).powerOutW == 15.0)
    }

    @Test func powerOutFromWatts() throws {
        let props: [String: Any] = ["PortNumber": 1, "PowerOutDetails": ["Watts": 12]]
        #expect(try #require(PortParser.parse(props)).powerOutW == 12.0)
    }

    @Test func powerOutFromVoltageAndCurrent() throws {
        let props: [String: Any] = ["PortNumber": 1, "PowerOutDetails": ["Voltage": 9000, "Current": 2000]]
        #expect(try #require(PortParser.parse(props)).powerOutW == 18.0)
    }

    @Test func powerOutDetailsAsArray() throws {
        let props: [String: Any] = [
            "PortNumber": 2,
            "PowerOutDetails": [["PDPowermW": 5000], ["PDPowermW": 10000]],
        ]
        #expect(try #require(PortParser.parse(props)).powerOutW == 15.0)
    }

    @Test func missingPowerOutIsNil() throws {
        let props: [String: Any] = ["PortNumber": 3]
        #expect(try #require(PortParser.parse(props)).powerOutW == nil)
    }

    @Test func missingPortNumberIsNil() {
        #expect(PortParser.parse([:]) == nil)
    }
}
