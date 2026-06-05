import SwiftUI

extension Notification.Name {
    static let gesturesEnabledDidChange = Notification.Name("gesturesEnabledDidChange")
}

struct MenuBarContentView: View {
    private var configStore: ConfigStore = .shared
    @Environment(\.openSettings) private var openSettings

    private var enabled: Bool { configStore.preferences.gesturesEnabled }

    var body: some View {
        Label {
            Text(L(enabled ? "menu.status.running" : "menu.status.paused"))
        } icon: {
            Circle()
                .fill(enabled ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
        }
        .disabled(true)

        Divider()

        Button(L(enabled ? "menu.pause" : "menu.resume")) {
            configStore.preferences.gesturesEnabled.toggle()
            configStore.savePreferences()
            NotificationCenter.default.post(name: .gesturesEnabledDidChange, object: nil)
        }

        Divider()

        Button(L("menu.settings")) {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button(L("menu.quit")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
