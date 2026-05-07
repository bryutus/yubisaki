import AppKit

@MainActor
final class MenuBarManager {
    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setupButton()
        setupMenu()
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "hand.point.up", accessibilityDescription: "yubisaki")
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )
        statusItem.menu = menu
    }
}
