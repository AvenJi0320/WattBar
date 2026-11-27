import Testing
@testable import WattBarCore

struct FourCCTests {
    @Test func roundTripPlainKey() {
        #expect(FourCC.string(FourCC.code("PSTR")) == "PSTR")
    }

    @Test func preservesTrailingSpace() {
        #expect(FourCC.string(FourCC.code("flt ")) == "flt ")
    }

    @Test func knownCodeValue() {
        #expect(FourCC.code("PSTR") == 0x5053_5452)
    }
}
