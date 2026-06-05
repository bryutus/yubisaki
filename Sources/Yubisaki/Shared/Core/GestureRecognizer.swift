enum GestureRecognizer {
    private static let threshold: Double = 0.3

    static func recognize(magnitude: Double) -> GestureType? {
        if magnitude > threshold { return .pinchOut }
        if magnitude < -threshold { return .pinchIn }
        return nil
    }
}
