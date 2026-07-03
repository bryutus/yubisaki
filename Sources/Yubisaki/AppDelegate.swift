import AppKit
import ServiceManagement
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "yubisaki", category: "AppDelegate")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var gestureMonitor: GestureMonitor?
    private var appWatcher: AppWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        PermissionManager.requestAuthorization()
        ConfigStore.shared.load()
        applyStartupPreferences()

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
            guard let binding = ConfigStore.shared.binding(for: bundleID, gesture: gesture) else { return }
            logger.info("Sending \(String(describing: gesture), privacy: .public) → keyCode \(binding.keyCode) to \(bundleID, privacy: .public)")
            KeySender.send(keyCode: binding.keyCode, flags: binding.eventFlags)
            if ConfigStore.shared.preferences.hudEnabled {
                HUDManager.shared.present(gesture: gesture, shortcutDescription: binding.shortcutDescription)
            }
        }
        monitor.startMonitoring()
        gestureMonitor = monitor
    }

    private func applyStartupPreferences() {
        let prefs = ConfigStore.shared.preferences

        // SMAppService の実態と保存値を同期（ユーザーがシステム設定で手動変更した場合に対応）
        let isRegistered = SMAppService.mainApp.status == .enabled
        if prefs.launchAtLogin != isRegistered {
            ConfigStore.shared.preferences.launchAtLogin = isRegistered
            ConfigStore.shared.savePreferences()
        }

        if prefs.showInDock {
            NSApp.setActivationPolicy(.regular)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        gestureMonitor?.stopMonitoring()
        appWatcher?.stopWatching()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
