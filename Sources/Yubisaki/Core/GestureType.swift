enum GestureGroup: CaseIterable, Sendable {
    case twoFinger, threeFinger, fourFinger, fiveFinger, force, corner

    var displayName: String { L(localizationKey) }

    private var localizationKey: String {
        switch self {
        case .twoFinger:   return "gesture.group.twoFinger"
        case .threeFinger: return "gesture.group.threeFinger"
        case .fourFinger:  return "gesture.group.fourFinger"
        case .fiveFinger:  return "gesture.group.fiveFinger"
        case .force:       return "gesture.group.force"
        case .corner:      return "gesture.group.corner"
        }
    }
}

enum GestureType: Codable, Sendable, Hashable, CaseIterable {
    // 2-finger
    case pinchIn, pinchOut
    case rotateCW, rotateCCW
    case twoTipTapLeft, twoTipTapRight
    case twoDoubleTap
    case twoSwipeUp, twoSwipeDown

    // 3-finger
    case threeTap, threeDoubleTap, threeClick
    case threeSwipeUp, threeSwipeDown, threeSwipeLeft, threeSwipeRight
    case threeTipTapLeft, threeTipTapRight

    // 4-finger
    case fourTap, fourDoubleTap
    case fourSwipeUp, fourSwipeDown, fourSwipeLeft, fourSwipeRight

    // 5-finger
    case fiveTap, fivePinchIn, fiveSpread

    // Force
    case forceClick, forceDrag

    // Corner
    case cornerTopLeft, cornerTopRight, cornerBottomLeft, cornerBottomRight

    var group: GestureGroup {
        switch self {
        case .pinchIn, .pinchOut, .rotateCW, .rotateCCW,
             .twoTipTapLeft, .twoTipTapRight, .twoDoubleTap,
             .twoSwipeUp, .twoSwipeDown:
            return .twoFinger
        case .threeTap, .threeDoubleTap, .threeClick,
             .threeSwipeUp, .threeSwipeDown, .threeSwipeLeft, .threeSwipeRight,
             .threeTipTapLeft, .threeTipTapRight:
            return .threeFinger
        case .fourTap, .fourDoubleTap,
             .fourSwipeUp, .fourSwipeDown, .fourSwipeLeft, .fourSwipeRight:
            return .fourFinger
        case .fiveTap, .fivePinchIn, .fiveSpread:
            return .fiveFinger
        case .forceClick, .forceDrag:
            return .force
        case .cornerTopLeft, .cornerTopRight, .cornerBottomLeft, .cornerBottomRight:
            return .corner
        }
    }

    var displayName: String { L(localizationKey) }

    var sfSymbol: String {
        switch self {
        case .pinchIn:           return "arrow.down.right.and.arrow.up.left"
        case .pinchOut:          return "arrow.up.left.and.arrow.down.right"
        case .rotateCW:          return "arrow.clockwise"
        case .rotateCCW:         return "arrow.counterclockwise"
        case .twoTipTapLeft:     return "hand.tap"
        case .twoTipTapRight:    return "hand.tap"
        case .twoDoubleTap:      return "hand.tap"
        case .twoSwipeUp:        return "arrow.up"
        case .twoSwipeDown:      return "arrow.down"
        case .threeTap:          return "3.circle"
        case .threeDoubleTap:    return "3.circle"
        case .threeClick:        return "hand.point.up"
        case .threeSwipeUp:      return "arrow.up.circle"
        case .threeSwipeDown:    return "arrow.down.circle"
        case .threeSwipeLeft:    return "arrow.left.circle"
        case .threeSwipeRight:   return "arrow.right.circle"
        case .threeTipTapLeft:   return "3.circle"
        case .threeTipTapRight:  return "3.circle"
        case .fourTap:           return "4.circle"
        case .fourDoubleTap:     return "4.circle"
        case .fourSwipeUp:       return "arrow.up.square"
        case .fourSwipeDown:     return "arrow.down.square"
        case .fourSwipeLeft:     return "arrow.left.square"
        case .fourSwipeRight:    return "arrow.right.square"
        case .fiveTap:           return "5.circle"
        case .fivePinchIn:       return "arrow.down.right.and.arrow.up.left"
        case .fiveSpread:        return "arrow.up.left.and.arrow.down.right"
        case .forceClick:        return "hand.point.up.fill"
        case .forceDrag:         return "hand.draw"
        case .cornerTopLeft:     return "arrow.up.left.square"
        case .cornerTopRight:    return "arrow.up.right.square"
        case .cornerBottomLeft:  return "arrow.down.left.square"
        case .cornerBottomRight: return "arrow.down.right.square"
        }
    }

    private var localizationKey: String {
        switch self {
        case .pinchIn:           return "gesture.pinchIn"
        case .pinchOut:          return "gesture.pinchOut"
        case .rotateCW:          return "gesture.rotateCW"
        case .rotateCCW:         return "gesture.rotateCCW"
        case .twoTipTapLeft:     return "gesture.twoTipTapLeft"
        case .twoTipTapRight:    return "gesture.twoTipTapRight"
        case .twoDoubleTap:      return "gesture.twoDoubleTap"
        case .twoSwipeUp:        return "gesture.twoSwipeUp"
        case .twoSwipeDown:      return "gesture.twoSwipeDown"
        case .threeTap:          return "gesture.threeTap"
        case .threeDoubleTap:    return "gesture.threeDoubleTap"
        case .threeClick:        return "gesture.threeClick"
        case .threeSwipeUp:      return "gesture.threeSwipeUp"
        case .threeSwipeDown:    return "gesture.threeSwipeDown"
        case .threeSwipeLeft:    return "gesture.threeSwipeLeft"
        case .threeSwipeRight:   return "gesture.threeSwipeRight"
        case .threeTipTapLeft:   return "gesture.threeTipTapLeft"
        case .threeTipTapRight:  return "gesture.threeTipTapRight"
        case .fourTap:           return "gesture.fourTap"
        case .fourDoubleTap:     return "gesture.fourDoubleTap"
        case .fourSwipeUp:       return "gesture.fourSwipeUp"
        case .fourSwipeDown:     return "gesture.fourSwipeDown"
        case .fourSwipeLeft:     return "gesture.fourSwipeLeft"
        case .fourSwipeRight:    return "gesture.fourSwipeRight"
        case .fiveTap:           return "gesture.fiveTap"
        case .fivePinchIn:       return "gesture.fivePinchIn"
        case .fiveSpread:        return "gesture.fiveSpread"
        case .forceClick:        return "gesture.forceClick"
        case .forceDrag:         return "gesture.forceDrag"
        case .cornerTopLeft:     return "gesture.cornerTopLeft"
        case .cornerTopRight:    return "gesture.cornerTopRight"
        case .cornerBottomLeft:  return "gesture.cornerBottomLeft"
        case .cornerBottomRight: return "gesture.cornerBottomRight"
        }
    }
}
