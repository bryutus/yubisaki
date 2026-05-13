import AppKit

final class AppWatcher: @unchecked Sendable {

    private(set) var frontmostBundleID: String?
    var onAppChanged: ((String?) -> Void)?

    private var observer: NSObjectProtocol?

    func startWatching() {
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier
            self?.frontmostBundleID = bundleID
            self?.onAppChanged?(bundleID)
        }
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
