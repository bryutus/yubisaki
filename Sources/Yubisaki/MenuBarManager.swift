import AppKit

@MainActor
final class MenuBarManager: NSObject {
    private let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        setupButton()
        setupMenu()
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "hand.point.up", accessibilityDescription: "yubisaki")
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
