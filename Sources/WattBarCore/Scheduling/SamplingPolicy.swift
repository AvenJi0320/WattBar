public enum Activity: Sendable, Equatable {
    case panelOpen, ambient, idle, suspended
}

public enum SamplingPolicy {
    public static func interval(for activity: Activity, panelInterval: Duration) -> Duration? {
        switch activity {
        case .panelOpen: panelInterval
        case .ambient: .seconds(5)
        case .idle, .suspended: nil
        }
    }
}
