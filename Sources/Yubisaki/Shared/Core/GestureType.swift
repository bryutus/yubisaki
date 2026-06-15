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
    case twoTipTapLeft, twoTipTapRight

    // 3-finger
    case threeTap

    // 4-finger
    case fourTap

    var group: GestureGroup {
        switch self {
        case .pinchIn, .pinchOut, .twoTipTapLeft, .twoTipTapRight:
            return .twoFinger
        case .threeTap:
            return .threeFinger
        case .fourTap:
            return .fourFinger
        }
    }

    var displayName: String { L(localizationKey) }

    var sfSymbol: String {
        switch self {
        case .pinchIn:         return "arrow.down.right.and.arrow.up.left"
        case .pinchOut:        return "arrow.up.left.and.arrow.down.right"
        case .twoTipTapLeft:   return "hand.tap"
        case .twoTipTapRight:  return "hand.tap"
        case .threeTap:        return "3.circle"
        case .fourTap:         return "4.circle"
        }
    }

    private var localizationKey: String {
        switch self {
        case .pinchIn:         return "gesture.pinchIn"
        case .pinchOut:        return "gesture.pinchOut"
        case .twoTipTapLeft:   return "gesture.twoTipTapLeft"
        case .twoTipTapRight:  return "gesture.twoTipTapRight"
        case .threeTap:        return "gesture.threeTap"
        case .fourTap:         return "gesture.fourTap"
        }
    }
}
