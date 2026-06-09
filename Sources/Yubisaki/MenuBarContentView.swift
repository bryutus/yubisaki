import SwiftUI

extension Notification.Name {
    static let gesturesEnabledDidChange = Notification.Name("gesturesEnabledDidChange")
}

struct MenuBarContentView: View {
    private var configStore: ConfigStore = .shared
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Toggle(L("general.gesturesEnabled"), isOn: Binding(
            get: { configStore.preferences.gesturesEnabled },
            set: {
                configStore.preferences.gesturesEnabled = $0
                configStore.savePreferences()
                NotificationCenter.default.post(name: .gesturesEnabledDidChange, object: nil)
            }
        ))

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
