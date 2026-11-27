import Testing
@testable import WattBarCore

struct PowerFormatterTests {
    @Test func belowThresholdIsZero() {
        #expect(PowerFormatter.text(Metric(watts: 0.04, quality: .measured)) == "0 W")
    }

    @Test func oneDecimalBelowHundred() {
        #expect(PowerFormatter.text(Metric(watts: 12.345, quality: .measured)) == "12.3 W")
    }

    @Test func integerAtOrAboveHundred() {
        #expect(PowerFormatter.text(Metric(watts: 112.4, quality: .derived)) == "112 W")
    }

    @Test func allocatedHasApproxPrefixAndTag() {
        let metric = Metric(watts: 3.25, quality: .allocated)
        #expect(PowerFormatter.text(metric) == "≈ 3.3 W")
        #expect(PowerFormatter.tag(.allocated) == "分配")
        #expect(PowerFormatter.tag(.contracted) == "协商")
        #expect(PowerFormatter.tag(.measured) == nil)
    }

    @Test func unavailableIsDash() {
        #expect(PowerFormatter.text(.unavailable) == "—")
    }
}
