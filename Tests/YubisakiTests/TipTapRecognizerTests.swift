import Testing
@testable import Yubisaki

@MainActor
struct TipTapRecognizerTests {
    private typealias R = TipTapRecognizer

    /// スナップショット生成のショートハンド
    private func touch(
        _ id: String, _ phase: TouchSnapshot.Phase, x: Double, y: Double = 0.5
    ) -> TouchSnapshot {
        TouchSnapshot(id: id, phase: phase, x: x, y: y)
    }

    /// 有効なチップタップ1回ぶんのシーケンスを流し、発火したジェスチャーを返す
    private func performValidTipTap(
        _ recognizer: TipTapRecognizer,
        restX: Double, tapX: Double, startingAt t0: Double
    ) -> GestureType? {
        var emitted: GestureType?
        emitted = recognizer.recognize(
            touches: [touch("rest", .began, x: restX)], timestamp: t0)
        #expect(emitted == nil)
        emitted = recognizer.recognize(
            touches: [touch("rest", .stationary, x: restX), touch("tap", .began, x: tapX)],
            timestamp: t0 + R.minRestDuration + 0.05)
        #expect(emitted == nil)
        return recognizer.recognize(
            touches: [touch("rest", .stationary, x: restX), touch("tap", .ended, x: tapX)],
            timestamp: t0 + R.minRestDuration + 0.15)
    }

    // MARK: - 正常系

    @Test func 右チップタップを検出する() {
        let recognizer = TipTapRecognizer()
        let result = performValidTipTap(recognizer, restX: 0.3, tapX: 0.6, startingAt: 0)
        #expect(result == .twoTipTapRight)
    }

    @Test func 左チップタップを検出する() {
        let recognizer = TipTapRecognizer()
        let result = performValidTipTap(recognizer, restX: 0.6, tapX: 0.3, startingAt: 0)
        #expect(result == .twoTipTapLeft)
    }

    @Test func 置き指を離さず連続チップタップできる() {
        let recognizer = TipTapRecognizer()
        var result = performValidTipTap(recognizer, restX: 0.3, tapX: 0.6, startingAt: 0)
        #expect(result == .twoTipTapRight)
        let emittedAt = R.minRestDuration + 0.15

        // cooldown 経過後の2回目（置き指は接地したまま）
        let t1 = emittedAt + R.cooldown + 0.05
        result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap2", .began, x: 0.6)],
            timestamp: t1)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap2", .ended, x: 0.6)],
            timestamp: t1 + 0.1)
        #expect(result == .twoTipTapRight)
    }

    // MARK: - 誤発火防止

    @Test func 同時2本タップは発火しない() {
        let recognizer = TipTapRecognizer()
        // 2本が同一フレームで着地（2本指タップ = 副ボタンクリック）
        var result = recognizer.recognize(
            touches: [touch("A", .began, x: 0.3), touch("B", .began, x: 0.6)], timestamp: 0)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: [touch("A", .ended, x: 0.3), touch("B", .ended, x: 0.6)], timestamp: 0.1)
        #expect(result == nil)

        // 全指離脱後は idle に復帰し、正しいチップタップは検出できる
        let recovered = performValidTipTap(recognizer, restX: 0.3, tapX: 0.6, startingAt: 1.0)
        #expect(recovered == .twoTipTapRight)
    }

    @Test func 置き指の接地が短すぎると発火しない() {
        let recognizer = TipTapRecognizer()
        var result = recognizer.recognize(
            touches: [touch("rest", .began, x: 0.3)], timestamp: 0)
        #expect(result == nil)
        // minRestDuration 未満で2本目が着地（ほぼ同時タップ）
        result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap", .began, x: 0.6)],
            timestamp: R.minRestDuration - 0.05)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap", .ended, x: 0.6)],
            timestamp: R.minRestDuration + 0.05)
        #expect(result == nil)
    }

    @Test func タップ指の長押しは発火しない() {
        let recognizer = TipTapRecognizer()
        _ = recognizer.recognize(touches: [touch("rest", .began, x: 0.3)], timestamp: 0)
        let tapStart = R.minRestDuration + 0.05
        _ = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap", .began, x: 0.6)],
            timestamp: tapStart)
        // maxTapDuration を超えて接地し続けている
        var result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap", .stationary, x: 0.6)],
            timestamp: tapStart + R.maxTapDuration + 0.1)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap", .ended, x: 0.6)],
            timestamp: tapStart + R.maxTapDuration + 0.2)
        #expect(result == nil)
    }

    @Test func タップ指が動くと発火しない() {
        let recognizer = TipTapRecognizer()
        _ = recognizer.recognize(touches: [touch("rest", .began, x: 0.3)], timestamp: 0)
        let tapStart = R.minRestDuration + 0.05
        _ = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap", .began, x: 0.6)],
            timestamp: tapStart)
        // タップ指が許容量を超えて移動（スクロール）
        var result = recognizer.recognize(
            touches: [
                touch("rest", .stationary, x: 0.3),
                touch("tap", .moved, x: 0.6 + R.tapMovementTolerance + 0.05),
            ],
            timestamp: tapStart + 0.05)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: [
                touch("rest", .stationary, x: 0.3),
                touch("tap", .ended, x: 0.6 + R.tapMovementTolerance + 0.05),
            ],
            timestamp: tapStart + 0.1)
        #expect(result == nil)
    }

    @Test func 置き指が動くと発火しない() {
        let recognizer = TipTapRecognizer()
        _ = recognizer.recognize(touches: [touch("rest", .began, x: 0.3)], timestamp: 0)
        let tapStart = R.minRestDuration + 0.05
        _ = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap", .began, x: 0.6)],
            timestamp: tapStart)
        // 置き指が許容量を超えて移動（2本指スクロール）
        var result = recognizer.recognize(
            touches: [
                touch("rest", .moved, x: 0.3 + R.restMovementTolerance + 0.05),
                touch("tap", .stationary, x: 0.6),
            ],
            timestamp: tapStart + 0.05)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: [
                touch("rest", .stationary, x: 0.3 + R.restMovementTolerance + 0.05),
                touch("tap", .ended, x: 0.6),
            ],
            timestamp: tapStart + 0.1)
        #expect(result == nil)
    }

    @Test func 三本目の指が現れると発火しない() {
        let recognizer = TipTapRecognizer()
        _ = recognizer.recognize(touches: [touch("rest", .began, x: 0.3)], timestamp: 0)
        let tapStart = R.minRestDuration + 0.05
        _ = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap", .began, x: 0.6)],
            timestamp: tapStart)
        var result = recognizer.recognize(
            touches: [
                touch("rest", .stationary, x: 0.3),
                touch("tap", .stationary, x: 0.6),
                touch("third", .began, x: 0.8),
            ],
            timestamp: tapStart + 0.05)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: [
                touch("rest", .stationary, x: 0.3),
                touch("tap", .ended, x: 0.6),
                touch("third", .ended, x: 0.8),
            ],
            timestamp: tapStart + 0.1)
        #expect(result == nil)
        // 置き指が残っている間は invalid のまま
        result = recognizer.recognize(
            touches: [touch("rest", .ended, x: 0.3)], timestamp: tapStart + 0.2)
        #expect(result == nil)

        // 全指離脱後は復帰できる
        let recovered = performValidTipTap(recognizer, restX: 0.3, tapX: 0.6, startingAt: 2.0)
        #expect(recovered == .twoTipTapRight)
    }

    @Test func X距離が近すぎるタップは発火せず置き指状態に戻る() {
        let recognizer = TipTapRecognizer()
        _ = recognizer.recognize(touches: [touch("rest", .began, x: 0.5)], timestamp: 0)
        let tapStart = R.minRestDuration + 0.05
        // X距離が minHorizontalSeparation 未満
        _ = recognizer.recognize(
            touches: [
                touch("rest", .stationary, x: 0.5),
                touch("tap", .began, x: 0.5 + R.minHorizontalSeparation - 0.02),
            ],
            timestamp: tapStart)
        var result = recognizer.recognize(
            touches: [
                touch("rest", .stationary, x: 0.5),
                touch("tap", .ended, x: 0.5 + R.minHorizontalSeparation - 0.02),
            ],
            timestamp: tapStart + 0.1)
        #expect(result == nil)

        // 置き指状態に戻っているので、離れた位置への再タップは発火する
        let retryStart = tapStart + 0.3
        _ = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.5), touch("tap2", .began, x: 0.8)],
            timestamp: retryStart)
        result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.5), touch("tap2", .ended, x: 0.8)],
            timestamp: retryStart + 0.1)
        #expect(result == .twoTipTapRight)
    }

    @Test func cooldown内の再タップは発火しない() {
        let recognizer = TipTapRecognizer()
        let result = performValidTipTap(recognizer, restX: 0.3, tapX: 0.6, startingAt: 0)
        #expect(result == .twoTipTapRight)
        let emittedAt = R.minRestDuration + 0.15

        // cooldown 未経過での再タップ
        let t1 = emittedAt + R.cooldown - 0.1
        var second = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap2", .began, x: 0.6)],
            timestamp: t1)
        #expect(second == nil)
        second = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap2", .ended, x: 0.6)],
            timestamp: t1 + 0.1)
        #expect(second == nil)
    }

    @Test func 一本指タップだけでは発火しない() {
        let recognizer = TipTapRecognizer()
        var result = recognizer.recognize(
            touches: [touch("A", .began, x: 0.5)], timestamp: 0)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: [touch("A", .ended, x: 0.5)], timestamp: 0.1)
        #expect(result == nil)

        // idle に戻っているので次のチップタップは検出できる
        let recovered = performValidTipTap(recognizer, restX: 0.3, tapX: 0.6, startingAt: 1.0)
        #expect(recovered == .twoTipTapRight)
    }

    @Test func interruptで認識が中断される() {
        let recognizer = TipTapRecognizer()
        _ = recognizer.recognize(touches: [touch("rest", .began, x: 0.3)], timestamp: 0)
        let tapStart = R.minRestDuration + 0.05
        _ = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap", .began, x: 0.6)],
            timestamp: tapStart)

        // ピンチ開始などの外部要因
        recognizer.interrupt()

        var result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap", .ended, x: 0.6)],
            timestamp: tapStart + 0.1)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: [touch("rest", .ended, x: 0.3)], timestamp: tapStart + 0.2)
        #expect(result == nil)

        // 全指離脱後は復帰できる
        let recovered = performValidTipTap(recognizer, restX: 0.3, tapX: 0.6, startingAt: 2.0)
        #expect(recovered == .twoTipTapRight)
    }

    @Test func 空のタッチ集合は無視される() {
        let recognizer = TipTapRecognizer()
        _ = recognizer.recognize(touches: [touch("rest", .began, x: 0.3)], timestamp: 0)
        // 実機ではタッチ情報を持たない type-29 イベントが交互に届く。
        // これを「全タッチ消失」と誤解釈しないこと
        var result = recognizer.recognize(touches: [], timestamp: 0.05)
        #expect(result == nil)
        let tapStart = R.minRestDuration + 0.05
        _ = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap", .began, x: 0.6)],
            timestamp: tapStart)
        result = recognizer.recognize(touches: [], timestamp: tapStart + 0.02)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap", .ended, x: 0.6)],
            timestamp: tapStart + 0.1)
        #expect(result == .twoTipTapRight)
    }

    // MARK: - 連続チップタップ（回帰）

    @Test func cooldown内で無視された打鍵の後もcooldown経過後に発火する() {
        // 修正前は cooldown 中のタップで invalid に落ち、全指を離すまで復帰できなかった。
        // 修正後は無視されて resting を維持し、cooldown 経過後の打鍵が発火する。
        let recognizer = TipTapRecognizer()
        let result = performValidTipTap(recognizer, restX: 0.3, tapX: 0.6, startingAt: 0)
        #expect(result == .twoTipTapRight)
        let emittedAt = R.minRestDuration + 0.15

        // 2打目: cooldown 未経過なので無視される（置き指は接地したまま）
        let t2 = emittedAt + R.cooldown - 0.05
        var r = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap2", .began, x: 0.6)],
            timestamp: t2)
        #expect(r == nil)
        r = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap2", .ended, x: 0.6)],
            timestamp: t2 + 0.05)
        #expect(r == nil)

        // 3打目: 置き指を離していないが、cooldown 経過後なので発火する（修正の核心）
        let t3 = emittedAt + R.cooldown + 0.20
        r = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap3", .began, x: 0.6)],
            timestamp: t3)
        #expect(r == nil)
        r = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap3", .ended, x: 0.6)],
            timestamp: t3 + 0.1)
        #expect(r == .twoTipTapRight)
    }

    @Test func 置き指を離さず左右交互に連続チップタップできる() {
        let recognizer = TipTapRecognizer()
        // 右タップ
        var result = performValidTipTap(recognizer, restX: 0.5, tapX: 0.8, startingAt: 0)
        #expect(result == .twoTipTapRight)
        var emittedAt = R.minRestDuration + 0.15

        // 左タップ（cooldown + α 経過後、置き指は接地したまま）
        let leftStart = emittedAt + R.cooldown + 0.05
        result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.5), touch("l", .began, x: 0.2)],
            timestamp: leftStart)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.5), touch("l", .ended, x: 0.2)],
            timestamp: leftStart + 0.1)
        #expect(result == .twoTipTapLeft)
        emittedAt = leftStart + 0.1

        // 再び右タップ
        let rightStart = emittedAt + R.cooldown + 0.05
        result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.5), touch("r", .began, x: 0.8)],
            timestamp: rightStart)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.5), touch("r", .ended, x: 0.8)],
            timestamp: rightStart + 0.1)
        #expect(result == .twoTipTapRight)
    }

    @Test func 同時着地で無視されても置き指状態が維持され次のタップが発火する() {
        let recognizer = TipTapRecognizer()
        _ = recognizer.recognize(touches: [touch("rest", .began, x: 0.3)], timestamp: 0)
        // minRestDuration 未満で着地したタップは無視される（invalid に落とさない）
        var result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("early", .began, x: 0.6)],
            timestamp: R.minRestDuration - 0.05)
        #expect(result == nil)
        // その指が離れる（置き指は接地したまま維持される）
        result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("early", .ended, x: 0.6)],
            timestamp: R.minRestDuration + 0.02)
        #expect(result == nil)

        // 置き指状態のまま、次の正しいタップが発火する
        let tapStart = R.minRestDuration + 0.30
        result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap", .began, x: 0.6)],
            timestamp: tapStart)
        #expect(result == nil)
        result = recognizer.recognize(
            touches: [touch("rest", .stationary, x: 0.3), touch("tap", .ended, x: 0.6)],
            timestamp: tapStart + 0.1)
        #expect(result == .twoTipTapRight)
    }
}
