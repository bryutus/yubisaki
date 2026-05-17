import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var configStore: ConfigStore
    @State private var selectedBundleID: String?

    var body: some View {
        NavigationSplitView {
            appList
        } detail: {
            detailPane
        }
        .frame(minWidth: 680, minHeight: 420)
    }

    // MARK: - Sidebar

    private var appList: some View {
        List(selection: $selectedBundleID) {
            ForEach(configStore.profiles) { profile in
                AppRowView(bundleID: profile.bundleID)
                    .tag(profile.bundleID)
            }
        }
        .navigationTitle("アプリ")
        .toolbar {
            ToolbarItemGroup {
                Button(action: addApp) {
                    Image(systemName: "plus")
                }
                Button(action: removeSelected) {
                    Image(systemName: "minus")
                }
                .disabled(selectedBundleID == nil)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if let id = selectedBundleID,
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

    private var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    private var appName: String {
        appURL.map { $0.deletingPathExtension().lastPathComponent } ?? bundleID
    }

    private var appIcon: NSImage {
        if let url = appURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(appName).font(.body)
                Text(bundleID).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
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
        .navigationTitle(appName)
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
