import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let hosting = NSHostingController(rootView: SettingsView(configStore: .shared))
        let window = NSWindow(contentViewController: hosting)
        window.title = ""
        window.setContentSize(NSSize(width: 960, height: 660))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func presentSettings() {
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
