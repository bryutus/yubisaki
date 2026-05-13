import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private var gestureMonitor: GestureMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager = MenuBarManager()
        PermissionManager.requestAuthorization()

        let monitor = GestureMonitor()
        monitor.onGestureDetected = { gesture in
            print("[AppDelegate] Detected: \(gesture)")
        }
        monitor.startMonitoring()
        gestureMonitor = monitor
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
