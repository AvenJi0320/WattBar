import Foundation

public enum PowerDeriver {
    public static func derive(
        _ raw: RawReadings,
        external: any ExternalPowerStrategy = LayeredExternalPowerStrategy()
    ) -> PowerSnapshot {
        let battery = raw.battery
        let telemetry = battery?.telemetry
        let connected = battery?.externalConnected ?? false
        let state = PowerState(battery: battery)

        let batteryPowerW = batteryPower(battery)

        let total: Metric
        if let value = valid(raw.smc?.systemTotalW) {
            total = Metric(watts: value, quality: .measured)
        } else if let value = valid(telemetry?.systemLoadMW.map { Double($0) / 1000 }) {
            total = Metric(watts: value, quality: .measured)
        } else if !connected, let value = valid(batteryPowerW.map { abs($0) }) {
            total = Metric(watts: value, quality: .measured)
        } else {
            total = .unavailable
        }

        let input: Metric
        if battery != nil, !connected {
            input = Metric(watts: 0, quality: .measured)
        } else if let value = valid(raw.smc?.dcInW) {
            input = Metric(watts: value, quality: .measured)
        } else if let value = valid(telemetry?.systemPowerInMW.map { Double($0) / 1000 }) {
            input = Metric(watts: value, quality: .measured)
        } else {
            input = .unavailable
        }

        let adapterLoss: Metric
        if let value = valid(telemetry?.adapterLossMW.map { Double($0) / 1000 }) {
            adapterLoss = Metric(watts: value, quality: .measured)
        } else {
            adapterLoss = .unavailable
        }

        var charge = Metric.unavailable
        var discharge = Metric.unavailable
        if let battery {
            let amperage = battery.amperageMA
            if let batteryPowerW, let amperage {
                charge = Metric(watts: amperage > 0 ? batteryPowerW : 0, quality: .measured)
                discharge = Metric(watts: amperage < 0 ? abs(batteryPowerW) : 0, quality: .measured)
            } else if let milliwatts = telemetry?.batteryPowerMW, let value = valid(Double(milliwatts) / 1000) {
                charge = Metric(watts: max(0, value), quality: .measured)
                discharge = Metric(watts: 0, quality: .measured)
            } else {
                charge = Metric(watts: 0, quality: .measured)
                discharge = Metric(watts: 0, quality: .measured)
            }
        }

        let display: Metric
        if let value = valid(raw.smc?.backlightW) {
            display = Metric(watts: value, quality: .measured)
        } else {
            display = .unavailable
        }

        let (externalMetric, devices) = external.evaluate(ports: raw.ports, devices: raw.usbDevices)

        let computer: Metric
        if let totalW = total.watts {
            let rest = totalW - (display.watts ?? 0) - (externalMetric.watts ?? 0)
            computer = Metric(watts: max(0, rest), quality: .derived)
        } else {
            computer = .unavailable
        }

        return PowerSnapshot(
            state: state,
            total: total,
            input: input,
            adapterLoss: adapterLoss,
            charge: charge,
            discharge: discharge,
            display: display,
            external: externalMetric,
            computer: computer,
            externalDevices: devices,
            batteryPercent: battery?.percent,
            timeToEmptyMin: battery?.timeToEmptyMin,
            adapterWatts: battery?.adapterWatts
        )
    }

    static func valid(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= -0.5, value <= 500 else { return nil }
        return max(0, value)
    }

    private static func batteryPower(_ battery: BatteryReadings?) -> Double? {
        guard let battery, let voltage = battery.voltageMV, let amperage = battery.amperageMA else {
            return nil
        }
        return Double(voltage) * Double(amperage) / 1_000_000
    }
}
