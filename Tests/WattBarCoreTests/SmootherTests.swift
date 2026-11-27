import Testing
@testable import WattBarCore

struct SmootherTests {
    @Test func firstValuePassesThrough() {
        var smoother = Smoother()
        #expect(smoother.push(10) == 10)
    }

    @Test func exponentialAverage() {
        var smoother = Smoother(alpha: 0.35)
        _ = smoother.push(10)
        let value = smoother.push(20)
        #expect(abs((value ?? .nan) - 13.5) < 0.001)
    }

    @Test func nilKeepsLastValue() {
        var smoother = Smoother()
        _ = smoother.push(10)
        #expect(smoother.push(nil) == 10)
    }

    @Test func resetRestartsFromFirstValue() {
        var smoother = Smoother()
        _ = smoother.push(10)
        smoother.reset()
        #expect(smoother.push(50) == 50)
        #expect(smoother.push(nil) == 50)
    }

    @Test func nilBeforeAnyValueIsNil() {
        var smoother = Smoother()
        #expect(smoother.push(nil) == nil)
    }
}
