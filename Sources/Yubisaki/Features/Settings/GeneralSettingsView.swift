import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @Bindable var configStore: ConfigStore
    @State private var accessibilityGranted = false
    @State private var inputMonitoringGranted = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FormGroupView(topPadding: 2) {
                    ToggleRowView(label: L("general.launchAtLogin"), hint: L("general.launchAtLoginHint"), isOn: $configStore.preferences.launchAtLogin)
                    Color(nsColor: .separatorColor).frame(height: 0.5).padding(.horizontal, 16)
                    ToggleRowView(label: L("general.showMenuBar"), hint: L("general.showMenuBarHint"), isOn: $configStore.preferences.showMenuBar)
                    Color(nsColor: .separatorColor).frame(height: 0.5).padding(.horizontal, 16)
                    ToggleRowView(label: L("general.showInDock"), isOn: $configStore.preferences.showInDock)
                }

                FormGroupView(title: L("general.section.gestures")) {
                    ToggleRowView(label: L("general.gesturesEnabled"), hint: L("general.gesturesEnabledHint"), isOn: $configStore.preferences.gesturesEnabled)
                }

                FormGroupView(title: L("general.section.permissions")) {
                    PermissionRowView(
                        label: L("general.accessibility"),
                        hint: L("general.accessibilityHint"),
                        granted: accessibilityGranted,
                        showOpenButton: true
                    )
                    Color(nsColor: .separatorColor).frame(height: 0.5).padding(.horizontal, 16)
                    PermissionRowView(
                        label: L("general.inputMonitoring"),
                        granted: inputMonitoringGranted,
                        showOpenButton: false
                    )
                }

                HStack(spacing: 6) {
                    Text("yubisaki · \(appVersion)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button(L("general.footer.help")) {}
                        .buttonStyle(.link)
                        .font(.caption)
                    Text("·").foregroundStyle(.tertiary).font(.caption)
                    Button(L("general.footer.privacy")) {}
                        .buttonStyle(.link)
                        .font(.caption)
                    Text("·").foregroundStyle(.tertiary).font(.caption)
                    Button(L("general.footer.reset")) {}
                        .buttonStyle(.link)
                        .font(.caption)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .background(Color(red: 236/255, green: 237/255, blue: 236/255))
        .onAppear {
            accessibilityGranted = PermissionManager.isAccessibilityGranted
            inputMonitoringGranted = PermissionManager.isInputMonitoringGranted
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            accessibilityGranted = PermissionManager.isAccessibilityGranted
            inputMonitoringGranted = PermissionManager.isInputMonitoringGranted
        }
        .onChange(of: configStore.preferences) { old, new in
            configStore.savePreferences()
            if old.gesturesEnabled != new.gesturesEnabled {
                NotificationCenter.default.post(name: .gesturesEnabledDidChange, object: nil)
            }
        }
    }
}

// MARK: - Form Group

private struct FormGroupView<Content: View>: View {
    var title: String? = nil
    var topPadding: CGFloat = 20
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.leading, 16)
                    .padding(.bottom, 6)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(Color(red: 232/255, green: 233/255, blue: 232/255))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator.opacity(0.6), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
    }
}

// MARK: - Toggle Row

private struct ToggleRowView: View {
    let label: String
    var hint: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.body)
                if let hint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

// MARK: - Permission Row

private struct PermissionRowView: View {
    let label: String
    var hint: String? = nil
    let granted: Bool
    let showOpenButton: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(label).font(.body)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(granted ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(granted ? L("general.permissionGranted") : L("general.permissionDenied"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if showOpenButton {
                        Button(L("general.openSystemSettings")) {
                            PermissionManager.openSystemSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 11)
            }
        }
    }
}
