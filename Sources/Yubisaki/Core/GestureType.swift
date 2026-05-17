enum GestureType: Codable, Sendable, Hashable, CaseIterable {
    case pinchIn
    case pinchOut

    var displayName: String {
        switch self {
        case .pinchIn: "ピンチイン"
        case .pinchOut: "ピンチアウト"
        }
    }
}
