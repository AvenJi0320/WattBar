import Foundation
import IOKit
import WattBarCore

public final class USBDeviceCache: @unchecked Sendable {
    private let lock = NSLock()
    private var dirty = true
    private var cached: [USBDeviceReading] = []
    private var notificationPort: IONotificationPortRef?
    private var matchedIterator: io_iterator_t = 0
    private var terminatedIterator: io_iterator_t = 0
    private let queue = DispatchQueue(label: "wattbar.usb-cache", qos: .utility)

    public init() {
        start()
    }

    deinit {
        if matchedIterator != 0 { IOObjectRelease(matchedIterator) }
        if terminatedIterator != 0 { IOObjectRelease(terminatedIterator) }
        if let notificationPort { IONotificationPortDestroy(notificationPort) }
    }

    public func devices() -> [USBDeviceReading] {
        lock.lock()
        let needsRefresh = dirty
        dirty = false
        lock.unlock()

        if needsRefresh {
            let fresh = Self.scan()
            lock.lock()
            cached = fresh
            lock.unlock()
            return fresh
        }

        lock.lock()
        defer { lock.unlock() }
        return cached
    }

    fileprivate func handleNotification(_ iterator: io_iterator_t) {
        var service = IOIteratorNext(iterator)
        while service != 0 {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        lock.lock()
        dirty = true
        lock.unlock()
    }

    private func start() {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notificationPort = port
        IONotificationPortSetDispatchQueue(port, queue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        register(kIOFirstMatchNotification, port: port, context: context, iterator: &matchedIterator)
        register(kIOTerminatedNotification, port: port, context: context, iterator: &terminatedIterator)
    }

    private func register(
        _ notification: String,
        port: IONotificationPortRef,
        context: UnsafeMutableRawPointer,
        iterator: inout io_iterator_t
    ) {
        let result = IOServiceAddMatchingNotification(
            port, notification, IOServiceMatching("IOUSBHostDevice"),
            usbNotificationCallback, context, &iterator
        )
        if result == KERN_SUCCESS {
            handleNotification(iterator)
        }
    }

    private static func scan() -> [USBDeviceReading] {
        var result: [USBDeviceReading] = []
        Registry.forEachService(named: "IOUSBHostDevice") { service in
            guard let props = Registry.properties(service),
                  let reading = USBDeviceParser.parse(props, entryID: Registry.entryID(service))
            else { return }
            result.append(reading)
        }
        return result
    }
}

private let usbNotificationCallback: IOServiceMatchingCallback = { context, iterator in
    guard let context else { return }
    Unmanaged<USBDeviceCache>.fromOpaque(context).takeUnretainedValue().handleNotification(iterator)
}
