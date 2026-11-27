import Foundation

public enum PowerFormatter {
    public static func text(_ metric: Metric) -> String {
        guard metric.quality != .unavailable, let watts = metric.watts else { return "—" }
        let prefix = (metric.quality == .contracted || metric.quality == .allocated) ? "≈ " : ""
        if watts < 0.05 { return prefix + "0 W" }
        if watts < 100 {
            let rounded = (watts * 10).rounded() / 10
            return prefix + String(format: "%.1f W", rounded)
        }
        return prefix + String(format: "%.0f W", watts.rounded())
    }

    public static func tag(_ quality: Quality) -> String? {
        switch quality {
        case .contracted: "协商"
        case .allocated: "分配"
        default: nil
        }
    }
}
