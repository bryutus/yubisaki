import CoreGraphics
import Foundation
import Testing
@testable import Yubisaki

struct GestureBindingTests {

    // MARK: - shortcutDescription

    @Test func 修飾キーなしのショートカット表記() {
        let binding = GestureBinding(gesture: .pinchIn, keyCode: 1) // "S"
        #expect(binding.shortcutDescription == "S")
    }

    @Test func 単一修飾キーのショートカット表記() {
        let binding = GestureBinding(
            gesture: .pinchIn, keyCode: 1, modifierFlags: CGEventFlags.maskCommand.rawValue)
        #expect(binding.shortcutDescription == "⌘S")
    }

    @Test func 複数修飾キーはコントロール_オプション_シフト_コマンドの順で並ぶ() {
        let allModifiers = CGEventFlags.maskControl.rawValue
            | CGEventFlags.maskAlternate.rawValue
            | CGEventFlags.maskShift.rawValue
            | CGEventFlags.maskCommand.rawValue
        let binding = GestureBinding(gesture: .pinchIn, keyCode: 49, modifierFlags: allModifiers) // "Space"
        #expect(binding.shortcutDescription == "⌃⌥⇧⌘Space")
    }

    @Test func keyCodeが0のショートカットは未設定として空文字になる() {
        let binding = GestureBinding(
            gesture: .pinchIn, keyCode: 0, modifierFlags: CGEventFlags.maskCommand.rawValue)
        #expect(binding.shortcutDescription == "")
    }

    // MARK: - keyCodeString

    @Test func 既知のkeyCodeは対応する記号に変換される() {
        #expect(GestureBinding.keyCodeString(0) == "A")
        #expect(GestureBinding.keyCodeString(36) == "↩")
        #expect(GestureBinding.keyCodeString(49) == "Space")
    }

    @Test func 未知のkeyCodeはコード番号表記になる() {
        #expect(GestureBinding.keyCodeString(200) == "(200)")
    }

    // MARK: - isUsable

    @Test func 有効かつショートカット設定済みなら使用可能() {
        let binding = GestureBinding(gesture: .pinchIn, keyCode: 1, enabled: true)
        #expect(binding.isUsable)
    }

    @Test func 有効でもショートカット未設定なら使用不可() {
        let binding = GestureBinding(gesture: .pinchIn, keyCode: 0, enabled: true)
        #expect(!binding.isUsable)
    }

    @Test func 無効ならショートカット設定済みでも使用不可() {
        let binding = GestureBinding(gesture: .pinchIn, keyCode: 1, enabled: false)
        #expect(!binding.isUsable)
    }

    @Test func 無効かつショートカット未設定なら使用不可() {
        let binding = GestureBinding(gesture: .pinchIn, keyCode: 0, enabled: false)
        #expect(!binding.isUsable)
    }

    // MARK: - Codable マイグレーション

    @Test func id_enabledキーの無いv1形式をデコードするとidが生成されenabledがtrueになる() throws {
        // GestureType は連想値なし enum の自動 Codable 合成により {"pinchIn":{}} という形で
        // エンコードされる（実際の encode 結果で確認済み）。v1 形式もこれに従う。
        let json = """
        {"gesture":{"pinchIn":{}},"keyCode":10,"modifierFlags":0}
        """
        let decoded = try JSONDecoder().decode(GestureBinding.self, from: Data(json.utf8))
        #expect(decoded.gesture == .pinchIn)
        #expect(decoded.keyCode == 10)
        #expect(decoded.modifierFlags == 0)
        #expect(decoded.enabled == true)
        // id は自動生成される（nilにならず、有効なUUID）
        _ = decoded.id
    }

    @Test func encodeしてdecodeすると同じ内容に戻る() throws {
        let original = GestureBinding(
            gesture: .twoHoldTapRight, keyCode: 8, modifierFlags: CGEventFlags.maskShift.rawValue, enabled: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GestureBinding.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.gesture == original.gesture)
        #expect(decoded.keyCode == original.keyCode)
        #expect(decoded.modifierFlags == original.modifierFlags)
        #expect(decoded.enabled == original.enabled)
    }

    // MARK: - GestureType の旧名からの移行

    @Test func 旧名twoTipTapをホールドタップとして読める() throws {
        let json = """
        [{"gesture":{"twoTipTapLeft":{}},"keyCode":1,"modifierFlags":0},
         {"gesture":{"twoTipTapRight":{}},"keyCode":2,"modifierFlags":0}]
        """
        let decoded = try JSONDecoder().decode([GestureBinding].self, from: Data(json.utf8))
        #expect(decoded.map(\.gesture) == [.twoHoldTapLeft, .twoHoldTapRight])
    }

    @Test func 保存時は新名で書き出す() throws {
        let data = try JSONEncoder().encode(GestureBinding(gesture: .twoHoldTapLeft, keyCode: 1))
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("twoHoldTapLeft"))
        #expect(!json.contains("twoTipTapLeft"))
    }

    @Test func 全ケースがencode_decodeで往復する() throws {
        for gesture in GestureType.allCases {
            let data = try JSONEncoder().encode(GestureBinding(gesture: gesture, keyCode: 1))
            let decoded = try JSONDecoder().decode(GestureBinding.self, from: data)
            #expect(decoded.gesture == gesture)
        }
    }

    @Test func 未知のジェスチャー名はデコードに失敗する() {
        let json = """
        {"gesture":{"fiveFingerSalute":{}},"keyCode":1,"modifierFlags":0}
        """
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(GestureBinding.self, from: Data(json.utf8))
        }
    }
}
