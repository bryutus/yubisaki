import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private var gestureMonitor: GestureMonitor?
    private var appWatcher: AppWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager = MenuBarManager()
        PermissionManager.requestAuthorization()

        let watcher = AppWatcher()
        watcher.startWatching()
        appWatcher = watcher

        let monitor = GestureMonitor()
        monitor.onGestureDetected = { [weak self] gesture in
            let bundleID = self?.appWatcher?.frontmostBundleID ?? "unknown"
            print("[AppDelegate] \(gesture) in \(bundleID)")
        }
        monitor.startMonitoring()
        gestureMonitor = monitor
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
