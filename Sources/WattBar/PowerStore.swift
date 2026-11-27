import Foundation
import Observation
import WattBarCore

@MainActor
@Observable
final class PowerStore {
    struct DisplayValues: Equatable {
        var primary: Double?
        var total: Double?
        var display: Double?
        var computer: Double?
        var external: Double?
    }

    private(set) var snapshot: PowerSnapshot = .unavailable
    private(set) var values = DisplayValues()
    private(set) var hasData = false

    @ObservationIgnored var onUpdate: (() -> Void)?
    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private let sampler = PowerSampler()
    @ObservationIgnored private let clock = ContinuousClock()
    @ObservationIgnored private var loopTask: Task<Void, Never>?
    @ObservationIgnored private var panelOpen = false
    @ObservationIgnored private var suspended = false
    @ObservationIgnored private var failures = 0
    @ObservationIgnored private var smoothers = Smoothers()

    private struct Smoothers {
        var primary = Smoother()
        var total = Smoother()
        var display = Smoother()
        var computer = Smoother()
        var external = Smoother()

        mutating func reset() {
            primary.reset()
            total.reset()
            display.reset()
            computer.reset()
            external.reset()
        }
    }

    init(settings: Settings) {
        self.settings = settings
    }

    var activity: Activity {
        if suspended { return .suspended }
        if panelOpen { return .panelOpen }
        return settings.showValueInMenuBar ? .ambient : .idle
    }

    func start() {
        refreshNow()
        restartLoop()
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    func setPanelOpen(_ open: Bool) {
        panelOpen = open
        if open { refreshNow() }
        restartLoop()
    }

    func setSuspended(_ value: Bool) {
        suspended = value
        if !value {
            smoothers.reset()
            refreshNow()
        }
        restartLoop()
    }

    func settingsChanged() {
        restartLoop()
    }

    func refreshNow() {
        Task { await sampleOnce() }
    }

    func loadPreview(snapshot: PowerSnapshot) {
        apply(snapshot)
    }

    private func restartLoop() {
        loopTask?.cancel()
        loopTask = nil
        let panelInterval = Duration.seconds(settings.panelIntervalSeconds)
        guard let interval = SamplingPolicy.interval(for: activity, panelInterval: panelInterval) else {
            return
        }
        loopTask = Task { [weak self, clock] in
            while !Task.isCancelled {
                try? await clock.sleep(for: interval, tolerance: interval / 10)
                guard !Task.isCancelled, let self else { return }
                await self.sampleOnce()
            }
        }
    }

    private func sampleOnce() async {
        let fresh = await sampler.sample()
        apply(fresh)
    }

    private func apply(_ fresh: PowerSnapshot) {
        if fresh.state != .unsupported, fresh.total.watts == nil {
            failures += 1
            if failures < 3, hasData { return }
        } else {
            failures = 0
        }

        let primaryRaw: Double?
        switch fresh.state {
        case .charging: primaryRaw = fresh.charge.watts
        case .pluggedIdle: primaryRaw = 0
        case .pluggedDraining, .onBattery: primaryRaw = fresh.discharge.watts
        case .unsupported: primaryRaw = nil
        }

        let candidate = DisplayValues(
            primary: smoothers.primary.push(primaryRaw),
            total: smoothers.total.push(fresh.total.watts),
            display: smoothers.display.push(fresh.display.watts),
            computer: smoothers.computer.push(fresh.computer.watts),
            external: smoothers.external.push(fresh.external.watts)
        )

        if fresh != snapshot { snapshot = fresh }
        if Self.differs(candidate, values) { values = candidate }
        hasData = true
        onUpdate?()
    }

    private static func differs(_ lhs: DisplayValues, _ rhs: DisplayValues) -> Bool {
        func moved(_ a: Double?, _ b: Double?) -> Bool {
            switch (a, b) {
            case (nil, nil): false
            case let (a?, b?): abs(a - b) >= 0.05
            default: true
            }
        }
        return moved(lhs.primary, rhs.primary) || moved(lhs.total, rhs.total)
            || moved(lhs.display, rhs.display) || moved(lhs.computer, rhs.computer)
            || moved(lhs.external, rhs.external)
    }
}
