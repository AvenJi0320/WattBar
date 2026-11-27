import Foundation
import IOKit.ps

@MainActor
public final class PowerSourceObserver {
    private var source: CFRunLoopSource?
    private var handler: (@MainActor () -> Void)?

    public init() {}

    public func start(_ handler: @escaping @MainActor () -> Void) {
        stop()
        self.handler = handler
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let observer = Unmanaged<PowerSourceObserver>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                observer.handler?()
            }
        }
        guard let created = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else {
            return
        }
        source = created
        CFRunLoopAddSource(CFRunLoopGetMain(), created, .commonModes)
    }

    public func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            self.source = nil
        }
        handler = nil
    }
}
