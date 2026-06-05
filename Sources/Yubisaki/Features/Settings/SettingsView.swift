import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable {
    case gestures = "ジェスチャー"
    case general = "一般"
}

// Configures the Settings window to match the macOS System Settings visual style:
// hidden title bar + transparent titlebar + full-size content view.
// Applied via .background() so the NSView can reach its containing NSWindow.
private struct SettingsWindowStyle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            if !window.styleMask.contains(.fullSizeContentView) {
                window.styleMask.insert(.fullSizeContentView)
            }
            window.toolbar = nil
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct SettingsView: View {
    @Bindable var configStore: ConfigStore
    @State private var selectedTab: SettingsTab = .gestures
    @State private var selectedBundleID: String? = "global"

    var body: some View {
        NavigationSplitView {
            appList
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            switch selectedTab {
            case .gestures:
                detailPane
            case .general:
                GeneralSettingsView(configStore: configStore)
            }
        }
        .frame(minWidth: 960, minHeight: 660)
        .background(SettingsWindowStyle())
    }

    // MARK: - Sidebar

    private var appList: some View {
        List(selection: $selectedBundleID) {
            AppRowView(
                bundleID: "global",
                enabledCount: configStore.globalProfile.bindings.filter(\.enabled).count
            )
            .tag("global")

            ForEach(configStore.profiles) { profile in
                AppRowView(
                    bundleID: profile.bundleID,
                    enabledCount: profile.bindings.filter(\.enabled).count
                )
                .tag(profile.bundleID)
            }
        }
        .onChange(of: selectedBundleID) { _, _ in
            if selectedTab == .general {
                selectedTab = .gestures
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 28)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 2) {
                Button(action: addApp) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel("アプリを追加")

                Button(action: removeSelected) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.plain)
                .padding(6)
                .disabled(selectedBundleID == nil || selectedBundleID == "global")
                .accessibilityLabel("アプリを削除")

                Spacer()

                Button(action: { selectedTab = selectedTab == .general ? .gestures : .general }) {
                    Image(systemName: "gearshape")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .padding(6)
                .padding(.trailing, 4)
                .accessibilityLabel("一般設定")
            }
            .padding(.leading, 4)
            .frame(height: 36)
        }
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
                  configStore.profiles.contains(where: { $0.bundleID == id }) {
            BindingsView(
                profile: Binding(
                    get: { configStore.profiles.first(where: { $0.bundleID == id }) ?? AppProfile(bundleID: id) },
                    set: {
                        if let i = configStore.profiles.firstIndex(where: { $0.bundleID == id }) {
                            configStore.profiles[i] = $0
                            configStore.save()
                        }
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
        selectedBundleID = "global"
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
                .font(.callout.weight(.medium))
                .lineLimit(1)
            Spacer()
            if enabledCount > 0 {
                Text("\(enabledCount)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
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
                    .fill(.quaternary)
                    .frame(width: 20, height: 20)
                Image(systemName: "hand.draw")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
