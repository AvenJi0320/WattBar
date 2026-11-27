import Testing
@testable import WattBarCore

struct USBDeviceParserTests {
    @Test func fixtureContainsLanAdapter() throws {
        let nodes = FixtureLoader.flatten(try FixtureLoader.load("usb_ac_full"))
        let readings = nodes.compactMap { USBDeviceParser.parse($0, entryID: 1) }
        let lan = try #require(readings.first { $0.name == "USB 10_100_1000 LAN" })
        #expect(lan.allocationMA == 350)
        #expect(!lan.isBuiltIn)
    }

    @Test func allocationIsParsed() throws {
        let props: [String: Any] = ["USB Product Name": "Dev", "UsbPowerSinkAllocation": 350]
        let reading = try #require(USBDeviceParser.parse(props, entryID: 7))
        #expect(reading.allocationMA == 350)
        #expect(reading.id == 7)
    }

    @Test func builtInFlag() throws {
        let props: [String: Any] = ["USB Product Name": "Cam", "Built-In": true]
        let reading = try #require(USBDeviceParser.parse(props, entryID: 1))
        #expect(reading.isBuiltIn)
    }

    @Test func nonRemovableFlag() throws {
        let props: [String: Any] = ["USB Product Name": "Kbd", "non-removable": "yes"]
        let reading = try #require(USBDeviceParser.parse(props, entryID: 1))
        #expect(reading.isBuiltIn)
    }

    @Test func namePriority() throws {
        let both: [String: Any] = ["USB Product Name": "A", "kUSBProductString": "B"]
        #expect(USBDeviceParser.parse(both, entryID: 1)?.name == "A")
        let second: [String: Any] = ["kUSBProductString": "B", "UsbPowerSinkAllocation": 100]
        #expect(USBDeviceParser.parse(second, entryID: 1)?.name == "B")
        let none: [String: Any] = ["UsbPowerSinkAllocation": 100]
        #expect(USBDeviceParser.parse(none, entryID: 1)?.name == "未知设备")
    }
}
