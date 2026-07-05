import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable {
    case gestures = "ジェスチャー"
    case general = "一般"
}

// Configures the Settings window to match the macOS System Settings / Xcode visual style.
// A unified toolbar makes the titlebar taller, so AppKit centers the traffic-light buttons
// lower (the same mechanism Xcode and Finder use). Combined with a transparent titlebar and
// full-size content view, the sidebar background shows through behind the buttons.
// Applied via .background() so the NSView can reach its containing NSWindow.
private struct SettingsWindowStyle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowConfiguringView()
    }

    // titleVisibility is non-structural and safe on updates; the heavier toolbar/styleMask
    // changes happen once, deferred, inside WindowConfiguringView. The sidebar-toggle removal
    // is re-scheduled on every update because SwiftUI re-adds the item when the view rebuilds.
    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.titleVisibility = .hidden
        (nsView as? WindowConfiguringView)?.scheduleSidebarToggleRemoval()
    }

    // Applies the window chrome once the view joins a window. styleMask/toolbar changes
    // rebuild the window's view hierarchy, so they MUST be deferred out of the current
    // layout/transaction pass — doing them inline throws during the CATransaction flush.
    private final class WindowConfiguringView: NSView {
        private var didConfigure = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil, !didConfigure else { return }
            didConfigure = true
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.applyChrome() }
            }
        }

        func scheduleSidebarToggleRemoval() {
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.removeSidebarToggle() }
            }
        }

        private func applyChrome() {
            guard let window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            // A unified toolbar keeps the titlebar tall (lowering the traffic lights) even
            // with no visible items. We reuse SwiftUI's NavigationSplitView toolbar.
            window.toolbarStyle = .unified
            window.titlebarSeparatorStyle = .none
            removeSidebarToggle()
        }

        // SwiftUI's NavigationSplitView injects a sidebar-toggle toolbar item that
        // .toolbar(removing: .sidebarToggle) fails to suppress here, so strip it directly.
        private func removeSidebarToggle() {
            guard let toolbar = window?.toolbar else { return }
            for index in toolbar.items.indices.reversed()
            where toolbar.items[index].itemIdentifier.rawValue.contains("toggleSidebar") {
                toolbar.removeItem(at: index)
            }
        }
    }
}

struct SettingsView: View {
    @Bindable var configStore: ConfigStore
    @State private var selectedTab: SettingsTab = .gestures
    @State private var selectedBundleID: String? = AppProfile.globalBundleID

    // Height of the unified titlebar; used to vertically center the tab title with the
    // traffic-light buttons.
    private let titlebarHeight: CGFloat = 50

    var body: some View {
        NavigationSplitView {
            appList
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            ZStack {
                switch selectedTab {
                case .gestures:
                    detailPane
                case .general:
                    GeneralSettingsView(configStore: configStore)
                }
            }
            .overlay(alignment: .topLeading) {
                // Sit the title in the titlebar band so its vertical center lines up with the
                // traffic-light buttons. The frame height matches the unified titlebar, and
                // ignoring the top safe area lets it rise into that band.
                Text(selectedTab.rawValue)
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, minHeight: titlebarHeight, alignment: .leading)
                    .ignoresSafeArea(.container, edges: .top)
            }
        }
        .navigationTitle("")
        .frame(minWidth: 960, minHeight: 660)
        .background(SettingsWindowStyle())
    }

    // MARK: - Sidebar

    private var appList: some View {
        List(selection: $selectedBundleID) {
            AppRowView(
                bundleID: AppProfile.globalBundleID,
                enabledCount: configStore.globalProfile.bindings.filter(\.enabled).count
            )
            .tag(AppProfile.globalBundleID)

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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 2) {
                Button(action: addApp) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel(L("sidebar.addApp"))

                Button(action: removeSelected) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.plain)
                .padding(6)
                .disabled(selectedBundleID == nil || selectedBundleID == AppProfile.globalBundleID)
                .accessibilityLabel(L("sidebar.removeApp"))

                Spacer()

                Button(action: { selectedTab = selectedTab == .general ? .gestures : .general }) {
                    Image(systemName: "gearshape")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .padding(6)
                .padding(.trailing, 4)
                .accessibilityLabel(L("sidebar.generalSettings"))
            }
            .padding(.leading, 4)
            .frame(height: 36)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if selectedBundleID == AppProfile.globalBundleID {
            BindingsView(
                profile: Binding(
                    get: { configStore.globalProfile },
                    set: {
                        configStore.globalProfile = $0
                        configStore.saveGlobalProfile()
                    }
                )
            )
        } else if let id = selectedBundleID,
                  let index = configStore.profiles.firstIndex(where: { $0.bundleID == id }) {
            BindingsView(
                profile: Binding(
                    get: {
                        // index は選択時点のもの。配列が変わっていたら安全側に倒す。
                        guard configStore.profiles.indices.contains(index),
                              configStore.profiles[index].bundleID == id else { return AppProfile(bundleID: id) }
                        return configStore.profiles[index]
                    },
                    set: {
                        guard configStore.profiles.indices.contains(index),
                              configStore.profiles[index].bundleID == id else { return }
                        configStore.profiles[index] = $0
                        configStore.saveProfiles()
                    }
                )
            )
        } else {
            Text(L("gestures.selectApp"))
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
            configStore.saveProfiles()
            selectedBundleID = bundleID
        }
    }

    private func removeSelected() {
        guard let id = selectedBundleID else { return }
        configStore.profiles.removeAll { $0.bundleID == id }
        configStore.saveProfiles()
        selectedBundleID = AppProfile.globalBundleID
    }
}

// MARK: - App Row

private struct AppRowView: View {
    let bundleID: String
    let enabledCount: Int

    var body: some View {
        HStack(spacing: 8) {
            AppIconView(bundleID: bundleID, size: 20)
            Text(AppDisplay.name(for: bundleID))
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
}
