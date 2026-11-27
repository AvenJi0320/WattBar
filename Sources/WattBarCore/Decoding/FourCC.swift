public enum FourCC {
    public static func code(_ text: String) -> UInt32 {
        var value: UInt32 = 0
        var count = 0
        for byte in text.utf8.prefix(4) {
            value = (value << 8) | UInt32(byte)
            count += 1
        }
        while count < 4 {
            value = (value << 8) | 0x20
            count += 1
        }
        return value
    }

    public static func string(_ code: UInt32) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF),
        ]
        return String(decoding: bytes, as: UTF8.self)
    }
}
