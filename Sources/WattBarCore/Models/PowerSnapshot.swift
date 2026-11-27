public struct ExternalDevice: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var watts: Double
    public var quality: Quality

    public init(id: String, name: String, watts: Double, quality: Quality) {
        self.id = id
        self.name = name
        self.watts = watts
        self.quality = quality
    }
}

public struct PowerSnapshot: Sendable, Equatable {
    public var state: PowerState
    public var total: Metric
    public var input: Metric
    public var adapterLoss: Metric
    public var charge: Metric
    public var discharge: Metric
    public var display: Metric
    public var external: Metric
    public var computer: Metric
    public var externalDevices: [ExternalDevice]
    public var batteryPercent: Int?
    public var timeToEmptyMin: Int?
    public var adapterWatts: Int?

    public init(
        state: PowerState,
        total: Metric,
        input: Metric,
        adapterLoss: Metric,
        charge: Metric,
        discharge: Metric,
        display: Metric,
        external: Metric,
        computer: Metric,
        externalDevices: [ExternalDevice] = [],
        batteryPercent: Int? = nil,
        timeToEmptyMin: Int? = nil,
        adapterWatts: Int? = nil
    ) {
        self.state = state
        self.total = total
        self.input = input
        self.adapterLoss = adapterLoss
        self.charge = charge
        self.discharge = discharge
        self.display = display
        self.external = external
        self.computer = computer
        self.externalDevices = externalDevices
        self.batteryPercent = batteryPercent
        self.timeToEmptyMin = timeToEmptyMin
        self.adapterWatts = adapterWatts
    }

    public static let unavailable = PowerSnapshot(
        state: .unsupported,
        total: .unavailable,
        input: .unavailable,
        adapterLoss: .unavailable,
        charge: .unavailable,
        discharge: .unavailable,
        display: .unavailable,
        external: .unavailable,
        computer: .unavailable
    )
}
