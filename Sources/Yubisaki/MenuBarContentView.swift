import SwiftUI
import AppKit

struct MenuBarContentView: View {
    private var configStore: ConfigStore = .shared
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Toggle(L("general.gesturesEnabled"), isOn: Binding(
            get: { configStore.preferences.gesturesEnabled },
            set: {
                configStore.preferences.gesturesEnabled = $0
                configStore.savePreferences()
            }
        ))

        Divider()

        Button(L("menu.settings")) {
            // アクセサリアプリは macOS 14+ の協調的アクティベーションでアクティブ化が
            // 拒否されることがあり、設定ウィンドウが表示されてもキー入力が直前のアプリへ
            // 流れてしまう（ショートカット記録が効かない）。設定ウィンドウの表示中だけ
            // .regular に切り替えて確実にアクティブ化する（閉じる時に SettingsView 側で戻す）。
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows
                    .first { $0.identifier?.rawValue.contains("Settings") == true }?
                    .makeKeyAndOrderFront(nil)
            }
        }
        .keyboardShortcut(",", modifiers: .command)

        Button(L("menu.quit")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
