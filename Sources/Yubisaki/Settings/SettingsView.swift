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
                GeneralTabView()
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

    private var availableGestures: [GestureType] {
        GestureType.allCases.filter { g in
            !profile.bindings.contains { $0.gesture == g }
        }
    }

    private var appName: String {
        NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: profile.bundleID)
            .map { $0.deletingPathExtension().lastPathComponent }
            ?? profile.bundleID
    }

    var body: some View {
        VStack(spacing: 0) {
            if profile.bindings.isEmpty {
                Spacer()
                Text("ジェスチャーバインディングがありません")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(profile.bindings.indices, id: \.self) { i in
                            BindingRowView(
                                binding: $profile.bindings[i],
                                onDelete: { profile.bindings.remove(at: i) }
                            )
                            Divider()
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            if !availableGestures.isEmpty {
                Divider()
                Button(action: addBinding) {
                    Label("バインディングを追加", systemImage: "plus")
                }
                .padding(12)
            }
        }
    }

    private func addBinding() {
        guard let gesture = availableGestures.first else { return }
        profile.bindings.append(GestureBinding(gesture: gesture, keyCode: 0, modifierFlags: 0))
    }
}

// MARK: - Binding Row

private struct BindingRowView: View {
    @Binding var binding: GestureBinding
    var onDelete: () -> Void

    var body: some View {
        HStack {
            Text(binding.gesture.displayName)
                .frame(width: 130, alignment: .leading)
            KeyRecorderView(
                keyCode: $binding.keyCode,
                modifierFlags: $binding.modifierFlags
            )
            .frame(height: 28)
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - General Tab

private struct GeneralTabView: View {
    var body: some View {
        Text("一般設定（フェーズ7-Gで実装）")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
