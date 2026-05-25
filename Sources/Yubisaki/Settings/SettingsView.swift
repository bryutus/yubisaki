import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable {
    case gestures = "ジェスチャー"
    case general = "一般"
}

struct SettingsView: View {
    @ObservedObject var configStore: ConfigStore
    @State private var selectedTab: SettingsTab = .gestures

    var body: some View {
        Group {
            switch selectedTab {
            case .gestures:
                GesturesTabView(configStore: configStore)
            case .general:
                GeneralTabView(configStore: configStore)
            }
        }
        .frame(minWidth: 960, minHeight: 660)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $selectedTab) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .labelsHidden()
            }
        }
    }
}

// MARK: - Gestures Tab

private struct GesturesTabView: View {
    @ObservedObject var configStore: ConfigStore
    @State private var selectedBundleID: String? = "global"

    var body: some View {
        NavigationSplitView {
            appList
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            detailPane
        }
    }

    // MARK: - Sidebar

    private var appList: some View {
        List(selection: $selectedBundleID) {
            Section {
                AppRowView(
                    bundleID: "global",
                    enabledCount: configStore.globalProfile.bindings.filter(\.enabled).count
                )
                .tag("global")
            } header: {
                sectionHeader(Text(L("sidebar.section.system")))
            }

            Section {
                ForEach(configStore.profiles) { profile in
                    AppRowView(
                        bundleID: profile.bundleID,
                        enabledCount: profile.bindings.filter(\.enabled).count
                    )
                    .tag(profile.bundleID)
                }
            } header: {
                sectionHeader(Text(L("sidebar.section.applications")))
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: addApp) {
                    Image(systemName: "plus")
                }
                Button(action: removeSelected) {
                    Image(systemName: "minus")
                }
                .disabled(selectedBundleID == nil || selectedBundleID == "global")
            }
        }
    }

    private func sectionHeader(_ label: Text) -> some View {
        label
            .font(.system(size: 10, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(.secondary)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if selectedBundleID == "global" {
            BindingsView(
                profile: Binding(
                    get: { configStore.globalProfile },
                    set: {
                        configStore.globalProfile = $0
                        configStore.save()
                    }
                )
            )
        } else if let id = selectedBundleID,
                  let index = configStore.profiles.firstIndex(where: { $0.bundleID == id }) {
            BindingsView(
                profile: Binding(
                    get: { configStore.profiles[index] },
                    set: {
                        configStore.profiles[index] = $0
                        configStore.save()
                    }
                )
            )
        } else {
            Text("左のリストからアプリを選択してください")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier else { return }
            guard !configStore.profiles.contains(where: { $0.bundleID == bundleID }) else { return }
            configStore.profiles.append(AppProfile(bundleID: bundleID, bindings: []))
            configStore.save()
            selectedBundleID = bundleID
        }
    }

    private func removeSelected() {
        guard let id = selectedBundleID else { return }
        configStore.profiles.removeAll { $0.bundleID == id }
        configStore.save()
        selectedBundleID = nil
    }
}

// MARK: - App Row

private struct AppRowView: View {
    let bundleID: String
    let enabledCount: Int

    private var isGlobal: Bool { bundleID == "global" }

    private var appURL: URL? {
        isGlobal ? nil : NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    private var appName: String {
        if isGlobal { return L("sidebar.allApps") }
        return appURL.map { $0.deletingPathExtension().lastPathComponent } ?? bundleID
    }

    var body: some View {
        HStack(spacing: 8) {
            appIconView
            Text(appName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            Spacer()
            if enabledCount > 0 {
                Text("\(enabledCount)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var appIconView: some View {
        if let url = appURL {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 20, height: 20)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .tertiaryLabelColor).opacity(0.25))
                    .frame(width: 20, height: 20)
                Image(systemName: "hand.draw")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Bindings View

private struct BindingsView: View {
    @Binding var profile: AppProfile
    @State private var selectedBindingID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            AppHeaderView(
                bundleID: profile.bundleID,
                isGlobalProfile: profile.bundleID == "global",
                enabled: $profile.enabled
            )
            Divider()
            ColumnHeaderRow()
            Divider()
            Group {
                if profile.bindings.isEmpty {
                    Text("ジェスチャーバインディングがありません")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach($profile.bindings) { $binding in
                                BindingRowView(
                                    binding: $binding,
                                    isSelected: selectedBindingID == binding.id,
                                    onSelect: { selectedBindingID = binding.id }
                                )
                                Divider()
                            }
                        }
                    }
                }
            }
            .opacity(profile.enabled ? 1.0 : 0.55)
            Divider()
            BindingsFooter(profile: $profile, selectedBindingID: $selectedBindingID)
        }
    }
}

// MARK: - App Header

private struct AppHeaderView: View {
    let bundleID: String
    let isGlobalProfile: Bool
    @Binding var enabled: Bool

    private var appURL: URL? {
        isGlobalProfile ? nil : NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    private var appName: String {
        if isGlobalProfile { return L("sidebar.allApps") }
        return appURL.map { $0.deletingPathExtension().lastPathComponent } ?? bundleID
    }

    private var toggleLabel: String {
        isGlobalProfile ? L("gestures.gesturesEnabled") : L("gestures.enabledForApp")
    }

    var body: some View {
        HStack(spacing: 12) {
            appIconView
            Text(appName)
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Text(toggleLabel)
                .font(.system(size: 12))
            Toggle("", isOn: $enabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var appIconView: some View {
        if let url = appURL {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 44, height: 44)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .tertiaryLabelColor).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "hand.draw")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Column Header Row

private struct ColumnHeaderRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 14, height: 1) // checkbox space
            Text(L("gestures.column.gesture"))
                .frame(width: 200, alignment: .leading)
            Text(L("gestures.column.shortcut"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L("gestures.column.note"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 10, weight: .bold))
        .tracking(0.3)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .frame(height: 28)
    }
}

// MARK: - Binding Row

private struct BindingRowView: View {
    @Binding var binding: GestureBinding
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $binding.enabled)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .frame(width: 14)

            Picker("", selection: $binding.gesture) {
                ForEach(GestureGroup.allCases, id: \.self) { group in
                    Section(group.displayName) {
                        ForEach(
                            GestureType.allCases.filter { $0.group == group },
                            id: \.self
                        ) { gesture in
                            Label(gesture.displayName, systemImage: gesture.sfSymbol)
                                .tag(gesture)
                        }
                    }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 200)

            KeyRecorderView(keyCode: $binding.keyCode, modifierFlags: $binding.modifierFlags)
                .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 28)

            TextField(L("gestures.column.note"), text: $binding.note)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { onSelect() })
    }
}

// MARK: - Bindings Footer

private struct BindingsFooter: View {
    @Binding var profile: AppProfile
    @Binding var selectedBindingID: UUID?

    private var enabledCount: Int { profile.bindings.filter(\.enabled).count }

    var body: some View {
        HStack(spacing: 2) {
            Button(action: addBinding) { Image(systemName: "plus") }
                .buttonStyle(.plain)
                .padding(6)

            Button(action: deleteSelected) { Image(systemName: "minus") }
                .buttonStyle(.plain)
                .padding(6)
                .disabled(selectedBindingID == nil)

            Spacer()

            if !profile.bindings.isEmpty {
                Text(String(format: L("gestures.activeCount"), enabledCount))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 16)
            }
        }
        .padding(.leading, 8)
        .frame(height: 36)
    }

    private func addBinding() {
        let used = Set(profile.bindings.map(\.gesture))
        let gesture = GestureType.allCases.first { !used.contains($0) } ?? .pinchIn
        let newBinding = GestureBinding(gesture: gesture, enabled: false)
        profile.bindings.append(newBinding)
        selectedBindingID = newBinding.id
    }

    private func deleteSelected() {
        guard let id = selectedBindingID else { return }
        profile.bindings.removeAll { $0.id == id }
        selectedBindingID = nil
    }
}

// MARK: - General Tab

private struct GeneralTabView: View {
    @ObservedObject var configStore: ConfigStore
    @State private var accessibilityGranted = false
    @State private var inputMonitoringGranted = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FormGroupView {
                    ToggleRowView(label: L("general.launchAtLogin"), hint: L("general.launchAtLoginHint"), isOn: $configStore.preferences.launchAtLogin)
                    Divider()
                    ToggleRowView(label: L("general.showMenuBar"), hint: L("general.showMenuBarHint"), isOn: $configStore.preferences.showMenuBar)
                    Divider()
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
                    Divider()
                    PermissionRowView(
                        label: L("general.inputMonitoring"),
                        granted: inputMonitoringGranted,
                        showOpenButton: false
                    )
                }

                HStack(spacing: 6) {
                    Text("yubisaki · \(appVersion)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button(L("general.footer.help")) {}
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                    Text("·").foregroundStyle(.tertiary).font(.system(size: 11))
                    Button(L("general.footer.privacy")) {}
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                    Text("·").foregroundStyle(.tertiary).font(.system(size: 11))
                    Button(L("general.footer.reset")) {}
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
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

private struct FormGroupView<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

private struct ToggleRowView: View {
    let label: String
    var hint: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 13))
                if let hint {
                    Text(hint)
                        .font(.system(size: 11))
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

private struct PermissionRowView: View {
    let label: String
    var hint: String? = nil
    let granted: Bool
    let showOpenButton: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(label).font(.system(size: 13))
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(granted ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(granted ? L("general.permissionGranted") : L("general.permissionDenied"))
                        .font(.system(size: 12))
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
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 11)
            }
        }
    }
}
