import Foundation

struct AppProfile: Codable, Sendable, Identifiable {
    /// "すべてのアプリ" を表す共通プロファイルの bundleID。
    static let globalBundleID = "global"

    var id: String { bundleID }
    var bundleID: String
    var enabled: Bool
    var bindings: [GestureBinding]

    init(bundleID: String, enabled: Bool = true, bindings: [GestureBinding] = []) {
        self.bundleID = bundleID
        self.enabled = enabled
        self.bindings = bindings
    }

    /// このプロファイルで使用中のジェスチャー一覧。
    var usedGestures: Set<GestureType> { Set(bindings.map(\.gesture)) }

    /// 発火する順序（`ConfigStore.binding(for:gesture:)` は先勝ち）で、
    /// 既に先に有効なバインディングがあるために発火しないバインディングの id。
    /// Picker は新規の重複割り当てを防ぐが、config.json の手動編集等で
    /// 既存データに重複が紛れ込んだ場合はここで可視化する。
    var shadowedBindingIDs: Set<UUID> {
        var seenGestures: Set<GestureType> = []
        var shadowed: Set<UUID> = []
        for binding in bindings where binding.isUsable {
            if seenGestures.contains(binding.gesture) {
                shadowed.insert(binding.id)
            } else {
                seenGestures.insert(binding.gesture)
            }
        }
        return shadowed
    }

    // MARK: - Codable (migration from v1 format: no enabled)

    private enum CodingKeys: String, CodingKey {
        case bundleID, enabled, bindings
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try c.decode(String.self,              forKey: .bundleID)
        enabled  = try c.decodeIfPresent(Bool.self,       forKey: .enabled) ?? true
        bindings = try c.decode([GestureBinding].self,    forKey: .bindings)
    }
}
