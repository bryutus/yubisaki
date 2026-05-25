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
        alert.messageText = "入力監視の権限が必要です"
        alert.informativeText = "システム設定 > プライバシーとセキュリティ > 入力監視 で yubisaki を許可してください。"
        alert.addButton(withTitle: "システム設定を開く")
        alert.addButton(withTitle: "後で")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
            )
        }
    }
}
