import SwiftUI

@main
struct YubisakiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("yubisaki", systemImage: "hand.point.up") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(configStore: .shared)
        }
    }
}
