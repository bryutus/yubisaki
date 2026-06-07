import SwiftUI
import AppKit

struct BindingsView: View {
    @Binding var profile: AppProfile
    @State private var selectedBindingID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                AppHeaderView(
                    bundleID: profile.bundleID,
                    isGlobalProfile: profile.bundleID == "global",
                    enabled: $profile.enabled
                )

                VStack(spacing: 0) {
                    ColumnHeaderRow()
                    Color(nsColor: .separatorColor).frame(height: 0.5).padding(.horizontal, 16)
                    if profile.bindings.isEmpty {
                        Text(L("gestures.noBindings"))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        ForEach($profile.bindings) { $binding in
                            BindingRowView(
                                binding: $binding,
                                isSelected: selectedBindingID == binding.id,
                                onSelect: { selectedBindingID = binding.id }
                            )
                            Color(nsColor: .separatorColor).frame(height: 0.5).padding(.horizontal, 16)
                        }
                    }
                }
                .opacity(profile.enabled ? 1.0 : 0.55)
                .background(Color(red: 232/255, green: 233/255, blue: 232/255))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.separator.opacity(0.6), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 236/255, green: 237/255, blue: 236/255))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BindingsFooter(profile: $profile, selectedBindingID: $selectedBindingID)
                .padding(.horizontal, 8)
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
                .font(.headline)
            Spacer()
            Text(toggleLabel)
                .font(.callout)
            Toggle("", isOn: $enabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
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
                    .fill(.quaternary)
                    .frame(width: 44, height: 44)
                Image(systemName: "hand.draw")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Column Header Row

private struct ColumnHeaderRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 14, height: 1)
            Text(L("gestures.column.gesture"))
                .frame(width: 200, alignment: .leading)
            Text(L("gestures.column.shortcut"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L("gestures.column.note"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption2.weight(.bold))
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

    @State private var noteText: String = ""
    @FocusState private var noteIsFocused: Bool

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

            TextField(L("gestures.column.note"), text: $noteText)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .focused($noteIsFocused)
                .onChange(of: noteIsFocused) { _, focused in
                    if !focused { binding.note = noteText }
                }
                .onChange(of: binding.note) { _, new in
                    if !noteIsFocused { noteText = new }
                }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { onSelect() })
        .onAppear { noteText = binding.note }
    }
}

// MARK: - Bindings Footer

private struct BindingsFooter: View {
    @Binding var profile: AppProfile
    @Binding var selectedBindingID: UUID?

    var body: some View {
        HStack(spacing: 2) {
            Button(action: addBinding) { Image(systemName: "plus") }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel("バインディングを追加")

            Button(action: deleteSelected) { Image(systemName: "minus") }
                .buttonStyle(.plain)
                .padding(6)
                .disabled(selectedBindingID == nil)
                .accessibilityLabel("バインディングを削除")

            Spacer()
        }
        .padding(.leading, 8)
        .frame(height: 36)
    }

    private func addBinding() {
        let used = Set(profile.bindings.map(\.gesture))
        guard let gesture = GestureType.allCases.first(where: { !used.contains($0) }) else { return }
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
