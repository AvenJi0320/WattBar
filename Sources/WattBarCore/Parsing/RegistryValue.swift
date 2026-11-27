import Foundation

public enum RegistryValue {
    public static func int(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        let wide = number.int64Value
        if wide > Int64(Int32.max) || wide < Int64(Int32.min) {
            return Int(Int32(truncatingIfNeeded: wide))
        }
        return Int(wide)
    }

    public static func bool(_ value: Any?) -> Bool? {
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        return nil
    }

    public static func string(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let data = value as? Data {
            var bytes = [UInt8](data)
            while bytes.last == 0 { bytes.removeLast() }
            return String(decoding: bytes, as: UTF8.self)
        }
        return nil
    }

    public static func dict(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }
}
