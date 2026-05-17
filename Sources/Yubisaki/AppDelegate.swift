import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private var gestureMonitor: GestureMonitor?
    private var appWatcher: AppWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager = MenuBarManager()
        PermissionManager.requestAuthorization()
        ConfigStore.shared.load()

        let watcher = AppWatcher()
        watcher.startWatching()
        appWatcher = watcher

        let monitor = GestureMonitor()
        monitor.onGestureDetected = { [weak self] gesture in
            guard let bundleID = self?.appWatcher?.frontmostBundleID else { return }
            guard let binding = ConfigStore.shared.binding(for: bundleID, gesture: gesture) else {
                print("[AppDelegate] No binding for \(gesture) in \(bundleID)")
                return
            }
            KeySender.send(keyCode: binding.keyCode, flags: binding.eventFlags)
        }
        monitor.startMonitoring()
        gestureMonitor = monitor
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        print("[AppDelegate] applicationShouldTerminate called")
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("[AppDelegate] applicationWillTerminate called")
        gestureMonitor?.stopMonitoring()
        appWatcher?.stopWatching()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
