import AppKit
@preconcurrency import CoreGraphics
@preconcurrency import CoreFoundation

extension CGEventType {
    static let magnify = CGEventType(rawValue: 29)!
}

private let kMagnifyEventMask = CGEventMask(1 << CGEventType.magnify.rawValue)

final class GestureMonitor: @unchecked Sendable {
    var onGestureDetected: ((GestureType) -> Void)?
    /// Called synchronously from the event tap background thread at gesture start.
    /// Return true to consume the gesture (suppress native zoom); false to pass through.
    var shouldHandleGesture: (() -> Bool)?

    private var eventTap: CFMachPort?
    private var tapRunLoop: CFRunLoop?
    // Accessed only from the event tap callback thread.
    private var accumulatedMagnification: Double = 0
    private var isHandlingCurrentGesture: Bool = false

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
        print("[GestureMonitor] started on background thread (cghidEventTap, defaultTap)")
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

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passRetained(event) }
        let monitor = Unmanaged<GestureMonitor>.fromOpaque(userInfo).takeUnretainedValue()

        // コールバックが遅い等で OS にタップを無効化された場合は、特殊イベントが届く。
        // 再有効化しないとジェスチャーが以降ずっと無反応になるため、ここで復帰させる。
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = monitor.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // cghidEventTap は magnify 以外の内部イベント（type 0xFFFFFFFF 等）も届くことがある。
        // NSEvent(cgEvent:) に未知の type を渡すと NSInternalInconsistencyException が発生するため、
        // CGEvent レベルで先にフィルタする。
        guard type == .magnify else { return Unmanaged.passRetained(event) }

        guard let nsEvent = NSEvent(cgEvent: event),
              nsEvent.type == .magnify else {
            return Unmanaged.passRetained(event)
        }

        let phase = nsEvent.phase

        if phase.contains(.began) {
            monitor.isHandlingCurrentGesture = monitor.shouldHandleGesture?() ?? false
            monitor.accumulatedMagnification = 0
        }

        guard monitor.isHandlingCurrentGesture else {
            return Unmanaged.passRetained(event)
        }

        let mag = nsEvent.magnification
        switch phase {
        case .changed:
            monitor.accumulatedMagnification += mag
        case .ended:
            monitor.accumulatedMagnification += mag
            let total = monitor.accumulatedMagnification
            monitor.accumulatedMagnification = 0
            monitor.isHandlingCurrentGesture = false
            if let gesture = GestureRecognizer.recognize(magnitude: total) {
                DispatchQueue.main.async {
                    monitor.onGestureDetected?(gesture)
                }
            }
        case .cancelled:
            monitor.accumulatedMagnification = 0
            monitor.isHandlingCurrentGesture = false
        default:
            break
        }

        return nil  // consume event
    }

    deinit {
        stopMonitoring()
    }
}
