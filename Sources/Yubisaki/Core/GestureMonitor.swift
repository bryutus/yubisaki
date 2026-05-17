import AppKit
@preconcurrency import CoreGraphics
@preconcurrency import CoreFoundation

extension CGEventType {
    static let magnify = CGEventType(rawValue: 29)!
}

private let kMagnifyEventMask = CGEventMask(1 << CGEventType.magnify.rawValue)

final class GestureMonitor: @unchecked Sendable {
    var onGestureDetected: ((GestureType) -> Void)?

    private var eventTap: CFMachPort?
    private var tapRunLoop: CFRunLoop?
    private var accumulatedMagnification: Double = 0

    func startMonitoring() {
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: kMagnifyEventMask,
            callback: Self.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[GestureMonitor] Failed to create event tap. Check Accessibility permission.")
            return
        }

        eventTap = tap

        let thread = Thread {
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            let rl = CFRunLoopGetCurrent()
            CFRunLoopAddSource(rl, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            self.tapRunLoop = rl
            CFRunLoopRun()
        }
        thread.name = "GestureMonitor"
        thread.start()
        print("[GestureMonitor] started on background thread (cghidEventTap, listenOnly)")
    }

    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let rl = tapRunLoop {
            CFRunLoopStop(rl)
        }
        eventTap = nil
        tapRunLoop = nil
    }

    // CGEvent を @unchecked Sendable でラップしてスレッド間で渡す
    private struct CGEventWrapper: @unchecked Sendable {
        let event: CGEvent
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passRetained(event) }
        let monitor = Unmanaged<GestureMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        let wrapper = CGEventWrapper(event: event)
        DispatchQueue.main.async {
            guard let nsEvent = NSEvent(cgEvent: wrapper.event) else { return }
            monitor.handleEvent(nsEvent: nsEvent)
        }
        return Unmanaged.passRetained(event)
    }

    private func handleEvent(nsEvent: NSEvent) {
        guard nsEvent.type == .magnify else { return }
        switch nsEvent.phase {
        case .began:
            accumulatedMagnification = 0
        case .changed:
            accumulatedMagnification += nsEvent.magnification
        case .ended:
            accumulatedMagnification += nsEvent.magnification
            let total = accumulatedMagnification
            accumulatedMagnification = 0
            if let gesture = GestureRecognizer.recognize(magnitude: total) {
                onGestureDetected?(gesture)
            }
        case .cancelled:
            accumulatedMagnification = 0
        default:
            break
        }
    }

    deinit {
        stopMonitoring()
    }
}
