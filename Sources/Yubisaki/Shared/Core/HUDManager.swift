import AppKit
import SwiftUI

/// ジェスチャー検出時にHUD（実行したショートカット名）を画面に一時表示する。
@MainActor
final class HUDManager {
    static let shared = HUDManager()

    private static let displayDuration: Duration = .seconds(1.2)
    private static let fadeDuration: TimeInterval = 0.25

    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    private init() {}

    func present(gesture: GestureType, shortcutDescription: String) {
        guard !shortcutDescription.isEmpty else { return }

        hideTask?.cancel()

        let panel = panel ?? makePanel()
        self.panel = panel

        let hostingView = NSHostingView(
            rootView: HUDView(symbolName: gesture.sfSymbol, title: gesture.displayName, shortcut: shortcutDescription)
        )
        panel.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        position(panel, contentSize: hostingView.fittingSize)

        panel.alphaValue = 1
        panel.orderFrontRegardless()

        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.displayDuration)
            guard !Task.isCancelled else { return }
            self?.fadeOutAndHide()
        }
    }

    private func fadeOutAndHide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            panel.animator().alphaValue = 0
        } completionHandler: {
            // NSAnimationContext のコールバックはメインスレッドで呼ばれる
            MainActor.assumeIsolated {
                panel.orderOut(nil)
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    private func position(_ panel: NSPanel, contentSize: CGSize) {
        guard let screen = NSScreen.main else { return }
        panel.setContentSize(contentSize)
        let frame = screen.visibleFrame
        let origin = CGPoint(
            x: frame.midX - contentSize.width / 2,
            y: frame.minY + frame.height * 0.22
        )
        panel.setFrameOrigin(origin)
    }
}
