import CSMC
import Foundation
import IOKit
import WattBarCore

public final class SMCClient: @unchecked Sendable {
    private var connection: io_connect_t = 0
    private var infoCache: [UInt32: SMCKeyInfoData] = [:]
    private var missingKeys: Set<UInt32> = []

    public init?() {
        var opened: io_connect_t = 0
        guard csmc_open(&opened) == KERN_SUCCESS else { return nil }
        connection = opened
    }

    deinit {
        close()
    }

    public func close() {
        guard connection != 0 else { return }
        csmc_close(connection)
        connection = 0
    }

    public func readDouble(_ key: String) -> Double? {
        guard connection != 0 else { return nil }
        let code = FourCC.code(key)
        if missingKeys.contains(code) { return nil }

        let info: SMCKeyInfoData
        if let cached = infoCache[code] {
            info = cached
        } else {
            var fetched = SMCKeyInfoData()
            guard csmc_key_info(connection, code, &fetched) == KERN_SUCCESS else {
                missingKeys.insert(code)
                return nil
            }
            infoCache[code] = fetched
            info = fetched
        }

        var buffer = [UInt8](repeating: 0, count: 32)
        guard csmc_read(connection, code, info, &buffer) == KERN_SUCCESS else { return nil }
        let size = min(Int(info.dataSize), buffer.count)
        return SMCDecoder.decode(type: FourCC.string(info.dataType), bytes: Array(buffer.prefix(size)))
    }

    public func allKeys() -> [String] {
        guard let count = readDouble("#KEY") else { return [] }
        var keys: [String] = []
        for index in 0..<UInt32(count) {
            var code: UInt32 = 0
            if csmc_key_at_index(connection, index, &code) == KERN_SUCCESS {
                keys.append(FourCC.string(code))
            }
        }
        return keys
    }
}
