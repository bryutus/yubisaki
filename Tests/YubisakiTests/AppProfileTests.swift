import Foundation
import Testing
@testable import Yubisaki

struct AppProfileTests {

    // MARK: - Codable マイグレーション

    @Test func enabledキーの無いv1形式をデコードするとenabledがtrueになる() throws {
        let json = """
        {"bundleID":"com.example.app","bindings":[]}
        """
        let decoded = try JSONDecoder().decode(AppProfile.self, from: Data(json.utf8))
        #expect(decoded.bundleID == "com.example.app")
        #expect(decoded.enabled == true)
        #expect(decoded.bindings.isEmpty)
    }

    // MARK: - shadowedBindingIDs

    @Test func 重複ジェスチャーが無ければshadowedは空() {
        let profile = AppProfile(
            bundleID: "com.example.app",
            bindings: [
                GestureBinding(gesture: .pinchIn, keyCode: 1),
                GestureBinding(gesture: .pinchOut, keyCode: 2),
            ]
        )
        #expect(profile.shadowedBindingIDs.isEmpty)
    }

    @Test func 同一ジェスチャーが2件とも使用可能なら後の方だけshadowedになる() {
        let first = GestureBinding(gesture: .pinchIn, keyCode: 1)
        let second = GestureBinding(gesture: .pinchIn, keyCode: 2)
        let profile = AppProfile(bundleID: "com.example.app", bindings: [first, second])
        #expect(profile.shadowedBindingIDs == [second.id])
    }

    @Test func 無効な重複はshadowed扱いにならずかつ先行として他をshadowしない() {
        let disabledDuplicate = GestureBinding(gesture: .pinchIn, keyCode: 1, enabled: false)
        let usable = GestureBinding(gesture: .pinchIn, keyCode: 2, enabled: true)
        let profile = AppProfile(bundleID: "com.example.app", bindings: [disabledDuplicate, usable])
        // disabledDuplicate は isUsable ではないため走査対象外。usable が最初の「使用可能な」
        // バインディングとして扱われ、shadowed にはならない。
        #expect(profile.shadowedBindingIDs.isEmpty)
    }

    @Test func keyCode未設定の重複はshadowed扱いにならずかつ先行として他をshadowしない() {
        let unsetDuplicate = GestureBinding(gesture: .pinchIn, keyCode: nil, enabled: true)
        let usable = GestureBinding(gesture: .pinchIn, keyCode: 2, enabled: true)
        let profile = AppProfile(bundleID: "com.example.app", bindings: [unsetDuplicate, usable])
        #expect(profile.shadowedBindingIDs.isEmpty)
    }

    @Test func 三件重複すると二件目以降がshadowedになる() {
        let first = GestureBinding(gesture: .pinchIn, keyCode: 1)
        let second = GestureBinding(gesture: .pinchIn, keyCode: 2)
        let third = GestureBinding(gesture: .pinchIn, keyCode: 3)
        let profile = AppProfile(bundleID: "com.example.app", bindings: [first, second, third])
        #expect(profile.shadowedBindingIDs == [second.id, third.id])
    }

    // MARK: - usedGestures

    @Test func usedGesturesはバインディング中のジェスチャー種別の集合() {
        let profile = AppProfile(
            bundleID: "com.example.app",
            bindings: [
                GestureBinding(gesture: .pinchIn, keyCode: 1),
                GestureBinding(gesture: .pinchOut, keyCode: 2),
                GestureBinding(gesture: .pinchIn, keyCode: 3, enabled: false),
            ]
        )
        #expect(profile.usedGestures == [.pinchIn, .pinchOut])
    }
}
