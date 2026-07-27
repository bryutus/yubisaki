import AppKit
import os
@preconcurrency import CoreGraphics
@preconcurrency import CoreFoundation

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "yubisaki", category: "GestureMonitor")

extension CGEventType {
    static let magnify = CGEventType(rawValue: 29)!
}

private let kGestureEventMask = CGEventMask(1 << CGEventType.magnify.rawValue)

/// CGEvent をタップコールバックスレッドからメインスレッドへ運ぶためのラッパー
private struct UncheckedSendableCGEvent: @unchecked Sendable { let event: CGEvent }

final class GestureMonitor: @unchecked Sendable {
    var onGestureDetected: ((GestureType) -> Void)?
    /// Called synchronously from the event tap background thread at gesture start.
    /// Return true to consume the gesture (suppress native zoom); false to pass through.
    var shouldHandleGesture: (() -> Bool)?

    /// イベントタップの実体。生成はメイン、RunLoop の登録はタップ用スレッド、
    /// 再有効化はコールバックスレッドと触るスレッドが分かれるためロックで保護する。
    /// CFMachPort / CFRunLoop への参照自体はスレッドをまたいで渡してよい
    /// （ここで呼ぶ `CGEvent.tapEnable` と `CFRunLoopStop` はどちらもスレッドセーフ）。
    private struct TapState: @unchecked Sendable {
        var eventTap: CFMachPort?
        var runLoop: CFRunLoop?
    }

    private let tapState = OSAllocatedUnfairLock(initialState: TapState())
    /// ホールドタップ検出の状態機械（メインスレッドからのみ触る）
    private let holdTapRecognizer = HoldTapRecognizer()
    /// 3本指/4本指タップ検出の状態機械（メインスレッドからのみ触る）
    private let multiFingerTapRecognizer = MultiFingerTapRecognizer()
    /// ピンチ検出の状態機械（イベントタップのコールバックスレッドからのみ触る）
    private var pinchRecognizer = PinchRecognizer()
    /// タッチIDの割り当て（メインスレッドからのみ触る）
    private let touchIDs = TouchIDTable()

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

        tapState.withLock { $0.eventTap = tap }

        let thread = Thread {
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            let rl = CFRunLoopGetCurrent()
            CFRunLoopAddSource(rl, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            self.tapState.withLock { $0.runLoop = rl }
            CFRunLoopRun()
        }
        thread.name = "GestureMonitor"
        thread.start()
        logger.info("Started on background thread (cghidEventTap)")
    }

    func stopMonitoring() {
        let previous = tapState.withLock { state -> TapState in
            let previous = state
            state = TapState()
            return previous
        }
        if let tap = previous.eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let rl = previous.runLoop {
            CFRunLoopStop(rl)
        }
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
            if let tap = monitor.tapState.withLock({ $0.eventTap }) {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // cghidEventTap は magnify 以外の内部イベント（type 0xFFFFFFFF 等）も届くことがある。
        // NSEvent(cgEvent:) に未知の type を渡すと NSInternalInconsistencyException が発生するため、
        // CGEvent レベルで先にフィルタする。
        guard type == .magnify else { return Unmanaged.passRetained(event) }

        // ホールドタップ検出: type 29 のタッチ情報はメインスレッドで抽出する（パススルー）
        monitor.forwardTouchEvent(event)

        guard let nsEvent = NSEvent(cgEvent: event),
              nsEvent.type == .magnify else {
            return Unmanaged.passRetained(event)
        }

        let phase = nsEvent.phase

        if phase.contains(.began) {
            monitor.pinchRecognizer.begin(handling: monitor.shouldHandleGesture?() ?? false)
            // ピンチ開始でタップ系の候補をキャンセル（誤発火保険）
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    monitor.holdTapRecognizer.interrupt()
                    monitor.multiFingerTapRecognizer.interrupt()
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

    // MARK: - タップ系（CGEvent type 29 のタッチ情報）

    // CGEventTap コールバックスレッドから呼ばれる。
    // NSEvent 変換はメインスレッド専用のため、CGEvent を包んで async で運ぶ
    // （メインキューは直列なのでイベント順序は保たれる。
    //   タップ系はパススルー型で同期的な消費判定が不要なので async でよい。
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
        let touches = nsEvent.allTouches()
        // タッチ情報を持たない .gesture イベントも混ざるため、空は無視する（全指離脱ではない）
        guard !touches.isEmpty else { return }

        let snapshots = touches.compactMap { snapshot(for: $0) }
        touchIDs.retire(after: touches)
        guard !snapshots.isEmpty else { return }

        // 3本以上の接地はホールドタップ側が無条件で失格にするため、同じタッチストリームを
        // 両方の認識器に流しても二重発火しない
        if let gesture = holdTapRecognizer.recognize(touches: snapshots, timestamp: nsEvent.timestamp) {
            logger.debug("Hold tap recognized: \(String(describing: gesture), privacy: .public)")
            onGestureDetected?(gesture)
        }
        if let gesture = multiFingerTapRecognizer.recognize(touches: snapshots, timestamp: nsEvent.timestamp) {
            logger.debug("Multi-finger tap recognized: \(String(describing: gesture), privacy: .public)")
            onGestureDetected?(gesture)
        }
    }

    /// NSTouch からスナップショットへ変換する。未知の phase は nil
    @MainActor
    private func snapshot(for touch: NSTouch) -> TouchSnapshot? {
        guard let phase = TouchSnapshot.Phase(touch.phase) else { return nil }
        return TouchSnapshot(
            id: touchIDs.id(for: touch.identity),
            phase: phase,
            x: touch.normalizedPosition.x,
            y: touch.normalizedPosition.y
        )
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

/// 接地中のタッチと、こちらで振ったIDの対応表。
///
/// `NSTouch.identity` はインスタンスの同一性も説明文字列の安定性・一意性も保証されておらず
/// （Apple のドキュメントは `isEqual:` での比較を指示している）、文字列化したものを
/// そのままキーにはできない。identity を保持して照合し、自前の連番IDを配る。
@MainActor
private final class TouchIDTable {
    private var live: [(identity: any NSObjectProtocol, id: String)] = []
    private var lastSerial = 0

    nonisolated init() {}

    /// 追跡中のタッチなら同じIDを返し、新しいタッチには連番IDを割り当てる
    func id(for identity: any NSObjectProtocol) -> String {
        if let known = live.first(where: { $0.identity.isEqual(identity) }) {
            return known.id
        }
        lastSerial += 1
        let id = "touch-\(lastSerial)"
        live.append((identity, id))
        return id
    }

    /// 離脱したタッチの対応を破棄する。identity が使い回されても前のIDを引き継がないよう、
    /// ended/cancelled はスナップショット生成の直後に外す（イベントから消えた分も掃除する）。
    func retire(after touches: Set<NSTouch>) {
        live.removeAll { entry in
            guard let touch = touches.first(where: { $0.identity.isEqual(entry.identity) }) else {
                return true
            }
            return touch.phase.contains(.ended) || touch.phase.contains(.cancelled)
        }
    }
}

private extension TouchSnapshot.Phase {
    /// NSTouch.Phase から写像する。未知の phase は nil
    init?(_ phase: NSTouch.Phase) {
        switch phase {
        case .began:      self = .began
        case .moved:      self = .moved
        case .stationary: self = .stationary
        case .ended:      self = .ended
        case .cancelled:  self = .cancelled
        default:          return nil
        }
    }
}
