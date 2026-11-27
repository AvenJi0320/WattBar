public enum Quality: Sendable, Equatable {
    case measured, contracted, allocated, derived, unavailable
}

public struct Metric: Sendable, Equatable {
    public var watts: Double?
    public var quality: Quality

    public init(watts: Double?, quality: Quality) {
        self.watts = watts
        self.quality = quality
    }

    public static let unavailable = Metric(watts: nil, quality: .unavailable)
}

public enum PowerState: Sendable, Equatable {
    case charging, pluggedIdle, pluggedDraining, onBattery, unsupported
}
