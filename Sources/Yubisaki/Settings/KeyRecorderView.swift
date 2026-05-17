import SwiftUI
import CoreGraphics
import AppKit

struct KeyRecorderView: NSViewRepresentable {
    @Binding var keyCode: CGKeyCode
    @Binding var modifierFlags: UInt64

    func makeNSView(context: Context) -> KeyRecorderNSView {
        KeyRecorderNSView()
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        nsView.currentKeyCode = keyCode
        nsView.currentFlags = modifierFlags
        let keyCodeBinding = $keyCode
        let flagsBinding = $modifierFlags
        nsView.onCapture = { code, flags in
            keyCodeBinding.wrappedValue = code
            flagsBinding.wrappedValue = flags.rawValue
        }
        nsView.needsDisplay = true
    }
}

final class KeyRecorderNSView: NSView {
    var currentKeyCode: CGKeyCode = 0
    var currentFlags: UInt64 = 0
    var onCapture: ((CGKeyCode, CGEventFlags) -> Void)?

    private var isRecording = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 200, height: 28) }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            window?.makeFirstResponder(nil)
        } else {
            window?.makeFirstResponder(self)
        }
    }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        isRecording = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        guard super.resignFirstResponder() else { return false }
        isRecording = false
        return true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            window?.makeFirstResponder(nil)
            return
        }
        let flags = CGEventFlags(rawValue: UInt64(
            event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
        ))
        let code = CGKeyCode(event.keyCode)
        onCapture?(code, flags)
        window?.makeFirstResponder(nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)

        let bg: NSColor = isRecording
            ? .controlAccentColor.withAlphaComponent(0.15)
            : .controlBackgroundColor
        bg.setFill()
        path.fill()

        let border: NSColor = isRecording ? .controlAccentColor : .separatorColor
        border.setStroke()
        path.lineWidth = isRecording ? 2 : 1
        path.stroke()

        let text: String
        let textColor: NSColor
        if isRecording {
            text = "録音中... (ESC でキャンセル)"
            textColor = .controlAccentColor
        } else if currentKeyCode == 0 {
            text = "クリックして録音"
            textColor = .placeholderTextColor
        } else {
            text = shortcutString(keyCode: currentKeyCode, flags: CGEventFlags(rawValue: currentFlags))
            textColor = .labelColor
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: textColor,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        str.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2))
    }

    private func shortcutString(keyCode: CGKeyCode, flags: CGEventFlags) -> String {
        var parts: [String] = []
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }
        parts.append(GestureBinding.keyCodeString(keyCode))
        return parts.joined()
    }
}
