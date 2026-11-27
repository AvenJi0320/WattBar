extension PowerState {
    public init(battery: BatteryReadings?) {
        guard let battery else {
            self = .unsupported
            return
        }
        guard battery.externalConnected else {
            self = .onBattery
            return
        }
        let amperage = battery.amperageMA ?? 0
        if amperage > 0 {
            self = .charging
        } else if battery.fullyCharged || amperage == 0 {
            self = .pluggedIdle
        } else {
            self = .pluggedDraining
        }
    }
}
