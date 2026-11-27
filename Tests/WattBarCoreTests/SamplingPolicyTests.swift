import Testing
@testable import WattBarCore

struct SamplingPolicyTests {
    @Test func panelOpenUsesUserInterval() {
        #expect(SamplingPolicy.interval(for: .panelOpen, panelInterval: .seconds(2)) == .seconds(2))
    }

    @Test func ambientIsFiveSeconds() {
        #expect(SamplingPolicy.interval(for: .ambient, panelInterval: .seconds(1)) == .seconds(5))
    }

    @Test func idleAndSuspendedDoNotPoll() {
        #expect(SamplingPolicy.interval(for: .idle, panelInterval: .seconds(1)) == nil)
        #expect(SamplingPolicy.interval(for: .suspended, panelInterval: .seconds(1)) == nil)
    }
}
