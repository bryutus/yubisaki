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
        nsView.onCapture = { code, flags in
            $keyCode.wrappedValue = code
            $modifierFlags.wrappedValue = flags.rawValue
        }
        nsView.needsDisplay = true
    }
}

final class KeyRecorderNSView: NSView {
    var currentKeyCode: CGKeyCode = 0
    var currentFlags: UInt64 = 0
    var onCapture: ((CGKeyCode, CGEventFlags) -> Void)?

    private var isRecording = false { didSet { needsDisplay = true } }
    private var pendingModifiers: NSEvent.ModifierFlags = [] { didSet { needsDisplay = true } }
    nonisolated(unsafe) private var blinkTimer: Timer?
    nonisolated(unsafe) private var localKeyMonitor: Any?
    private var blinkOn = true

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 200, height: 26) }

    private var clearButtonRect: NSRect {
        NSRect(x: bounds.maxX - 22, y: (bounds.height - 14) / 2, width: 14, height: 14)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if !isRecording && currentKeyCode != 0 && clearButtonRect.contains(point) {
            onCapture?(0, CGEventFlags(rawValue: 0))
            return
        }
        if isRecording {
            window?.makeFirstResponder(nil)
        } else {
            window?.makeFirstResponder(self)
        }
    }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        pendingModifiers = []
        isRecording = true
        startBlink()
        // Cmd+W など、メニューショートカットが keyDown より先に処理されるのを防ぐ。
        // ローカルモニターはメニュー処理より前に実行され、nil を返すことでイベントを消費する。
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            self.keyDown(with: event)
            return nil
        }
        return true
    }

    override func resignFirstResponder() -> Bool {
        guard super.resignFirstResponder() else { return false }
        isRecording = false
        pendingModifiers = []
        stopBlink()
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        return true
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else { return }
        pendingModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC — cancel, keep saved values
            window?.makeFirstResponder(nil)
            return
        }
        let flags = CGEventFlags(rawValue: UInt64(
            event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
        ))
        onCapture?(CGKeyCode(event.keyCode), flags)
        window?.makeFirstResponder(nil)
    }

    deinit {
        blinkTimer?.invalidate()
    }

    private func startBlink() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.blinkOn.toggle()
                self?.needsDisplay = true
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        blinkTimer = timer
    }

    private func stopBlink() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        blinkOn = true
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        let bgPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
        NSColor.controlBackgroundColor.setFill()
        bgPath.fill()

        let borderColor: NSColor = isRecording ? .controlAccentColor : .separatorColor
        borderColor.setStroke()
        bgPath.lineWidth = isRecording ? 1.5 : 0.5
        bgPath.stroke()

        let midY = bounds.midY

        if isRecording && !pendingModifiers.isEmpty {
            // State 3: modifier key pills + "+ ?" hint
            var x: CGFloat = 8
            for sym in modifierSymbols(for: pendingModifiers) {
                x = drawPill(sym, x: x, midY: midY) + 3
            }
            let hint = NSAttributedString(string: "+ ?", attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.tertiaryLabelColor
            ])
            hint.draw(at: NSPoint(x: x + 2, y: midY - hint.size().height / 2))

        } else if isRecording {
            // State 2: blinking red dot + prompt
            if blinkOn {
                NSColor.systemRed.setFill()
                NSBezierPath(ovalIn: NSRect(x: 8, y: midY - 3, width: 6, height: 6)).fill()
            }
            let label = NSAttributedString(string: L("shortcut.pressNewKey"), attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ])
            label.draw(at: NSPoint(x: 18, y: midY - label.size().height / 2))

        } else if currentKeyCode != 0 {
            // State 4: shortcut pills + × clear button
            var x: CGFloat = 8
            for part in shortcutParts() {
                x = drawPill(part, x: x, midY: midY) + 3
            }
            drawClearButton()

        } else {
            // State 1: italic placeholder
            let baseFont = NSFont.systemFont(ofSize: 11)
            let italicDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.italic)
            let italicFont = NSFont(descriptor: italicDescriptor, size: 11) ?? baseFont
            let placeholder = NSAttributedString(string: L("shortcut.clickToRecord"), attributes: [
                .font: italicFont,
                .foregroundColor: NSColor.tertiaryLabelColor
            ])
            placeholder.draw(at: NSPoint(x: 8, y: midY - placeholder.size().height / 2))
        }
    }

    @discardableResult
    private func drawPill(_ text: String, x: CGFloat, midY: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let textSize = str.size()
        let hPad: CGFloat = 5
        let pillH: CGFloat = 18
        let pillW = max(textSize.width + hPad * 2, pillH)
        let pillRect = NSRect(x: x, y: midY - pillH / 2, width: pillW, height: pillH)

        NSColor.tertiaryLabelColor.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: pillRect, xRadius: pillH / 2, yRadius: pillH / 2).fill()

        NSColor.separatorColor.setStroke()
        let borderPath = NSBezierPath(roundedRect: pillRect.insetBy(dx: 0.25, dy: 0.25), xRadius: pillH / 2, yRadius: pillH / 2)
        borderPath.lineWidth = 0.5
        borderPath.stroke()

        str.draw(at: NSPoint(x: x + (pillW - textSize.width) / 2, y: midY - textSize.height / 2))
        return x + pillW
    }

    private func drawClearButton() {
        let rect = clearButtonRect
        NSColor.tertiaryLabelColor.withAlphaComponent(0.35).setFill()
        NSBezierPath(ovalIn: rect).fill()

        let inset: CGFloat = 3.5
        let crossPath = NSBezierPath()
        crossPath.lineWidth = 1.4
        crossPath.lineCapStyle = .round
        crossPath.move(to: NSPoint(x: rect.minX + inset, y: rect.minY + inset))
        crossPath.line(to: NSPoint(x: rect.maxX - inset, y: rect.maxY - inset))
        crossPath.move(to: NSPoint(x: rect.maxX - inset, y: rect.minY + inset))
        crossPath.line(to: NSPoint(x: rect.minX + inset, y: rect.maxY - inset))
        NSColor.white.setStroke()
        crossPath.stroke()
    }

    // NSEvent.ModifierFlags の deviceIndependent なビットは CGEventFlags と同一値なので、
    // keyDown(with:) と同じ変換で CGEventFlags.modifierSymbols に寄せる。
    private func modifierSymbols(for flags: NSEvent.ModifierFlags) -> [String] {
        CGEventFlags(rawValue: UInt64(flags.rawValue)).modifierSymbols
    }

    private func shortcutParts() -> [String] {
        var parts = CGEventFlags(rawValue: currentFlags).modifierSymbols
        parts.append(GestureBinding.keyCodeString(currentKeyCode))
        return parts
    }
}
