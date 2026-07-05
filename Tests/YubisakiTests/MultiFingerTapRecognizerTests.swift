import Testing
@testable import Yubisaki

@MainActor
struct MultiFingerTapRecognizerTests {
    private typealias M = MultiFingerTapRecognizer

    /// スナップショット生成のショートハンド
    private func touch(
        _ id: String, _ phase: TouchSnapshot.Phase, x: Double = 0.5, y: Double = 0.5
    ) -> TouchSnapshot {
        TouchSnapshot(id: id, phase: phase, x: x, y: y)
    }

    /// 各指を横に並べた固定X座標（重ならないよう 0.1 刻み）
    private func x(forFinger index: Int) -> Double { 0.2 + Double(index) * 0.1 }

    /// n本指をすべて同一イベントで began → 同一イベントで ended する有効な同時タップ。
    /// 発火したジェスチャーを返す（began の戻り値は nil を確認する）。
    private func performSimultaneousTap(
        _ recognizer: MultiFingerTapRecognizer, fingerCount n: Int, startingAt t0: Double
    ) -> GestureType? {
        let began = (0..<n).map { touch("f\($0)", .began, x: x(forFinger: $0)) }
        #expect(recognizer.recognize(touches: began, timestamp: t0) == nil)
        let ended = (0..<n).map { touch("f\($0)", .ended, x: x(forFinger: $0)) }
        return recognizer.recognize(touches: ended, timestamp: t0 + 0.10)
    }

    // MARK: - 正常系

    @Test func 三本指同時タップを検出する() {
        let recognizer = MultiFingerTapRecognizer()
        let result = performSimultaneousTap(recognizer, fingerCount: 3, startingAt: 0)
        #expect(result == .threeTap)
    }

    @Test func 四本指同時タップを検出する() {
        let recognizer = MultiFingerTapRecognizer()
        let result = performSimultaneousTap(recognizer, fingerCount: 4, startingAt: 0)
        #expect(result == .fourTap)
    }

    @Test func 着地が二回に分かれてもmaxLandingSpread以内なら発火する() {
        let recognizer = MultiFingerTapRecognizer()
        // A・B が着地
        var result = recognizer.recognize(
            touches: [touch("A", .began, x: 0.3), touch("B", .began, x: 0.4)], timestamp: 0)
        #expect(result == nil)
        // C が maxLandingSpread 以内で遅れて着地（A・B は接地継続）
        result = recognizer.recognize(
            touches: [
                touch("A", .stationary, x: 0.3),
                touch("B", .stationary, x: 0.4),
                touch("C", .began, x: 0.5),
            ],
            timestamp: M.maxLandingSpread - 0.02)
        #expect(result == nil)
        // 全指離脱
        result = recognizer.recognize(
            touches: [
                touch("A", .ended, x: 0.3),
                touch("B", .ended, x: 0.4),
                touch("C", .ended, x: 0.5),
            ],
            timestamp: M.maxLandingSpread + 0.05)
        #expect(result == .threeTap)
    }

    @Test func 指が一本ずつ離脱してもmaxTapDuration以内なら発火する() {
        let recognizer = MultiFingerTapRecognizer()
        var result = recognizer.recognize(
            touches: [
                touch("A", .began, x: 0.3),
                touch("B", .began, x: 0.4),
                touch("C", .began, x: 0.5),
            ],
            timestamp: 0)
        #expect(result == nil)
        // A だけ離脱（B・C は接地継続）
        result = recognizer.recognize(
            touches: [
                touch("A", .ended, x: 0.3),
                touch("B", .stationary, x: 0.4),
                touch("C", .stationary, x: 0.5),
            ],
            timestamp: 0.10)
        #expect(result == nil)
        // B が離脱
        result = recognizer.recognize(
            touches: [touch("B", .ended, x: 0.4), touch("C", .stationary, x: 0.5)],
            timestamp: 0.15)
        #expect(result == nil)
        // 最後の C が離脱 → maxTapDuration 以内なので発火
        result = recognizer.recognize(
            touches: [touch("C", .ended, x: 0.5)], timestamp: 0.20)
        #expect(result == .threeTap)
    }

    @Test func 発火後に次のタップも検出できる() {
        let recognizer = MultiFingerTapRecognizer()
        #expect(performSimultaneousTap(recognizer, fingerCount: 3, startingAt: 0) == .threeTap)
        // 状態がリセットされ、次のタップも検出できる
        #expect(performSimultaneousTap(recognizer, fingerCount: 4, startingAt: 1.0) == .fourTap)
        #expect(performSimultaneousTap(recognizer, fingerCount: 3, startingAt: 2.0) == .threeTap)
    }

    // MARK: - 誤発火防止

    @Test func 四本指が移動して離脱すると発火しない() {
        let recognizer = MultiFingerTapRecognizer()
        var result = recognizer.recognize(
            touches: (0..<4).map { touch("f\($0)", .began, x: x(forFinger: $0), y: 0.5) },
            timestamp: 0)
        #expect(result == nil)
        // 全指が上方向へ movementTolerance を超えて移動（上スワイプ相当）
        let movedY = 0.5 + M.movementTolerance + 0.05
        result = recognizer.recognize(
            touches: (0..<4).map { touch("f\($0)", .moved, x: x(forFinger: $0), y: movedY) },
            timestamp: 0.05)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: (0..<4).map { touch("f\($0)", .ended, x: x(forFinger: $0), y: movedY) },
            timestamp: 0.10)
        #expect(result == nil)
    }

    @Test func 移動して離脱後に復帰し次の正しいタップは発火する() {
        let recognizer = MultiFingerTapRecognizer()
        _ = recognizer.recognize(
            touches: (0..<4).map { touch("f\($0)", .began, x: x(forFinger: $0), y: 0.5) },
            timestamp: 0)
        let movedY = 0.5 + M.movementTolerance + 0.05
        _ = recognizer.recognize(
            touches: (0..<4).map { touch("f\($0)", .moved, x: x(forFinger: $0), y: movedY) },
            timestamp: 0.05)
        _ = recognizer.recognize(
            touches: (0..<4).map { touch("f\($0)", .ended, x: x(forFinger: $0), y: movedY) },
            timestamp: 0.10)
        // 全指離脱で復帰。次の正しい同時タップは発火する
        #expect(performSimultaneousTap(recognizer, fingerCount: 4, startingAt: 1.0) == .fourTap)
    }

    @Test func 後着の指がmaxLandingSpread超で着地すると発火しない() {
        let recognizer = MultiFingerTapRecognizer()
        var result = recognizer.recognize(
            touches: [touch("A", .began, x: 0.3), touch("B", .began, x: 0.4)], timestamp: 0)
        #expect(result == nil)
        // 3本目が maxLandingSpread を超えて着地（チップタップ的な順次着地）
        result = recognizer.recognize(
            touches: [
                touch("A", .stationary, x: 0.3),
                touch("B", .stationary, x: 0.4),
                touch("C", .began, x: 0.5),
            ],
            timestamp: M.maxLandingSpread + 0.05)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: [
                touch("A", .ended, x: 0.3),
                touch("B", .ended, x: 0.4),
                touch("C", .ended, x: 0.5),
            ],
            timestamp: M.maxLandingSpread + 0.15)
        #expect(result == nil)
    }

    @Test func maxTapDuration超の長押し後に離脱すると発火しない() {
        let recognizer = MultiFingerTapRecognizer()
        var result = recognizer.recognize(
            touches: (0..<3).map { touch("f\($0)", .began, x: x(forFinger: $0)) },
            timestamp: 0)
        #expect(result == nil)
        // maxTapDuration を超えて接地し続ける
        result = recognizer.recognize(
            touches: (0..<3).map { touch("f\($0)", .stationary, x: x(forFinger: $0)) },
            timestamp: M.maxTapDuration + 0.05)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: (0..<3).map { touch("f\($0)", .ended, x: x(forFinger: $0)) },
            timestamp: M.maxTapDuration + 0.10)
        #expect(result == nil)
    }

    @Test func 二本指タップは発火しない() {
        let recognizer = MultiFingerTapRecognizer()
        #expect(performSimultaneousTap(recognizer, fingerCount: 2, startingAt: 0) == nil)
    }

    @Test func 一本指タップは発火しない() {
        let recognizer = MultiFingerTapRecognizer()
        #expect(performSimultaneousTap(recognizer, fingerCount: 1, startingAt: 0) == nil)
    }

    @Test func 五本指タップは発火しない() {
        let recognizer = MultiFingerTapRecognizer()
        #expect(performSimultaneousTap(recognizer, fingerCount: 5, startingAt: 0) == nil)
    }

    @Test func interrupt後は全指離脱まで発火しない() {
        let recognizer = MultiFingerTapRecognizer()
        _ = recognizer.recognize(
            touches: (0..<3).map { touch("f\($0)", .began, x: x(forFinger: $0)) },
            timestamp: 0)
        // 外部要因（ピンチ開始など）で中断
        recognizer.interrupt()
        let result = recognizer.recognize(
            touches: (0..<3).map { touch("f\($0)", .ended, x: x(forFinger: $0)) },
            timestamp: 0.10)
        #expect(result == nil)
        // 全指離脱後は復帰できる
        #expect(performSimultaneousTap(recognizer, fingerCount: 3, startingAt: 1.0) == .threeTap)
    }

    @Test func 空のタッチ集合は状態を壊さない() {
        let recognizer = MultiFingerTapRecognizer()
        var result = recognizer.recognize(
            touches: (0..<3).map { touch("f\($0)", .began, x: x(forFinger: $0)) },
            timestamp: 0)
        #expect(result == nil)
        // タッチ情報を持たないイベント（空集合）は無視され、進行中のタップを壊さない
        result = recognizer.recognize(touches: [], timestamp: 0.03)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: (0..<3).map { touch("f\($0)", .ended, x: x(forFinger: $0)) },
            timestamp: 0.10)
        #expect(result == .threeTap)
    }
}
