public enum IconState: Sendable, Equatable {
    case charging, plugged, battery, unavailable

    public init(_ state: PowerState) {
        switch state {
        case .charging: self = .charging
        case .pluggedIdle, .pluggedDraining: self = .plugged
        case .onBattery: self = .battery
        case .unsupported: self = .unavailable
        }
    }
}
