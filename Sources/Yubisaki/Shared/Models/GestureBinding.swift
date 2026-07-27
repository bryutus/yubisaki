import CoreGraphics
import Foundation

struct GestureBinding: Codable, Sendable, Identifiable {
    var id: UUID
    var gesture: GestureType
    /// 未設定は nil。0 は 'A' の正当な仮想キーコードなので、未設定の表現には使えない
    var keyCode: CGKeyCode?
    var modifierFlags: UInt64
    var enabled: Bool

    init(gesture: GestureType, keyCode: CGKeyCode? = nil, modifierFlags: UInt64 = 0, enabled: Bool = true) {
        self.id = UUID()
        self.gesture = gesture
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.enabled = enabled
    }

    var eventFlags: CGEventFlags { CGEventFlags(rawValue: modifierFlags) }

    /// 有効かつショートカット設定済みで、実際に発火し得るバインディングかどうか。
    var isUsable: Bool { enabled && keyCode != nil }

    var shortcutDescription: String {
        guard let keyCode else { return "" }
        var parts = eventFlags.modifierSymbols
        parts.append(Self.keyCodeString(keyCode))
        return parts.joined()
    }

    static func keyCodeString(_ code: CGKeyCode) -> String {
        let table: [CGKeyCode: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
            50: "`", 51: "⌫", 53: "⎋", 76: "↩",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
            103: "F11", 107: "F14", 109: "F10", 111: "F12", 113: "F15",
            115: "↖", 116: "⇞", 117: "⌦", 118: "F4", 119: "↘",
            120: "F2", 121: "⇟", 122: "F1",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return table[code] ?? "(\(code))"
    }

    // MARK: - Codable
    //
    // v1: id/enabled なし、キーは "keyCode" で 0 が「未設定」を意味していた。
    // v2: キーを "key" に変え、未設定はキー自体を書かない（0 は 'A' として有効な値になる）。
    // 旧キーで 0 が来た場合だけ未設定へ読み替えるため、キー名を分けて両方を読む。

    private enum CodingKeys: String, CodingKey {
        case id, gesture, modifierFlags, enabled
        case key
        case legacyKeyCode = "keyCode"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decodeIfPresent(UUID.self,       forKey: .id)            ?? UUID()
        gesture       = try c.decode(GestureType.self,         forKey: .gesture)
        modifierFlags = try c.decode(UInt64.self,              forKey: .modifierFlags)
        enabled       = try c.decodeIfPresent(Bool.self,       forKey: .enabled)       ?? true

        if let key = try c.decodeIfPresent(CGKeyCode.self, forKey: .key) {
            keyCode = key
        } else if let legacy = try c.decodeIfPresent(CGKeyCode.self, forKey: .legacyKeyCode) {
            keyCode = legacy == 0 ? nil : legacy
        } else {
            keyCode = nil
        }
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                     forKey: .id)
        try c.encode(gesture,                forKey: .gesture)
        try c.encodeIfPresent(keyCode,       forKey: .key)
        try c.encode(modifierFlags,          forKey: .modifierFlags)
        try c.encode(enabled,                forKey: .enabled)
    }
}

extension CGEventFlags {
    /// 修飾キーを ⌃⌥⇧⌘ の順で記号化したもの。ショートカット表示の組み立てに使う。
    var modifierSymbols: [String] {
        var syms: [String] = []
        if contains(.maskControl)   { syms.append("⌃") }
        if contains(.maskAlternate) { syms.append("⌥") }
        if contains(.maskShift)     { syms.append("⇧") }
        if contains(.maskCommand)   { syms.append("⌘") }
        return syms
    }
}
