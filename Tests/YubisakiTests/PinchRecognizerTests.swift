import Testing
@testable import Yubisaki

struct PinchRecognizerTests {

    // MARK: - 正常系

    @Test func 累積が閾値を超えるとピンチアウトを検出する() {
        var recognizer = PinchRecognizer()
        recognizer.begin(handling: true)
        #expect(recognizer.recognize(phase: .changed, magnification: 0.2) == nil)
        #expect(recognizer.recognize(phase: .changed, magnification: 0.2) == nil)
        #expect(recognizer.recognize(phase: .ended, magnification: 0.0) == .pinchOut)
    }

    @Test func 累積が負の閾値を超えるとピンチインを検出する() {
        var recognizer = PinchRecognizer()
        recognizer.begin(handling: true)
        #expect(recognizer.recognize(phase: .changed, magnification: -0.25) == nil)
        #expect(recognizer.recognize(phase: .ended, magnification: -0.1) == .pinchIn)
    }

    @Test func ended自身の変化量も累積に含める() {
        var recognizer = PinchRecognizer()
        recognizer.begin(handling: true)
        #expect(recognizer.recognize(phase: .changed, magnification: 0.2) == nil)
        // 0.2 + 0.15 = 0.35 > threshold(0.3)
        #expect(recognizer.recognize(phase: .ended, magnification: 0.15) == .pinchOut)
    }

    @Test func 連続したピンチをそれぞれ独立に判定する() {
        var recognizer = PinchRecognizer()
        recognizer.begin(handling: true)
        #expect(recognizer.recognize(phase: .changed, magnification: 0.4) == nil)
        #expect(recognizer.recognize(phase: .ended, magnification: 0) == .pinchOut)

        // 2回目: 前回の累積を引き継がない
        recognizer.begin(handling: true)
        #expect(recognizer.recognize(phase: .changed, magnification: -0.4) == nil)
        #expect(recognizer.recognize(phase: .ended, magnification: 0) == .pinchIn)
    }

    // MARK: - 発火しないケース

    @Test func 累積が閾値ちょうどでは発火しない() {
        var recognizer = PinchRecognizer()
        recognizer.begin(handling: true)
        let result = recognizer.recognize(
            phase: .ended, magnification: PinchRecognizer.threshold)
        #expect(result == nil)
    }

    @Test func 累積が閾値未満では発火しない() {
        var recognizer = PinchRecognizer()
        recognizer.begin(handling: true)
        #expect(recognizer.recognize(phase: .changed, magnification: 0.1) == nil)
        #expect(recognizer.recognize(phase: .ended, magnification: 0.1) == nil)
    }

    @Test func 拡大と縮小が相殺されると発火しない() {
        var recognizer = PinchRecognizer()
        recognizer.begin(handling: true)
        #expect(recognizer.recognize(phase: .changed, magnification: 0.3) == nil)
        #expect(recognizer.recognize(phase: .changed, magnification: -0.25) == nil)
        #expect(recognizer.recognize(phase: .ended, magnification: 0) == nil)
    }

    // MARK: - ハンドリング状態

    @Test func ハンドルしない開始では何も検出しない() {
        var recognizer = PinchRecognizer()
        recognizer.begin(handling: false)
        #expect(recognizer.isHandling == false)
        #expect(recognizer.recognize(phase: .changed, magnification: 1.0) == nil)
        #expect(recognizer.recognize(phase: .ended, magnification: 0) == nil)
    }

    @Test func endedで判定後はハンドル状態が解除される() {
        var recognizer = PinchRecognizer()
        recognizer.begin(handling: true)
        #expect(recognizer.recognize(phase: .ended, magnification: 0.5) == .pinchOut)
        #expect(recognizer.isHandling == false)
    }

    @Test func cancelledで累積とハンドル状態がリセットされる() {
        var recognizer = PinchRecognizer()
        recognizer.begin(handling: true)
        #expect(recognizer.recognize(phase: .changed, magnification: 0.5) == nil)
        #expect(recognizer.recognize(phase: .cancelled, magnification: 0) == nil)
        #expect(recognizer.isHandling == false)

        // キャンセル後の新しいピンチは累積ゼロから始まる
        recognizer.begin(handling: true)
        #expect(recognizer.recognize(phase: .ended, magnification: 0.1) == nil)
    }

    @Test func beganフェーズは累積に影響しない() {
        var recognizer = PinchRecognizer()
        recognizer.begin(handling: true)
        // NSEvent の began フレームは magnification を持ちうるが、判定には加えない（現行挙動の維持）
        #expect(recognizer.recognize(phase: .began, magnification: 1.0) == nil)
        #expect(recognizer.recognize(phase: .ended, magnification: 0.1) == nil)
    }
}
