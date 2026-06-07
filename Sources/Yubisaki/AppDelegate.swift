import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var gestureMonitor: GestureMonitor?
    private var appWatcher: AppWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        PermissionManager.requestAuthorization()
        ConfigStore.shared.load()

        let watcher = AppWatcher()
        watcher.startWatching()
        appWatcher = watcher

        let monitor = GestureMonitor()
        monitor.shouldHandleGesture = { [weak watcher] in
            // CGEventTap スレッドから呼ばれる。メインへ同期せず、ロック保護のスナップショットを読む。
            // 使用可能な pinch バインディング(アプリ個別 or グローバル)がある時だけ消費し、
            // 未割当時はネイティブのピンチズームを温存する。
            let snapshot = ConfigStore.shared.gestureSnapshot()
            guard snapshot.gesturesEnabled else { return false }
            guard let bundleID = watcher?.frontmostBundleID else { return false }
            return snapshot.pinchBoundBundleIDs.contains(bundleID) || snapshot.globalHasPinchBinding
        }
        monitor.onGestureDetected = { [weak watcher] gesture in
            guard let bundleID = watcher?.frontmostBundleID else { return }
            guard let binding = ConfigStore.shared.binding(for: bundleID, gesture: gesture) else {
                return
            }
            KeySender.send(keyCode: binding.keyCode, flags: binding.eventFlags)
        }
        monitor.startMonitoring()
        gestureMonitor = monitor
    }

    func applicationWillTerminate(_ notification: Notification) {
        gestureMonitor?.stopMonitoring()
        appWatcher?.stopWatching()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
