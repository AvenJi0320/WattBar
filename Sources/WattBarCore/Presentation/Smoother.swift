public struct Smoother: Sendable {
    private let alpha: Double
    private var last: Double?

    public init(alpha: Double = 0.35) {
        self.alpha = alpha
    }

    public mutating func push(_ value: Double?) -> Double? {
        guard let value else { return last }
        if let previous = last {
            last = alpha * value + (1 - alpha) * previous
        } else {
            last = value
        }
        return last
    }

    public mutating func reset() {
        last = nil
    }
}
