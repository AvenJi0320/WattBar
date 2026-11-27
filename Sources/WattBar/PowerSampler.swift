import WattBarCore
import WattBarSystem

actor PowerSampler {
    private let reader = SystemPowerReader()

    func sample() -> PowerSnapshot {
        PowerDeriver.derive(reader.read())
    }
}
