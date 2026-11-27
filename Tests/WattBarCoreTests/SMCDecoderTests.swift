import Testing
@testable import WattBarCore

struct SMCDecoderTests {
    @Test func floatLittleEndian() {
        #expect(SMCDecoder.decode(type: "flt ", bytes: [0x00, 0x00, 0x05, 0x41]) == 8.3125)
    }

    @Test func unsigned16() {
        #expect(SMCDecoder.decode(type: "ui16", bytes: [0x01, 0x00]) == 256)
    }

    @Test func fixedPointSp78() {
        #expect(SMCDecoder.decode(type: "sp78", bytes: [0x1E, 0x80]) == 30.5)
    }

    @Test func fixedPointFpe2() {
        #expect(SMCDecoder.decode(type: "fpe2", bytes: [0x00, 0x0A]) == 2.5)
    }

    @Test func unknownTypeIsNil() {
        #expect(SMCDecoder.decode(type: "zzzz", bytes: [1, 2, 3, 4]) == nil)
    }

    @Test func shortBytesIsNil() {
        #expect(SMCDecoder.decode(type: "flt ", bytes: [0x00, 0x00]) == nil)
    }
}
