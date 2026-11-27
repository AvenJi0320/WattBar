public enum SMCDecoder {
    public static func decode(type: String, bytes: [UInt8]) -> Double? {
        switch type {
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0])
                | (UInt32(bytes[1]) << 8)
                | (UInt32(bytes[2]) << 16)
                | (UInt32(bytes[3]) << 24)
            return Double(Float(bitPattern: bits))
        case "ui8 ":
            guard bytes.count >= 1 else { return nil }
            return Double(bytes[0])
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(bigEndianUnsigned(bytes, count: 2))
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            return Double(bigEndianUnsigned(bytes, count: 4))
        case "si16":
            guard bytes.count >= 2 else { return nil }
            return Double(Int16(truncatingIfNeeded: bigEndianUnsigned(bytes, count: 2)))
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            return Double(Int16(truncatingIfNeeded: bigEndianUnsigned(bytes, count: 2))) / 256
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            return Double(bigEndianUnsigned(bytes, count: 2)) / 4
        default:
            return nil
        }
    }

    private static func bigEndianUnsigned(_ bytes: [UInt8], count: Int) -> UInt64 {
        var value: UInt64 = 0
        for index in 0..<count {
            value = (value << 8) | UInt64(bytes[index])
        }
        return value
    }
}
