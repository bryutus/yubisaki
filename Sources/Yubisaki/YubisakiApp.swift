import SwiftUI

@main
struct YubisakiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
        } label: {
            templateIcon(named: "menuBarIcon", pointSize: 18)
                .accessibilityLabel(Text("yubisaki"))
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(configStore: .shared)
        }
    }
}
