import Foundation
import WattBarCore
import WattBarSystem

let arguments = Array(CommandLine.arguments.dropFirst())

func watts(_ metric: Metric) -> String {
    PowerFormatter.text(metric)
}

func describe(_ raw: RawReadings, _ snapshot: PowerSnapshot) -> String {
    var lines: [String] = []
    let smc = raw.smc
    lines.append("SMC     PSTR=\(smc?.systemTotalW.map { String(format: "%.2f", $0) } ?? "nil")"
        + " PDTR=\(smc?.dcInW.map { String(format: "%.2f", $0) } ?? "nil")"
        + " PDBR=\(smc?.backlightW.map { String(format: "%.2f", $0) } ?? "nil")"
        + " PPBR=\(smc?.batteryRailW.map { String(format: "%.2f", $0) } ?? "nil")")
    if let battery = raw.battery {
        lines.append("BATT    ext=\(battery.externalConnected) charging=\(battery.isCharging)"
            + " full=\(battery.fullyCharged) V=\(battery.voltageMV.map(String.init) ?? "nil")mV"
            + " I=\(battery.amperageMA.map(String.init) ?? "nil")mA"
            + " pct=\(battery.percent.map(String.init) ?? "nil")"
            + " load=\(battery.telemetry?.systemLoadMW.map(String.init) ?? "nil")mW"
            + " adapter=\(battery.adapterWatts.map(String.init) ?? "nil")W")
    } else {
        lines.append("BATT    nil")
    }
    for port in raw.ports {
        lines.append("PORT    #\(port.portNumber) active=\(port.connectionActive)"
            + " out=\(port.powerOutW.map { String(format: "%.2f", $0) } ?? "nil")W"
            + " transports=\(port.transports.joined(separator: ","))")
    }
    for device in raw.usbDevices where device.allocationMA > 0 {
        lines.append("USB     \(device.name) \(device.allocationMA)mA builtIn=\(device.isBuiltIn)")
    }
    lines.append("STATE   \(snapshot.state)")
    lines.append("TOTAL   \(watts(snapshot.total))  INPUT \(watts(snapshot.input))  LOSS \(watts(snapshot.adapterLoss))")
    lines.append("CHARGE  \(watts(snapshot.charge))  DISCHARGE \(watts(snapshot.discharge))")
    lines.append("DISPLAY \(watts(snapshot.display))  COMPUTER \(watts(snapshot.computer))"
        + "  EXTERNAL \(watts(snapshot.external))")
    return lines.joined(separator: "\n")
}

func jsonObject(_ snapshot: PowerSnapshot) -> [String: Any] {
    func value(_ metric: Metric) -> Any { metric.watts ?? NSNull() }
    return [
        "state": "\(snapshot.state)",
        "totalW": value(snapshot.total),
        "inputW": value(snapshot.input),
        "adapterLossW": value(snapshot.adapterLoss),
        "chargeW": value(snapshot.charge),
        "dischargeW": value(snapshot.discharge),
        "displayW": value(snapshot.display),
        "externalW": value(snapshot.external),
        "externalQuality": "\(snapshot.external.quality)",
        "computerW": value(snapshot.computer),
        "externalDevices": snapshot.externalDevices.map {
            ["name": $0.name, "watts": $0.watts, "quality": "\($0.quality)"]
        },
    ]
}

func smcDump(prefix: String) {
    guard let smc = SMCClient() else {
        print("SMC open failed (needs to run outside the Codex sandbox)")
        exit(1)
    }
    for key in smc.allKeys() where key.hasPrefix(prefix) {
        if let value = smc.readDouble(key), value != 0 {
            print("\(key) \(String(format: "%.3f", value))")
        }
    }
}

func bench(count: Int) {
    let reader = SystemPowerReader()
    _ = reader.read()
    let clock = ContinuousClock()
    var samples: [Double] = []
    samples.reserveCapacity(count)
    for _ in 0..<count {
        let start = clock.now
        let raw = reader.read()
        _ = PowerDeriver.derive(raw)
        let elapsed = clock.now - start
        samples.append(Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000)
    }
    samples.sort()
    let average = samples.reduce(0, +) / Double(samples.count)
    let p99 = samples[min(samples.count - 1, Int(Double(samples.count) * 0.99))]
    print(String(format: "read+derive x%d  avg %.3f ms  p99 %.3f ms", count, average, p99))
}

func run() {
    if let index = arguments.firstIndex(of: "--smc-dump") {
        let prefix = index + 1 < arguments.count ? arguments[index + 1] : "P"
        smcDump(prefix: prefix)
        return
    }
    if let index = arguments.firstIndex(of: "--bench") {
        let count = index + 1 < arguments.count ? Int(arguments[index + 1]) ?? 1000 : 1000
        bench(count: count)
        return
    }

    let reader = SystemPowerReader()
    if reader.smc == nil {
        FileHandle.standardError.write(Data("warning: SMC unavailable, using AppleSmartBattery fallback only\n".utf8))
    }
    let once = arguments.contains("--once")
    let asJSON = arguments.contains("--json")
    repeat {
        let raw = reader.read()
        let snapshot = PowerDeriver.derive(raw)
        if asJSON {
            let data = try? JSONSerialization.data(
                withJSONObject: jsonObject(snapshot), options: [.sortedKeys])
            print(data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}")
        } else {
            print(describe(raw, snapshot))
            print("")
        }
        if once { break }
        Thread.sleep(forTimeInterval: 1)
    } while true
}

run()
