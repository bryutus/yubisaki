enum GestureGroup: CaseIterable, Sendable {
    case twoFinger, threeFinger, fourFinger

    var displayName: String { L(localizationKey) }

    private var localizationKey: String {
        switch self {
        case .twoFinger:   return "gesture.group.twoFinger"
        case .threeFinger: return "gesture.group.threeFinger"
        case .fourFinger:  return "gesture.group.fourFinger"
        }
    }
}

enum GestureType: Codable, Sendable, Hashable, CaseIterable {
    // 2-finger
    case pinchIn, pinchOut
    case twoHoldTapLeft, twoHoldTapRight

    // 3-finger
    case threeTap

    // 4-finger
    case fourTap

    var group: GestureGroup {
        switch self {
        case .pinchIn, .pinchOut, .twoHoldTapLeft, .twoHoldTapRight:
            return .twoFinger
        case .threeTap:
            return .threeFinger
        case .fourTap:
            return .fourFinger
        }
    }

    var displayName: String { L(localizationKey) }

    /// `Sources/Yubisaki/Resources/Icons/` 内の独自アイコン画像名（`scripts/make-gesture-icons.swift` で生成）
    var iconName: String {
        switch self {
        case .pinchIn:          return "pinchIn"
        case .pinchOut:         return "pinchOut"
        case .twoHoldTapLeft:   return "twoHoldTapLeft"
        case .twoHoldTapRight:  return "twoHoldTapRight"
        case .threeTap:         return "threeTap"
        case .fourTap:          return "fourTap"
        }
    }

    private var localizationKey: String {
        switch self {
        case .pinchIn:          return "gesture.pinchIn"
        case .pinchOut:         return "gesture.pinchOut"
        case .twoHoldTapLeft:   return "gesture.twoHoldTapLeft"
        case .twoHoldTapRight:  return "gesture.twoHoldTapRight"
        case .threeTap:         return "gesture.threeTap"
        case .fourTap:          return "gesture.fourTap"
        }
    }

    // MARK: - Codable

    /// config.json 上の名前。合成 Codable と同じ `{"<名前>":{}}` 形式を保つため、
    /// 既存の設定ファイルとの互換性を壊さずにケース名だけを改名できる。
    private var persistedName: String {
        switch self {
        case .pinchIn:          return "pinchIn"
        case .pinchOut:         return "pinchOut"
        case .twoHoldTapLeft:   return "twoHoldTapLeft"
        case .twoHoldTapRight:  return "twoHoldTapRight"
        case .threeTap:         return "threeTap"
        case .fourTap:          return "fourTap"
        }
    }

    /// 旧名 → 現行ケース（チップタップ（TipTap）からホールドタップ（HoldTap）への改名に伴う移行）
    private static let legacyNames: [String: GestureType] = [
        "twoTipTapLeft":  .twoHoldTapLeft,
        "twoTipTapRight": .twoHoldTapRight,
    ]

    private struct NameKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }

        init(_ name: String) { stringValue = name }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: NameKey.self)
        guard let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "ジェスチャー名が空です"
            ))
        }
        if let match = Self.allCases.first(where: { $0.persistedName == key.stringValue }) {
            self = match
        } else if let migrated = Self.legacyNames[key.stringValue] {
            self = migrated
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: container,
                debugDescription: "未知のジェスチャー: \(key.stringValue)"
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: NameKey.self)
        _ = container.nestedContainer(keyedBy: NameKey.self, forKey: NameKey(persistedName))
    }
}
