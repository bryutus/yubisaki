import CoreGraphics

enum KeySender {
    static func send(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
    }
}
