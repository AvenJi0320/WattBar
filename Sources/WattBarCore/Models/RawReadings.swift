public struct SMCPowerReadings: Sendable, Equatable {
    public var systemTotalW: Double?
    public var dcInW: Double?
    public var backlightW: Double?
    public var batteryRailW: Double?

    public init(
        systemTotalW: Double? = nil,
        dcInW: Double? = nil,
        backlightW: Double? = nil,
        batteryRailW: Double? = nil
    ) {
        self.systemTotalW = systemTotalW
        self.dcInW = dcInW
        self.backlightW = backlightW
        self.batteryRailW = batteryRailW
    }
}

public struct BatteryTelemetry: Sendable, Equatable {
    public var systemLoadMW: Int?
    public var systemPowerInMW: Int?
    public var batteryPowerMW: Int?
    public var adapterLossMW: Int?

    public init(
        systemLoadMW: Int? = nil,
        systemPowerInMW: Int? = nil,
        batteryPowerMW: Int? = nil,
        adapterLossMW: Int? = nil
    ) {
        self.systemLoadMW = systemLoadMW
        self.systemPowerInMW = systemPowerInMW
        self.batteryPowerMW = batteryPowerMW
        self.adapterLossMW = adapterLossMW
    }
}

public struct BatteryReadings: Sendable, Equatable {
    public var externalConnected: Bool
    public var isCharging: Bool
    public var fullyCharged: Bool
    public var voltageMV: Int?
    public var amperageMA: Int?
    public var percent: Int?
    public var timeToEmptyMin: Int?
    public var adapterWatts: Int?
    public var adapterVoltageMV: Int?
    public var adapterCurrentMA: Int?
    public var telemetry: BatteryTelemetry?
    public var notChargingReason: Int?

    public init(
        externalConnected: Bool,
        isCharging: Bool = false,
        fullyCharged: Bool = false,
        voltageMV: Int? = nil,
        amperageMA: Int? = nil,
        percent: Int? = nil,
        timeToEmptyMin: Int? = nil,
        adapterWatts: Int? = nil,
        adapterVoltageMV: Int? = nil,
        adapterCurrentMA: Int? = nil,
        telemetry: BatteryTelemetry? = nil,
        notChargingReason: Int? = nil
    ) {
        self.externalConnected = externalConnected
        self.isCharging = isCharging
        self.fullyCharged = fullyCharged
        self.voltageMV = voltageMV
        self.amperageMA = amperageMA
        self.percent = percent
        self.timeToEmptyMin = timeToEmptyMin
        self.adapterWatts = adapterWatts
        self.adapterVoltageMV = adapterVoltageMV
        self.adapterCurrentMA = adapterCurrentMA
        self.telemetry = telemetry
        self.notChargingReason = notChargingReason
    }
}

public struct PortReading: Sendable, Equatable {
    public var portNumber: Int
    public var connectionActive: Bool
    public var transports: [String]
    public var powerOutW: Double?

    public init(
        portNumber: Int,
        connectionActive: Bool = false,
        transports: [String] = [],
        powerOutW: Double? = nil
    ) {
        self.portNumber = portNumber
        self.connectionActive = connectionActive
        self.transports = transports
        self.powerOutW = powerOutW
    }
}

public struct USBDeviceReading: Sendable, Equatable, Identifiable {
    public var id: UInt64
    public var name: String
    public var allocationMA: Int
    public var isBuiltIn: Bool

    public init(id: UInt64, name: String, allocationMA: Int, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.allocationMA = allocationMA
        self.isBuiltIn = isBuiltIn
    }
}

public struct RawReadings: Sendable, Equatable {
    public var smc: SMCPowerReadings?
    public var battery: BatteryReadings?
    public var ports: [PortReading]
    public var usbDevices: [USBDeviceReading]

    public init(
        smc: SMCPowerReadings? = nil,
        battery: BatteryReadings? = nil,
        ports: [PortReading] = [],
        usbDevices: [USBDeviceReading] = []
    ) {
        self.smc = smc
        self.battery = battery
        self.ports = ports
        self.usbDevices = usbDevices
    }
}
