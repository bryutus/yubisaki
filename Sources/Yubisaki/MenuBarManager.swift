import AppKit

private func colorDot(_ color: NSColor, size: CGFloat = 12) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        color.setFill()
        NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
        return true
    }
    image.isTemplate = false
    return image
}

@MainActor
final class MenuBarManager: NSObject {
    private let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        setupButton()
        buildMenu()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(buildMenu),
            name: .gesturesEnabledDidChange,
            object: nil
        )
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "hand.point.up", accessibilityDescription: "yubisaki")
    }

    @objc func buildMenu() {
        let enabled = ConfigStore.shared.preferences.gesturesEnabled
        let menu = NSMenu()
        menu.autoenablesItems = false

        let statusItem = NSMenuItem(
            title: String(localized: enabled ? "menu.status.running" : "menu.status.paused", bundle: .module),
            action: nil,
            keyEquivalent: ""
        )
        statusItem.image = colorDot(enabled ? .systemGreen : .systemOrange)
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: String(localized: enabled ? "menu.pause" : "menu.resume", bundle: .module),
            action: #selector(toggleGestures),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.isEnabled = true
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: String(localized: "menu.settings", bundle: .module),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.isEnabled = true
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: String(localized: "menu.quit", bundle: .module),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc private func toggleGestures() {
        ConfigStore.shared.preferences.gesturesEnabled.toggle()
        ConfigStore.shared.savePreferences()
        NotificationCenter.default.post(name: .gesturesEnabledDidChange, object: nil)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.presentSettings()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

extension Notification.Name {
    static let gesturesEnabledDidChange = Notification.Name("gesturesEnabledDidChange")
}
