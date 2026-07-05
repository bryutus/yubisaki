import AppKit
import os
@preconcurrency import CoreGraphics
@preconcurrency import CoreFoundation

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "yubisaki", category: "GestureMonitor")

extension CGEventType {
    static let magnify = CGEventType(rawValue: 29)!
    /// 4本指タップなどの汎用ジェスチャーイベント
    static let gesture = CGEventType(rawValue: 30)!
}

private let kGestureEventMask =
    CGEventMask(1 << CGEventType.magnify.rawValue) |
    CGEventMask(1 << CGEventType.gesture.rawValue)

/// CGEvent をタップコールバックスレッドからメインスレッドへ運ぶためのラッパー
private struct UncheckedSendableCGEvent: @unchecked Sendable { let event: CGEvent }

final class GestureMonitor: @unchecked Sendable {
    var onGestureDetected: ((GestureType) -> Void)?
    /// Called synchronously from the event tap background thread at gesture start.
    /// Return true to consume the gesture (suppress native zoom); false to pass through.
    var shouldHandleGesture: (() -> Bool)?

    private var eventTap: CFMachPort?
    private var tapRunLoop: CFRunLoop?
    /// チップタップ検出の状態機械（メインスレッドからのみ触る）
    private let tipTapRecognizer = TipTapRecognizer()
    /// ピンチ検出の状態機械（イベントタップのコールバックスレッドからのみ触る）
    private var pinchRecognizer = PinchRecognizer()

    func startMonitoring() {
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: kGestureEventMask,
            callback: Self.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger.error("Failed to create event tap — Accessibility permission may be missing")
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
        logger.info("Started on background thread (cghidEventTap)")
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
            if type == .tapDisabledByTimeout {
                logger.warning("Event tap disabled by timeout, re-enabling")
            } else {
                logger.warning("Event tap disabled by user input, re-enabling")
            }
            if let tap = monitor.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .gesture {
            return GestureMonitor.handleGestureEvent(event: event, monitor: monitor)
        }

        // cghidEventTap は magnify 以外の内部イベント（type 0xFFFFFFFF 等）も届くことがある。
        // NSEvent(cgEvent:) に未知の type を渡すと NSInternalInconsistencyException が発生するため、
        // CGEvent レベルで先にフィルタする。
        guard type == .magnify else { return Unmanaged.passRetained(event) }

        // チップタップ検出: type 29 のタッチ情報はメインスレッドで抽出する（パススルー）
        monitor.forwardTouchEvent(event)

        guard let nsEvent = NSEvent(cgEvent: event),
              nsEvent.type == .magnify else {
            return Unmanaged.passRetained(event)
        }

        let phase = nsEvent.phase

        if phase.contains(.began) {
            monitor.pinchRecognizer.begin(handling: monitor.shouldHandleGesture?() ?? false)
            // ピンチ開始でチップタップの候補をキャンセル（誤発火保険）
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    monitor.tipTapRecognizer.interrupt()
                }
            }
        }

        guard monitor.pinchRecognizer.isHandling else {
            return Unmanaged.passRetained(event)
        }

        if let recognizerPhase = PinchRecognizer.Phase(phase),
           let gesture = monitor.pinchRecognizer.recognize(
               phase: recognizerPhase, magnification: nsEvent.magnification
           ) {
            DispatchQueue.main.async {
                logger.debug("Gesture recognized: \(String(describing: gesture), privacy: .public)")
                monitor.onGestureDetected?(gesture)
            }
        }

        return nil  // consume event
    }

    // MARK: - チップタップ（CGEvent type 29 のタッチ情報）

    // CGEventTap コールバックスレッドから呼ばれる。
    // NSEvent 変換はメインスレッド専用のため、CGEvent を包んで async で運ぶ
    // （メインキューは直列なのでイベント順序は保たれる。
    //   チップタップはパススルー型で同期的な消費判定が不要なので async でよい。
    //   sync はタップのタイムアウト無効化を招くため使わない）。
    private func forwardTouchEvent(_ event: CGEvent) {
        let boxed = UncheckedSendableCGEvent(event: event.copy() ?? event)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.processTouchEvent(boxed.event)
            }
        }
    }

    @MainActor
    private func processTouchEvent(_ event: CGEvent) {
        // タッチ情報を運ぶ NSEvent は .gesture のみ（実機で確認済み。magnify/pressure 等は常に空）
        guard let nsEvent = NSEvent(cgEvent: event),
              nsEvent.type == .gesture else {
            return
        }
        let snapshots = nsEvent.allTouches().compactMap { TouchSnapshot(touch: $0) }
        // タッチ情報を持たない .gesture イベントも混ざるため、空は無視する
        guard !snapshots.isEmpty else { return }
        if let gesture = tipTapRecognizer.recognize(touches: snapshots, timestamp: nsEvent.timestamp) {
            logger.debug("Tip tap recognized: \(String(describing: gesture), privacy: .public)")
            onGestureDetected?(gesture)
        }
    }

    // MARK: - 4本指タップ（CGEvent type 30）

    // type 30 は NSEvent が認識しない非公開 CGEventType。
    // 4本指タップごとに 1 回届くことを実機で確認済み。
    private static func handleGestureEvent(event: CGEvent, monitor: GestureMonitor) -> Unmanaged<CGEvent> {
        DispatchQueue.main.async {
            logger.debug("fourTap detected")
            monitor.onGestureDetected?(.fourTap)
        }
        return Unmanaged.passRetained(event)  // システムのデフォルト動作を温存
    }

    deinit {
        stopMonitoring()
    }
}

private extension PinchRecognizer.Phase {
    /// NSEvent.Phase から写像する。判定に関与しない phase（mayBegin / stationary 等）は nil
    init?(_ phase: NSEvent.Phase) {
        switch phase {
        case .began:     self = .began
        case .changed:   self = .changed
        case .ended:     self = .ended
        case .cancelled: self = .cancelled
        default:         return nil
        }
    }
}

private extension TouchSnapshot {
    /// NSTouch からスナップショットへ変換する。未知の phase は nil
    init?(touch: NSTouch) {
        let phase: TouchSnapshot.Phase
        switch touch.phase {
        case .began:      phase = .began
        case .moved:      phase = .moved
        case .stationary: phase = .stationary
        case .ended:      phase = .ended
        case .cancelled:  phase = .cancelled
        default:          return nil
        }
        self.init(
            id: String(describing: touch.identity),
            phase: phase,
            x: touch.normalizedPosition.x,
            y: touch.normalizedPosition.y
        )
    }
}
