import AppKit
import CoreGraphics

extension CGEventType {
    static let magnify = CGEventType(rawValue: 29)!
}

private let kMagnifyEventMask = CGEventMask(1 << CGEventType.magnify.rawValue)

final class GestureMonitor: @unchecked Sendable {
    var onGestureDetected: ((GestureType) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var accumulatedMagnification: Double = 0

    func startMonitoring() {
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: kMagnifyEventMask,
            callback: Self.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[GestureMonitor] Failed to create event tap. Check Accessibility permission.")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        print("[GestureMonitor] Event tap created successfully")
    }

    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passRetained(event) }
        let monitor = Unmanaged<GestureMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        monitor.handleEvent(type: type, event: event)
        return Unmanaged.passRetained(event)
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        guard type == .magnify, let nsEvent = NSEvent(cgEvent: event) else { return }

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
