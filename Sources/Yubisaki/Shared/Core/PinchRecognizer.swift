/// ピンチ（magnify）イベント列からピンチイン/アウトを判定する累積状態機械。
///
/// AppKit 非依存の値型にすることで、合成イベント列によるユニットテストを可能にする
/// （`HoldTapRecognizer` と同じ方針）。`GestureMonitor` の CGEventTap コールバック
/// スレッドからのみ使う前提で、スレッド閉じ込めは呼び出し側の責務。
struct PinchRecognizer {
    /// ピンチ確定に必要な累積変化量の閾値
    static let threshold: Double = 0.3

    /// magnify イベントのフェーズ（NSEvent.Phase から必要なものだけを写像した値）
    enum Phase: Sendable {
        case began, changed, ended, cancelled
    }

    private var accumulatedMagnification: Double = 0
    /// 現在のピンチを消費（ハンドル）して判定対象にしているか。
    /// false の間、呼び出し側はイベントをパススルーしてネイティブのピンチズームを温存する。
    private(set) var isHandling = false

    /// ピンチ開始。`handling` はこのピンチを消費して判定対象にするかどうか
    /// （使用可能な pinch バインディングの有無で呼び出し側が決める）。
    mutating func begin(handling: Bool) {
        isHandling = handling
        accumulatedMagnification = 0
    }

    /// イベント1件ぶんのフェーズと変化量を処理し、ended で累積が閾値を超えていれば
    /// ジェスチャーを返す。ハンドル中でなければ何もしない。
    mutating func recognize(phase: Phase, magnification: Double) -> GestureType? {
        guard isHandling else { return nil }
        switch phase {
        case .began:
            // 開始処理は begin(handling:) で行う（shouldHandle の判定が必要なため分離）
            break
        case .changed:
            accumulatedMagnification += magnification
        case .ended:
            accumulatedMagnification += magnification
            let total = accumulatedMagnification
            accumulatedMagnification = 0
            isHandling = false
            if total > Self.threshold { return .pinchOut }
            if total < -Self.threshold { return .pinchIn }
        case .cancelled:
            accumulatedMagnification = 0
            isHandling = false
        }
        return nil
    }
}
