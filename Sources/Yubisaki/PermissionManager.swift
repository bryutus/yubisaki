import AppKit
@preconcurrency import ApplicationServices
import IOKit.hid

@MainActor
enum PermissionManager {

    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    static var isInputMonitoringGranted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    static func openSystemSettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    static func requestAuthorization() {
        requestAccessibility()
        requestInputMonitoring()
    }

    private static func requestAccessibility() {
        guard !AXIsProcessTrusted() else { return }
        _ = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        )
    }

    private static func requestInputMonitoring() {
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        guard access != kIOHIDAccessTypeGranted else { return }

        if access == kIOHIDAccessTypeDenied {
            presentSettingsAlert()
        } else {
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        }
    }

    private static func presentSettingsAlert() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = L("permission.inputMonitoring.title")
        alert.informativeText = L("permission.inputMonitoring.message")
        alert.addButton(withTitle: L("permission.openSystemSettings"))
        alert.addButton(withTitle: L("permission.later"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
            )
        }
    }
}
