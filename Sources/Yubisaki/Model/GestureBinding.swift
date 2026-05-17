import CoreGraphics

struct GestureBinding: Codable, Sendable {
    var gesture: GestureType
    var keyCode: CGKeyCode
    var modifierFlags: UInt64

    var eventFlags: CGEventFlags { CGEventFlags(rawValue: modifierFlags) }
}
