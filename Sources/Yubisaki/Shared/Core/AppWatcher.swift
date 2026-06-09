import AppKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "yubisaki", category: "AppWatcher")

final class AppWatcher: @unchecked Sendable {

    // CGEventTap スレッドからも読むため、ロックで保護する（書き込みはメインのみ）。
    private let frontmostBundleIDLock = OSAllocatedUnfairLock(initialState: String?.none)
    var frontmostBundleID: String? { frontmostBundleIDLock.withLock { $0 } }
    var onAppChanged: ((String?) -> Void)?

    private var observer: NSObjectProtocol?

    func startWatching() {
        setFrontmostBundleID(NSWorkspace.shared.frontmostApplication?.bundleIdentifier)

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier
            self?.setFrontmostBundleID(bundleID)
            logger.debug("Frontmost app: \(bundleID ?? "nil", privacy: .public)")
            self?.onAppChanged?(bundleID)
        }
    }

    private func setFrontmostBundleID(_ bundleID: String?) {
        frontmostBundleIDLock.withLock { $0 = bundleID }
    }

    func stopWatching() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    deinit {
        stopWatching()
    }
}
