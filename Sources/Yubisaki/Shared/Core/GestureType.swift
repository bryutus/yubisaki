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
}
