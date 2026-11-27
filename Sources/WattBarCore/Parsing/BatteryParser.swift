import Foundation

public enum BatteryParser {
    public static func parse(_ props: [String: Any]) -> BatteryReadings? {
        guard let external = RegistryValue.bool(props["ExternalConnected"]) else { return nil }

        let adapter = RegistryValue.dict(props["AdapterDetails"])
        let charger = RegistryValue.dict(props["ChargerData"])

        var telemetry: BatteryTelemetry?
        if let raw = RegistryValue.dict(props["PowerTelemetryData"]) {
            telemetry = BatteryTelemetry(
                systemLoadMW: RegistryValue.int(raw["SystemLoad"]),
                systemPowerInMW: RegistryValue.int(raw["SystemPowerIn"]),
                batteryPowerMW: RegistryValue.int(raw["BatteryPower"]),
                adapterLossMW: RegistryValue.int(raw["AdapterEfficiencyLoss"])
            )
        }

        var timeToEmpty = RegistryValue.int(props["AvgTimeToEmpty"])
        if timeToEmpty == 65535 || timeToEmpty == -1 { timeToEmpty = nil }

        return BatteryReadings(
            externalConnected: external,
            isCharging: RegistryValue.bool(props["IsCharging"]) ?? false,
            fullyCharged: RegistryValue.bool(props["FullyCharged"]) ?? false,
            voltageMV: RegistryValue.int(props["Voltage"]),
            amperageMA: RegistryValue.int(props["InstantAmperage"]) ?? RegistryValue.int(props["Amperage"]),
            percent: RegistryValue.int(props["CurrentCapacity"]),
            timeToEmptyMin: timeToEmpty,
            adapterWatts: RegistryValue.int(adapter?["Watts"]),
            adapterVoltageMV: RegistryValue.int(adapter?["AdapterVoltage"]),
            adapterCurrentMA: RegistryValue.int(adapter?["Current"]),
            telemetry: telemetry,
            notChargingReason: RegistryValue.int(charger?["NotChargingReason"])
        )
    }
}
